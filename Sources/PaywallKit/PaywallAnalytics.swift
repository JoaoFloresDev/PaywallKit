//
//  PaywallAnalytics.swift
//  PaywallKit
//
//  Analytics hook — the kit has no Firebase dependency. The app wires
//  `PaywallAnalytics.onEvent` to its AnalyticsService once (in @main) and sets
//  `PaywallAnalytics.source` right before presenting a paywall. Event names and
//  params follow _GambitStudio/analytics/event-taxonomy.md §2.4.
//

import Foundation
import StoreKit

// MARK: - PaywallAnalytics
public enum PaywallAnalytics {
    /// Wire to the app's analytics: `PaywallAnalytics.onEvent = { Analytics.log($0, $1) }`.
    nonisolated(unsafe) public static var onEvent: ((String, [String: Any]) -> Void)?
    /// Where the paywall was opened from (onboarding / settings / gate_<feature> / deeplink).
    /// Set it right before presenting; it is attached to every event until changed.
    nonisolated(unsafe) public static var source: String = "unknown"
    /// Optional A/B variant label attached to every event.
    nonisolated(unsafe) public static var variant: String?
    /// First-launch date of this install. When set, every event carries `days_since_install`
    /// (Int) — day-0 revenue vs total is the research 2026-09 metric #7. The app persists the
    /// date on first launch and sets it here once at launch, next to `onEvent`.
    nonisolated(unsafe) public static var installDate: Date?

    // MARK: - Event Names
    /// Every event the kit emits through `onEvent`. All follow event-taxonomy.md §2.4.
    public enum Event {
        public static let paywallShown = "paywall_shown"
        public static let paywallDismissed = "paywall_dismissed"
        public static let purchaseStarted = "purchase_started"
        public static let purchaseSuccess = "purchase_success"
        public static let purchaseAbandoned = "purchase_abandoned"
        public static let purchaseRestored = "purchase_restored"
        public static let premiumGateHit = "premium_gate_hit"
        /// Emitted by `PostPurchaseView.onAppear`.
        public static let postPurchaseShown = "post_purchase_shown"
        /// A plan card was tapped in `PurchaseScaffold` (params: `product_id`, `period`, `trial`).
        public static let planSelected = "plan_selected"
        /// `ExitOfferSheet` appeared (params: `reason` dismiss/abandon, `product_id`).
        public static let exitOfferShown = "exit_offer_shown"
        /// `TrialReminderScheduler` queued one local reminder (params: `days_before`, `kind`).
        public static let trialReminderScheduled = "trial_reminder_scheduled"
    }

    // MARK: - Logging
    static func log(_ name: String, _ params: [String: Any] = [:]) {
        var p = params
        p["source"] = source
        if let variant { p["variant"] = variant }
        if let days = daysSinceInstall() { p["days_since_install"] = days }
        onEvent?(name, p)
    }

    static func productParams(_ product: Product) -> [String: Any] {
        var p: [String: Any] = ["product_id": product.id,
                                "period": period(of: product),
                                "trial": hasFreeTrial(product),
                                "value": NSDecimalNumber(decimal: product.price).doubleValue,
                                "currency": product.priceFormatStyle.currencyCode]
        if product.subscription == nil { p["period"] = "lifetime" }
        return p
    }

    // MARK: - Helpers
    /// Whole days between `installDate` and now; nil when the app never set the date.
    static func daysSinceInstall(now: Date = Date()) -> Int? {
        guard let installDate else { return nil }
        return max(0, Int(now.timeIntervalSince(installDate) / 86_400))
    }

    static func period(of product: Product) -> String {
        guard let sub = product.subscription else { return "lifetime" }
        switch sub.subscriptionPeriod.unit {
        case .day: return sub.subscriptionPeriod.value >= 7 ? "weekly" : "daily"
        case .week: return "weekly"
        case .month: return sub.subscriptionPeriod.value >= 12 ? "yearly" : "monthly"
        case .year: return "yearly"
        @unknown default: return "unknown"
        }
    }

    static func hasFreeTrial(_ product: Product) -> Bool {
        product.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }
}
