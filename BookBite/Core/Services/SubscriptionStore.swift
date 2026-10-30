import Foundation
import StoreKit

/// BookBite Unlimited: a $9/month auto-renewable subscription (StoreKit 2) that removes the reading
/// pass limit. The entitlement is read on device from `Transaction.currentEntitlements`; the server
/// doesn't know about it. Local testing uses `BookBite.storekit` (set in the BookBite scheme).
@MainActor
final class SubscriptionStore: ObservableObject {
    static let shared = SubscriptionStore()

    /// Must match the product in App Store Connect and `BookBite.storekit`
    static let productID = "tilo.BookBite.unlimited.monthly"

    enum PurchaseOutcome {
        case purchased, pending, cancelled
    }

    enum SubscriptionError: LocalizedError {
        case unavailable, unverified

        var errorDescription: String? {
            switch self {
            case .unavailable: return "The App Store isn't available right now. Try again later."
            case .unverified: return "The App Store couldn't confirm the purchase. Try Restore Purchases."
            }
        }
    }

    @Published private(set) var product: Product?
    /// Cached so a subscriber doesn't see the limit while StoreKit answers at launch
    @Published private(set) var isSubscribed: Bool {
        didSet { defaults.set(isSubscribed, forKey: Self.cacheKey) }
    }

    private static let cacheKey = "isSubscribedUnlimited"
    private let defaults: UserDefaults
    private var updates: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isSubscribed = defaults.bool(forKey: Self.cacheKey)
    }

    /// Listens for renewals, refunds and purchases made elsewhere (Family Sharing, another device)
    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self?.refreshEntitlement()
            }
        }
        Task {
            await loadProduct()
            await refreshEntitlement()
        }
    }

    /// "$9.00/month", from the App Store so it is in the reader's currency
    var priceText: String {
        guard let product else { return "$9/month" }
        return "\(product.displayPrice)/month"
    }

    func loadProduct() async {
        guard product == nil else { return }
        product = try? await Product.products(for: [Self.productID]).first
    }

    func refreshEntitlement() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                active = true
            }
        }
        isSubscribed = active
    }

    /// `accountId` (the Supabase user id) goes with the purchase as its app account token, so the
    /// server can link subscriptions to accounts later
    func purchase(accountId: String?) async throws -> PurchaseOutcome {
        await loadProduct()
        guard let product else { throw SubscriptionError.unavailable }
        var options: Set<Product.PurchaseOption> = []
        if let token = accountId.flatMap(UUID.init(uuidString:)) {
            options.insert(.appAccountToken(token))
        }
        switch try await product.purchase(options: options) {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { throw SubscriptionError.unverified }
            await transaction.finish()
            await refreshEntitlement()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlement()
    }
}
