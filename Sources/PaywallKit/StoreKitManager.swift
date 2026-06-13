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
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return transaction
        case .userCancelled, .pending:
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
        } catch {
            errorMessage = "Failed to restore purchases"
        }
        isLoading = false
    }

    // MARK: - Private
    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                purchased.insert(transaction.productID)
            }
        }
        purchasedProductIDs = purchased
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
