//
//  GambitPaywallPreset.swift
//  PaywallKit
//
//  The lab's DEFAULT paywall ("o modelo que funciona", João 28/09/2026): one call that renders
//  `PurchaseScaffold` in the order and with the decisions of spec/paywall-onboarding-template.md.
//  Thin wrapper — no new visual system. Finding numbers refer to
//  spec/research-2026-09-onboarding-paywall-analytics.md (OPA-n):
//
//    hero → 3 outcome benefits → social proof (only when the app passes REAL data) → 2 plans,
//    hero plan first and pre-selected, the other as a price anchor without trial, per-week
//    equivalent on the yearly (subordinate) → trial timeline while the selected plan has a
//    trial → CTA with trial length + price after the trial → restore/terms + auto-renew note →
//    close button after the cooldown.
//
//  Hero plan (OPA-1/2/3; lab ASC data 29/08-27/09: Cloak weekly + 3 d = 22% trial→paid among
//  resolved trials, n=73, same as RevenueCat's 22,3%; yearly + 7 d across 6 apps = 64%, n=56): `.weeklyHero(trialDays: 3)` for impulse utilities,
//  `.annualHero(trialDays: 7)` for daily-habit apps, `.noTrial(preselect:)` for productivity /
//  party apps. The trial itself is the intro offer configured in App Store Connect; the preset
//  pre-selects, orders, labels and — in DEBUG — reports a store config that breaks the rule
//  (trial on the anchor plan, ≤ 4-day trial on a yearly).
//
//  Usage:
//      GambitPaywallPreset(
//          isPresented: $showPaywall,
//          heroPlan: .annualHero(trialDays: 7),
//          strings: PaywallCopy.strings,               // from templates/copy/paywall.<locale>.json
//          benefits: PaywallCopy.benefits,             // 3 outcomes, not features
//          accentColor: AppColors.primary,
//          heroSymbol: "timer",
//          termsURL: AppConstants.termsURL,
//          privacyURL: AppConstants.privacyURL,
//          source: "onboarding"
//      )
//

import SwiftUI
import StoreKit

// MARK: - Hero Plan

/// Which plan carries the revenue and, with it, the trial. Never a trial on both plans; never a
/// trial toggle (Apple 3.1.2 since Jan/2026, OPA-7).
public enum GambitHeroPlan: Sendable, Equatable {
    /// Impulse utility (vault, anti-theft, calculator, camera): weekly + short trial, yearly direct.
    case weeklyHero(trialDays: Int)
    /// Daily habit / health / education / family: yearly + trial, weekly direct.
    case annualHero(trialDays: Int)
    /// Productivity / lifestyle / party: no trial (trial lowers LTV 14-21% there, OPA-2).
    case noTrial(preselect: PurchasePeriod)

    public var heroPeriod: PurchasePeriod {
        switch self {
        case .weeklyHero: return .week
        case .annualHero: return .year
        case .noTrial(let period): return period
        }
    }

    /// Trial length the app configured in ASC for the hero plan; nil without a trial.
    public var trialDays: Int? {
        switch self {
        case .weeklyHero(let days), .annualHero(let days): return days
        case .noTrial: return nil
        }
    }

    /// What in the store configuration contradicts this hero plan (empty = consistent).
    /// `plans` = (period, trial days or nil) of every product the paywall sells.
    public func violations(in plans: [(period: PurchasePeriod?, trialDays: Int?)]) -> [String] {
        var found: [String] = []
        for plan in plans {
            guard let days = plan.trialDays, days > 0 else { continue }
            if plan.period != heroPeriod || trialDays == nil {
                found.append("trial on a non-hero plan (\(String(describing: plan.period))) — the anchor plan must be direct")
            }
            if plan.period == .year, days <= 4 {
                found.append("yearly trial of \(days) days — ≤ 4 days is the worst yearly cell (24% / 18,3%)")
            }
        }
        return found
    }
}

// MARK: - Strings

/// Every word of the preset, from the app (source: templates/copy/paywall.<locale>.json).
public struct GambitPaywallStrings {
    public var title: String
    /// "Começar 3 dias grátis, depois R$ 14,90/semana" — receives trial days and price per unit.
    public var ctaTrial: (_ trialDays: Int, _ priceAfter: String) -> String
    /// "Assinar por R$ 99,90/ano" — receives the price per unit.
    public var ctaDirect: (_ pricePerUnit: String) -> String
    /// "R$ 1,92 por semana" — subordinate line of the yearly card; nil hides it.
    public var perWeek: ((String) -> String)?
    /// Auto-renew disclosure (renews automatically, cancel in Settings ≥ 24 h before).
    public var legalNote: String
    public var restore: String
    public var terms: String
    public var per: String
    public var then: String
    public var save: String
    public var nothingRestored: String
    public var plansUnavailable: String
    public var retry: String
    public var periodNames: PurchasePeriodNames
    public var trialTimeline: TrialTimelineStrings

    public init(
        title: String,
        ctaTrial: @escaping (Int, String) -> String,
        ctaDirect: @escaping (String) -> String,
        perWeek: ((String) -> String)?,
        legalNote: String,
        restore: String,
        terms: String,
        per: String,
        then: String,
        save: String,
        nothingRestored: String,
        plansUnavailable: String,
        retry: String,
        periodNames: PurchasePeriodNames,
        trialTimeline: TrialTimelineStrings
    ) {
        self.title = title
        self.ctaTrial = ctaTrial
        self.ctaDirect = ctaDirect
        self.perWeek = perWeek
        self.legalNote = legalNote
        self.restore = restore
        self.terms = terms
        self.per = per
        self.then = then
        self.save = save
        self.nothingRestored = nothingRestored
        self.plansUnavailable = plansUnavailable
        self.retry = retry
        self.periodNames = periodNames
        self.trialTimeline = trialTimeline
    }
}

