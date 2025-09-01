import SwiftUI

struct BookDetailView: View {
    @StateObject private var viewModel: BookDetailViewModel
    @StateObject private var colorExtractor = ColorExtractor()
    @State private var showingChatSheet = false
    @State private var showingSummarySheet = false
    
    init(book: Book) {
        _viewModel = StateObject(wrappedValue: BookDetailViewModel(
            book: book,
            repository: DependencyContainer.shared.bookRepository
        ))
    }
    
    var body: some View {
        ZStack {
            // Background gradient based on book cover colors
            LinearGradient(
                colors: colorExtractor.backgroundGradient,
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea(.all, edges: .top)
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    // Clean book header section
                    bookHeader
                        .padding(.horizontal)
                        .padding(.top)
                        .padding(.bottom, 32)
                    
                    // Action buttons section
                    actionButtonsSection
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                
                    // Summary preview or status
                    summaryPreviewSection
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Share button
                Button(action: {
                    SharingService.shared.shareBook(viewModel.book)
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.primary)
                }
            }
        }
        .task {
            await colorExtractor.extractColors(from: viewModel.book.coverAssetName)
        }
        .sheet(isPresented: $showingChatSheet) {
            NavigationView {
                BookChatView(book: viewModel.book)
                    .navigationTitle(viewModel.book.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingChatSheet = false
                            }
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSummarySheet) {
            NavigationView {
                summarySheetContent
                    .navigationTitle(viewModel.book.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingSummarySheet = false
                            }
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
    
    var actionButtonsSection: some View {
        VStack(spacing: 16) {
            // Primary CTA - Chat with book
            Button(action: {
                showingChatSheet = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "message.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                    
                    Text("Chat with book")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: .blue.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            
            // Secondary CTA - Read Extended Summary
            Button(action: {
                showingSummarySheet = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 20, weight: .medium))
                    
                    Text("Read")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.secondarySystemBackground))
                        .stroke(Color(UIColor.separator).opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    var summaryPreviewSection: some View {
        VStack(spacing: 20) {
            if viewModel.isLoadingSummary {
                VStack(spacing: 16) {
                    if viewModel.isGeneratingSummary {
                        GeneratingView(message: viewModel.generationMessage)
                    } else {
                        ConsistentLoadingView(style: .primary, message: "Loading summary...")
                    }
                }
                .frame(height: 150)
                .padding()
            } else if let error = viewModel.summaryError {
                ErrorView(error: error) {
                    Task {
                        await viewModel.loadSummary()
                    }
                }
                .padding()
            } else if let summary = viewModel.summary {
                summaryPreview(summary)
            } else {
                noSummaryPreview
            }
        }
        .background(Color(UIColor.systemBackground))
    }
    
    var summarySheetContent: some View {
        Group {
            if let summary = viewModel.summary {
                EnhancedSummaryView(
                    summary: summary, 
                    book: viewModel.book,
                    dominantColor: colorExtractor.dominantColor,
                    secondaryColor: colorExtractor.secondaryColor,
                    onGenerateSummary: {
                        await viewModel.generateSummary()
                    }
                )
            } else if viewModel.isLoadingSummary {
                VStack(spacing: 16) {
                    if viewModel.isGeneratingSummary {
                        GeneratingView(message: viewModel.generationMessage)
                    } else {
                        ConsistentLoadingView(style: .primary, message: "Loading summary...")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                noSummaryView
            }
        }
    }
    
    var bookHeader: some View {
        VStack(spacing: 20) {
            // Book cover centered
            BookCoverView(coverURL: viewModel.book.coverAssetName, size: .large)
                .frame(height: 200)
                .shadow(radius: 10)
            
            // Book information
            VStack(spacing: 12) {
                Text(viewModel.book.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                if let subtitle = viewModel.book.subtitle {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Text(viewModel.book.formattedAuthors)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary.opacity(0.8))
                
                VStack(spacing: 8) {
                    HStack(spacing: 20) {
                        // Publication info
                        Text(viewModel.publicationInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Reading time
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text(viewModel.readingTime)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    // Book rating
                    if viewModel.isLoadingRating {
                        RatingLoadingView(compact: true)
                    } else if let rating = viewModel.rating {
                        BookRatingDisplayView(rating: rating, showSource: false, compact: true)
                    }
                }
            }
        }
    }
    
    func summaryPreview(_ summary: Summary) -> some View {
        VStack(spacing: 20) {
            summaryHookSection(summary)
            keyIdeasSection(summary)
            actionsSection(summary)
        }
    }
    
    @ViewBuilder
    private func summaryHookSection(_ summary: Summary) -> some View {
        if !summary.oneSentenceHook.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("What's inside?")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                
                Text(summary.oneSentenceHook)
                    .font(.body)
                    .foregroundColor(.primary.opacity(0.8))
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func keyIdeasSection(_ summary: Summary) -> some View {
        if !summary.keyIdeas.isEmpty {
            keyIdeasContent(summary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .padding(.horizontal)
        }
    }
    
    private func keyIdeasContent(_ summary: Summary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
                Text("Key Ideas")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(summary.keyIdeas.enumerated()), id: \.element.id) { index, idea in
                    keyIdeaRow(index: index, idea: idea)
                }
            }
        }
    }
    
    private func keyIdeaRow(index: Int, idea: KeyIdea) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(index + 1).")
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .trailing)
            
            Text(idea.idea)
                .font(.callout)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    @ViewBuilder
    private func actionsSection(_ summary: Summary) -> some View {
        if !summary.howToApply.isEmpty {
            actionsContent(summary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(UIColor.secondarySystemBackground))
                )
                .padding(.horizontal)
        }
    }
    
    private func actionsContent(_ summary: Summary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16))
                Text("Actions to Apply")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(summary.howToApply, id: \.id) { action in
                    actionRow(action: action)
                }
            }
        }
    }
    
    private func actionRow(action: ApplicationPoint) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.caption)
                .foregroundColor(.green.opacity(0.7))
                .frame(width: 20)
            
            Text(action.action)
                .font(.callout)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    var noSummaryPreview: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary.opacity(0.7))
                
                VStack(spacing: 8) {
                    Text("No Summary Available")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("Generate a summary to unlock key insights and detailed analysis.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            
            Button(action: {
                Task {
                    await viewModel.generateSummary()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .medium))
                    Text("Generate Summary")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    var noSummaryView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 50))
                    .foregroundColor(.secondary.opacity(0.7))
                
                VStack(spacing: 8) {
                    Text("No Summary Available")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text("This book doesn't have an extended summary yet. Generate one to get key insights, ideas, and a detailed breakdown.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            
            Button(action: {
                Task {
                    await viewModel.generateSummary()
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .medium))
                    Text("Generate a summary")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(Color(UIColor.systemBackground))
    }
}

// StatView removed - now displaying key ideas and actions directly