import StoreKit
import SwiftUI
import UIKit

/// Settings, opened from the account button in Library. A plain grouped list in the system style:
/// account first, then what changes the app day to day, then data, then About.
struct SettingsView: View {
    @EnvironmentObject private var authService: SupabaseAuthService
    @ObservedObject private var dependencies = DependencyContainer.shared
    @ObservedObject private var audio = AudioPlaybackService.shared
    @ObservedObject private var askHistory = AskHistoryStore.shared
    @ObservedObject private var recentBooks = RecentBooksStore.shared
    @ObservedObject private var readingProgress = ReadingProgressStore.shared
    @ObservedObject private var readingPass = ReadingPassStore.shared
    @ObservedObject private var subscription = SubscriptionStore.shared
    @State private var showingManageSubscription = false
    @State private var restoreMessage: String?
    @StateObject private var reminder = ReminderSettingsViewModel()

    @AppStorage("readerTheme") private var readerTheme: ReaderTheme = .paper
    @AppStorage("readerTypeface") private var readerTypeface: ReaderTypeface = .serif

    @State private var cacheInfo: CacheInfo?
    @State private var offlineStorageInfo: OfflineStorageInfo?
    @State private var pendingClear: ClearAction?
    @State private var showingAuth = false
    @State private var interestsSummary = InterestsView.summary()
    @Environment(\.openURL) private var openURL

    private let cacheService = CacheService.shared
    private let offlineStorage = OfflineStorageService.shared

    /// Destructive actions, each confirmed in one dialog
    private enum ClearAction: Identifiable {
        case cache, askHistory, recentlyOpened, readingProgress

        var id: Self { self }

        var title: String {
            switch self {
            case .cache: return "Clear Cache"
            case .askHistory: return "Clear Ask History"
            case .recentlyOpened: return "Clear Recently Opened"
            case .readingProgress: return "Clear Reading Progress"
            }
        }

        var message: String {
            switch self {
            case .cache: return "This removes cached books and summaries. Downloaded books stay."
            case .askHistory: return "This deletes all your Ask conversations."
            case .recentlyOpened: return "This empties Recently opened in your Library."
            case .readingProgress: return "This removes Continue reading and your Finished shelf. Your notebook stays."
            }
        }
    }

    private var isSignedIn: Bool {
        authService.isAuthenticated && !authService.isAnonymous
    }