// MARK: - Preset

public struct GambitPaywallPreset: View {
    // MARK: - Defaults
    /// Close button cooldown. No conversion data for any delay value and no documented Apple
    /// rejection text for a short one (search 28/09/2026) — so the kit's historical value stays.
    public static let defaultCloseDelay: CGFloat = 5.0

    // MARK: - Configuration
    @Binding private var isPresented: Bool
    private let heroPlan: GambitHeroPlan
    private let strings: GambitPaywallStrings
    private let benefits: [PurchaseFeature]
    private let accentColor: Color
    private let heroSymbol: String
    private let heroImageName: String?
    private let termsURL: URL?
    private let privacyURL: URL?
    private let socialProof: PurchaseSocialProof?
    private let exitOffer: ExitOfferConfiguration?
    private let closeDelay: CGFloat
    private let source: String
    private let variant: String?
    private let backgroundColor: Color?
    private let palette: PurchasePalette
    private let cornerRadius: CGFloat
    private let previewPlans: [PurchasePlanPreview]

    @ObservedObject private var store = StoreKitManager.shared

    // MARK: - Init
    /// - Parameters:
    ///   - benefits: 3 outcomes (2-4 accepted) — "what your life looks like", not the feature name.
    ///   - socialProof: ONLY the live store rating/count and a real review; nil hides the block.
    ///   - exitOffer: a real intro-offer product; the preset shows it after an ABANDONED purchase
    ///     only (`exitOfferOnDismiss: true` adds the close moment — see the template for the risk).
    ///   - closeDelay: seconds before the X becomes tappable (the ring is visible meanwhile).
    public init(
        isPresented: Binding<Bool>,
        heroPlan: GambitHeroPlan,
        strings: GambitPaywallStrings,
        benefits: [PurchaseFeature],
        accentColor: Color,
        heroSymbol: String = "crown.fill",
        heroImageName: String? = nil,
        termsURL: URL?,
        privacyURL: URL?,
        socialProof: PurchaseSocialProof? = nil,
        exitOffer: ExitOfferConfiguration? = nil,
        exitOfferOnDismiss: Bool = false,
        closeDelay: CGFloat = GambitPaywallPreset.defaultCloseDelay,
        source: String = "onboarding",
        variant: String? = nil,
        backgroundColor: Color? = nil,
        palette: PurchasePalette = PurchasePalette(),
        cornerRadius: CGFloat = 14,
        previewPlans: [PurchasePlanPreview] = []
    ) {
        assert((2...4).contains(benefits.count), "GambitPaywallPreset: 3 outcome benefits (2-4)")
        self._isPresented = isPresented
        self.heroPlan = heroPlan
        self.strings = strings
        self.benefits = benefits
        self.accentColor = accentColor
        self.heroSymbol = heroSymbol
        self.heroImageName = heroImageName
        self.termsURL = termsURL
        self.privacyURL = privacyURL
        self.socialProof = socialProof
        self.exitOffer = exitOffer?.triggered(by: exitOfferOnDismiss ? [.abandon, .dismiss] : [.abandon])
        self.closeDelay = closeDelay
        self.source = source
        self.variant = variant
        self.backgroundColor = backgroundColor
        self.palette = palette
        self.cornerRadius = cornerRadius
        self.previewPlans = previewPlans
    }

    // MARK: - View Body
    public var body: some View {
        PurchaseScaffold(
            isPresented: $isPresented,
            title: strings.title,
            accentColor: accentColor,
            features: benefits,
            heroSymbol: heroSymbol,
            heroImageName: heroImageName,
            termsURL: termsURL,
            privacyURL: privacyURL,
            hasCooldown: true,
            allowCloseAfter: closeDelay,
            restoreText: strings.restore,
            termsText: strings.terms,
            perText: strings.per,
            thenText: strings.then,
            saveText: strings.save,
            nothingRestoredText: strings.nothingRestored,
            plansUnavailableText: strings.plansUnavailable,
            retryText: strings.retry,
            periodNames: strings.periodNames,
            backgroundColor: backgroundColor,
            palette: palette,
            cornerRadius: cornerRadius,
            previewPlans: previewPlans,
            socialProof: socialProof,
            trialTimeline: heroPlan.trialDays == nil ? nil : strings.trialTimeline,
            exitOffer: exitOffer,
            options: options
        )
        .onAppear {
            PaywallAnalytics.variant = variant
            reportStoreMismatch()
        }
        .onChange(of: store.products) { _, _ in reportStoreMismatch() }
    }

    // MARK: - Private
    private var options: PurchaseScaffoldOptions {
        let strings = strings
        return PurchaseScaffoldOptions(
            heroPeriod: heroPlan.heroPeriod,
            ctaText: { context in
                if context.hasTrial, let days = context.trialDays {
                    return strings.ctaTrial(days, context.pricePerUnit)
                }
                return strings.ctaDirect(context.pricePerUnit)
            },
            perWeekText: strings.perWeek,
            legalNote: strings.legalNote,
            source: source,
            placement: "gambit_preset"
        )
    }

    /// DEBUG only: says in the console when the ASC/.storekit config contradicts the hero plan.
    private func reportStoreMismatch() {
        #if DEBUG
        let plans = store.products.map { product in
            (period: product.subscription.map { PurchasePeriod.of($0.subscriptionPeriod) },
             trialDays: TrialTimeline.days(of: product))
        }
        for issue in heroPlan.violations(in: plans) {
            print("[GambitPaywallPreset] store config: \(issue)")
        }
        #endif
    }
}
