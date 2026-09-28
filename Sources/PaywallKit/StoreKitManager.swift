//
//  StoreKitManager.swift
//  PaywallKit
//
//  Reusable StoreKit 2 manager for GambitStudio apps.
//  Single shared instance, configurable product IDs per app.
//
//  Usage in your app:
//
//      // In your App init, configure once:
//      StoreKitManager.shared.configure(productIDs: [
//          "myapp.pro.monthly",
//          "myapp.pro.yearly"
//      ])
//

import Foundation
import StoreKit
import Combine

@MainActor
public final class StoreKitManager: NSObject, ObservableObject {
    // MARK: - Singleton
    public static let shared = StoreKitManager()

    // MARK: - Published
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var purchasedProductIDs: Set<String> = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var errorMessage: String?
    /// End of the free trial the current entitlement is in; nil when not in a trial (or iOS < 17.2).
    /// Feed it to `TrialReminderScheduler.enable(trialEnd:strings:)` from the post-purchase screen.
    @Published public private(set) var trialEndDate: Date?

    // MARK: - Private
    private var productIDs: [String] = []
    private var weeklyID: String?
    private var monthlyID: String?
    private var yearlyID: String?
    private var lifetimeID: String?
    private var updateListenerTask: Task<Void, Error>?

    // MARK: - Init
    private override init() {
        super.init()
        updateListenerTask = listenForTransactions()
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Configuration
    /// Call ONCE at app launch with the app's product IDs.
    /// Pass whichever plans the app sells — weekly, monthly, yearly, lifetime (any subset).
    /// The GambitStudio default plan model is weekly + yearly.
    public func configure(weekly: String? = nil, monthly: String? = nil, yearly: String? = nil, lifetime: String? = nil) {
        self.weeklyID = weekly
        self.monthlyID = monthly
        self.yearlyID = yearly
        self.lifetimeID = lifetime
        self.productIDs = [weekly, monthly, yearly, lifetime].compactMap { $0 }
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    /// Alternative configure: pass arbitrary product IDs (no monthly/yearly distinction).
    public func configure(productIDs: [String]) {
        self.productIDs = productIDs
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }

    // MARK: - Public computed
    public var isPremium: Bool { !purchasedProductIDs.isEmpty }

    public var weeklyProduct: Product? {
        guard let id = weeklyID else { return nil }
        return product(for: id)
    }

    public var monthlyProduct: Product? {
        guard let id = monthlyID else { return nil }
        return product(for: id)
    }

    public var yearlyProduct: Product? {
        guard let id = yearlyID else { return nil }
        return product(for: id)
    }

    public var lifetimeProduct: Product? {
        guard let id = lifetimeID else { return nil }
        return product(for: id)
    }

    public func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    // MARK: - Public actions
    public func loadProducts() async {
        guard !productIDs.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await Product.products(for: productIDs)
            self.products = loaded.sorted { $0.price > $1.price }  // yearly first
        } catch {
            errorMessage = "Failed to load products"
        }
        isLoading = false
    }

    public func purchase(_ product: Product) async throws -> Transaction? {
        try await purchase(product, options: [])
    }

    /// Same, with purchase options (a signed promotional offer for `ExitOfferSheet`, app account token…).
    public func purchase(_ product: Product, options: Set<Product.PurchaseOption>) async throws -> Transaction? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let pp = PaywallAnalytics.productParams(product)
        PaywallAnalytics.log("purchase_started", pp)
        let result: Product.PurchaseResult
        do {
            result = try await product.purchase(options: options)
        } catch {
            PaywallAnalytics.log("purchase_abandoned", pp.merging(["reason": "failed"]) { $1 })
            throw error
        }

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            PaywallAnalytics.log("purchase_success", pp)
            return transaction
        case .userCancelled:
            PaywallAnalytics.log("purchase_abandoned", pp.merging(["reason": "cancelled"]) { $1 })
            return nil
        case .pending:
            PaywallAnalytics.log("purchase_abandoned", pp.merging(["reason": "pending"]) { $1 })
            return nil
        @unknown default:
            return nil
        }
    }

    public func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            if let id = purchasedProductIDs.first {
                PaywallAnalytics.log("purchase_restored", ["product_id": id])
            }
        } catch {
            errorMessage = "Failed to restore purchases"
        }
        isLoading = false
    }

    // MARK: - Private
    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        var trialEnd: Date?
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                purchased.insert(transaction.productID)
                if #available(iOS 17.2, *), let end = TrialReminderScheduler.trialEnd(of: transaction) {
                    trialEnd = end
                }
            }
        }
        purchasedProductIDs = purchased
        trialEndDate = trialEnd
        // The trial converted (or the plan changed): a "trial ends soon" reminder would now be false.
        if trialEnd == nil, !purchased.isEmpty, TrialReminderScheduler.isScheduled {
            TrialReminderScheduler.cancel()
        }
        UserDefaults.standard.set(!purchased.isEmpty, forKey: "isPremium")
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                do {
                    let transaction = try self?.checkVerified(result)
                    await self?.updatePurchasedProducts()
                    await transaction?.finish()
                } catch {
                    // verification failed — ignore
                }
            }
        }
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw PaywallKitError.verificationFailed
        case .verified(let safe): return safe
        }
    }
}

// MARK: - Errors
public enum PaywallKitError: Error {
    case verificationFailed
    case productNotFound
}