    var body: some View {
        Form {
            accountSection
            readingPassSection
            notificationsSection
            readingSection
            interestsSection
            storageSection
            privacySection
            aboutSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await reminder.load()
        }
        .onAppear {
            refreshStorageInfo()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Back from the Settings app, where notifications may have been turned on
            Task { await reminder.load() }
        }
        .onReceive(NotificationCenter.default.publisher(for: OnboardingPreferences.didChange)) { _ in
            interestsSummary = InterestsView.summary()
        }
        .confirmationDialog(pendingClear?.title ?? "", isPresented: isConfirmingClear,
                            titleVisibility: .visible, presenting: pendingClear) { action in
            Button(action.title, role: .destructive) { perform(action) }
        } message: { action in
            Text(action.message)
        }
        .sheet(isPresented: $showingAuth) {
            OnboardingAuthSheet(authService: authService) {
                showingAuth = false
            }
        }
        .manageSubscriptionsSheet(isPresented: $showingManageSubscription)
        .alert("Restore Purchases", isPresented: Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
    }

    // MARK: - Reading Pass

    private var readingPassSection: some View {
        Section {
            NavigationLink {
                ReadingPassView(showsCloseButton: false)
            } label: {
                LabeledContent("Reading Pass", value: readingPassSummary)
            }
            if subscription.isSubscribed {
                Button("Manage Subscription") { showingManageSubscription = true }
            } else {
                Button("Restore Purchases") {
                    Task {
                        do {
                            try await subscription.restore()
                            restoreMessage = subscription.isSubscribed
                                ? "BookBite Unlimited is active again."
                                : "No active subscription was found for this Apple Account."
                        } catch {
                            restoreMessage = error.localizedDescription
                        }
                    }
                }
            }
        } footer: {
            Text("Give a friend 5 books and you get 5 more. Key ideas are always free.")
        }
    }

    private var readingPassSummary: String {
        if subscription.isSubscribed { return "Unlimited" }
        let left = readingPass.pass.remaining
        return left == 1 ? "1 book left" : "\(left) books left"
    }

    // MARK: - Account

    @ViewBuilder
    private var accountSection: some View {
        Section {
            if isSignedIn, let user = authService.currentUser {
                NavigationLink {
                    AccountView()
                } label: {
                    AccountRow(user: user)
                }
            } else {
                Button {
                    showingAuth = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sign In")
                                .font(.headline)
                            Text("Save books and keep them on all your devices.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section {
            Toggle("Idea of the Day", isOn: Binding(
                get: { reminder.isOn },
                set: { on in Task { await reminder.setOn(on) } }
            ))
            // While notifications are off in the Settings app the switch can still turn the reminder off
            .disabled(!reminder.isLoaded || (reminder.isDenied && !reminder.isOn))

            if reminder.isOn {
                DatePicker("Time", selection: Binding(
                    get: { reminder.time },
                    set: { time in Task { await reminder.setTime(time) } }
                ), displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Notifications")
        } footer: {
            if reminder.isDenied {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notifications are off for BookBite.")
                    Button("Turn On in Settings") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .font(.footnote.weight(.medium))
                }
            } else {
                Text("One big idea from a great book, every morning. It takes a minute to read.")
            }
        }
        .animation(.default, value: reminder.isOn)
    }

    // MARK: - Reading & Listening

    private var readingSection: some View {
        Section("Reading & Listening") {
            NavigationLink {
                ReadingSettingsView()
            } label: {
                LabeledContent("Reader", value: "\(readerTheme.name) · \(readerTypeface.name)")
            }

            Picker("Playback Speed", selection: Binding(
                get: { audio.playbackRate },
                set: { audio.setPlaybackRate($0) }
            )) {
                ForEach(AudioPlaybackService.playbackRates, id: \.self) { rate in
                    Text(Self.speedLabel(rate)).tag(rate)
                }
            }
        }
    }

    static func speedLabel(_ rate: Float) -> String {
        rate.formatted(.number.precision(.fractionLength(0...2))) + "×"
    }

    // MARK: - Interests

    private var interestsSection: some View {
        Section {
            NavigationLink {
                InterestsView()
            } label: {
                LabeledContent("Topics & Goals", value: interestsSummary)
            }
        } header: {
            Text("Your Interests")
        } footer: {
            Text("Discover uses these to pick books for you.")
        }
    }

    // MARK: - Storage

    private var storageSection: some View {
        Section {
            NavigationLink(destination: DownloadedBooksView()) {
                LabeledContent("Downloaded Books") {
                    if let info = offlineStorageInfo, info.bookCount > 0 {
                        Text("\(info.bookCount)")
                    }
                }
            }

            Button("Clear Cache", role: .destructive) {
                pendingClear = .cache
            }
        } header: {
            Text("Storage")
        } footer: {
            if let cacheInfo {
                Text("Books you save or start reading are downloaded so you can read them offline. The cache uses \(cacheInfo.formattedSize).")
            } else {
                Text("Books you save or start reading are downloaded so you can read them offline.")
            }
        }
    }

    // MARK: - Privacy & Data

    private var privacySection: some View {
        Section {
            clearButton(.askHistory, isEmpty: askHistory.conversations.isEmpty)
            clearButton(.recentlyOpened, isEmpty: recentBooks.books.isEmpty)
            clearButton(.readingProgress, isEmpty: readingProgress.entries.isEmpty)
        } header: {
            Text("Privacy & Data")
        } footer: {
            Text("Your reading progress, notebook, recently opened books and Ask history are stored only on this \(UIDevice.current.model), not on BookBite's servers.")
        }
    }

    private func clearButton(_ action: ClearAction, isEmpty: Bool) -> some View {
        Button(action.title, role: .destructive) {
            pendingClear = action
        }
        .disabled(isEmpty)
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: appVersion)
            Link(destination: AppLinks.privacyPolicy) {
                ExternalLinkLabel(title: "Privacy Policy")
            }
            Link(destination: AppLinks.termsOfUse) {
                ExternalLinkLabel(title: "Terms of Use")
            }
            if let feedback = AppLinks.feedbackMail(appVersion: appVersion) {
                Link(destination: feedback) {
                    ExternalLinkLabel(title: "Send Feedback")
                }
            }
        } header: {
            Text("About")
        } footer: {
            // Required by Amazon Associates for the "Get the full book" links
            Text("As an Amazon Associate, BookBite earns from qualifying purchases.")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    // MARK: - Actions

    private var isConfirmingClear: Binding<Bool> {
        Binding(get: { pendingClear != nil }, set: { if !$0 { pendingClear = nil } })
    }

    private func perform(_ action: ClearAction) {
        switch action {
        case .cache:
            cacheService.clearAllCache()
            dependencies.bookRepository.clearCache()
            refreshStorageInfo()
        case .askHistory:
            askHistory.clear()
        case .recentlyOpened:
            recentBooks.clear()
        case .readingProgress:
            readingProgress.clear()
        }
    }

    private func refreshStorageInfo() {
        cacheInfo = cacheService.getCacheInfo()
        offlineStorageInfo = offlineStorage.getOfflineStorageInfo()
    }
}

/// The signed-in account at the top of Settings: initial in a circle, name or email.
private struct AccountRow: View {
    let user: User

    var body: some View {
        HStack(spacing: 14) {
            AccountInitial(user: user, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName ?? user.email ?? "Your Account")
                    .font(.headline)
                    .lineLimit(1)
                Text(user.displayName != nil ? (user.email ?? "") : "Saved books sync across your devices")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

/// First letter of the name or email on a quiet ink circle. Monochrome, like the rest of the app.
struct AccountInitial: View {
    let user: User
    let size: CGFloat

    private var initial: String {
        let source = user.displayName ?? user.email ?? ""
        return source.first.map { String($0).uppercased() } ?? "?"
    }

    var body: some View {
        Text(initial)
            .font(.system(size: size * 0.45, weight: .medium, design: .serif))
            .foregroundStyle(Color(.systemBackground))
            .frame(width: size, height: size)
            .background(Circle().fill(Color.primary))
            .accessibilityHidden(true)
    }
}

/// A row that leaves the app: title plus the arrow iOS uses for external links.
private struct ExternalLinkLabel: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(DependencyContainer.shared.authService)
    }
}
