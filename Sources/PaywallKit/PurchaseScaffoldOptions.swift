//
//  PurchaseScaffoldOptions.swift
//  PaywallKit
//
//  Opt-in behaviour of `PurchaseScaffold` that the lab preset (`GambitPaywallPreset`) turns on.
//  Every field defaults to the scaffold's historical behaviour, so an app that never passes
//  `options:` renders exactly as before.
//

import SwiftUI

// MARK: - CTA Context

/// What the CTA label is built from: the selected plan as the user sees it.
public struct PurchaseCTAContext: Sendable, Equatable {
    public let hasTrial: Bool
    /// Trial length in days (nil without a trial).
    public let trialDays: Int?
    /// Billed price as displayed ("R$ 14,90").
    public let price: String
    public let period: PurchasePeriod?
    /// Localised unit of the period ("semana"), empty for a lifetime product.
    public let unitLabel: String

    public init(hasTrial: Bool, trialDays: Int?, price: String, period: PurchasePeriod?, unitLabel: String) {
        self.hasTrial = hasTrial
        self.trialDays = trialDays
        self.price = price
        self.period = period
        self.unitLabel = unitLabel
    }

    /// "R$ 14,90/semana" — the price billed after the trial, as Apple asks the screen to show it.
    /// Non-breaking spaces keep "R$" and the amount on the same line when the CTA wraps.
    public var pricePerUnit: String {
        let glued = price.replacingOccurrences(of: " ", with: "\u{00A0}")
        return unitLabel.isEmpty ? glued : "\(glued)/\(unitLabel)"
    }
}

// MARK: - Options

public struct PurchaseScaffoldOptions {
    /// Plan pre-selected and listed first (the "hero plan", where the trial lives). nil = the
    /// historical order (most expensive first) and first-card selection.
    public var heroPeriod: PurchasePeriod?
    /// CTA label per selected plan (trial length + price after the trial). nil = `startTrialText` /
    /// `unlockNowText`.
    public var ctaText: ((PurchaseCTAContext) -> String)?
    /// Subordinate per-week line of the yearly card ("R$ 1,92 por semana"). nil hides it.
    public var perWeekText: ((String) -> String)?
    /// Auto-renew disclosure under the footer links. nil hides it.
    public var legalNote: String?
    /// Sets `PaywallAnalytics.source` right before `paywall_shown` is logged.
    public var source: String?
    /// `placement` param of `paywall_shown` / `paywall_dismissed`.
    public var placement: String

    public init(
        heroPeriod: PurchasePeriod? = nil,
        ctaText: ((PurchaseCTAContext) -> String)? = nil,
        perWeekText: ((String) -> String)? = nil,
        legalNote: String? = nil,
        source: String? = nil,
        placement: String = "purchase_scaffold"
    ) {
        self.heroPeriod = heroPeriod
        self.ctaText = ctaText
        self.perWeekText = perWeekText
        self.legalNote = legalNote
        self.source = source
        self.placement = placement
    }
}

// MARK: - Plan ordering

extension Array where Element == PurchasePlan {
    /// Hero plan first, the rest in their original order.
    func heroFirst(_ period: PurchasePeriod?) -> [PurchasePlan] {
        guard let period else { return self }
        return filter { $0.period == period } + filter { $0.period != period }
    }
}

extension PurchasePlan {
    var ctaContext: PurchaseCTAContext {
        PurchaseCTAContext(hasTrial: hasTrial, trialDays: trialDays, price: price, period: period, unitLabel: unitLabel)
    }
}

// MARK: - Legal note

/// Apple's auto-renew disclosure (Guidelines 3.1.2, "how to cancel" in 4.9 disclosures), small and
/// quiet under the restore/terms links.
struct PurchaseLegalNote: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .accessibilityIdentifier("paywall.legalNote")
    }
}
