//
//  PurchaseScaffoldComponents.swift
//  PaywallKit
//
//  Supporting types and subviews for PurchaseScaffold: a display model derived
//  from a StoreKit Product, pricing math (save %), the feature row and the
//  selectable plan card.
//
//  Adapted for GambitStudio from Paywall-PurchaseView-SwiftUI by Adam Lyttle
//  (https://github.com/adamlyttleapps/Paywall-PurchaseView-SwiftUI, MIT).
//

import SwiftUI
import StoreKit

// MARK: - Period

/// The billing period a plan renews on, normalised away from how StoreKit
/// happens to express it (a weekly product can arrive as `.day` × 7).
public enum PurchasePeriod: Sendable, Hashable {
    case day, week, month, year

    /// Collapses a raw StoreKit period into the period a user would name it.
    public static func normalised(unit: Product.SubscriptionPeriod.Unit, value: Int) -> PurchasePeriod {
        switch unit {
        case .day:
            if value % 365 == 0 { return .year }
            if value % 30 == 0 || value % 31 == 0 { return .month }
            if value % 7 == 0 { return .week }
            return .day
        case .week:
            if value >= 52 { return .year }
            if value >= 4 { return .month }
            return .week
        case .month:
            return value >= 12 ? .year : .month
        case .year:
            return .year
        @unknown default:
            return .month
        }
    }

    public static func of(_ period: Product.SubscriptionPeriod) -> PurchasePeriod {
        normalised(unit: period.unit, value: period.value)
    }

    /// Normalises a raw period into the (count, period) pair a user would say:
    /// `.day × 7` → (1, .week), `.day × 14` → (2, .week), `.day × 3` → (3, .day),
    /// `.week × 1` → (1, .week), `.month × 12` → (1, .year). Use it for trial wording,
    /// so a 7-day trial that StoreKit reports as `.day × 7` reads "1-Week", not "7-Week".
    public static func normalisedCount(unit: Product.SubscriptionPeriod.Unit, value: Int) -> (count: Int, period: PurchasePeriod) {
        let period = normalised(unit: unit, value: value)
        switch (unit, period) {
        case (.day, .week): return (max(1, value / 7), .week)
        case (.day, .month): return (max(1, value / 30), .month)
        case (.day, .year): return (max(1, value / 365), .year)
        case (.week, .month): return (max(1, value / 4), .month)
        case (.week, .year): return (max(1, value / 52), .year)
        case (.month, .year): return (max(1, value / 12), .year)
        default: return (max(1, value), period)
        }
    }

    public static func countOf(_ period: Product.SubscriptionPeriod) -> (count: Int, period: PurchasePeriod) {
        normalisedCount(unit: period.unit, value: period.value)
    }
}

// MARK: - Period Names

/// Localised wording for plan periods. The kit ships English; every app passes
/// its own so the paywall speaks the same language as the rest of the UI.
public struct PurchasePeriodNames: Sendable {
    public var planName: @Sendable (PurchasePeriod) -> String
    public var unitName: @Sendable (PurchasePeriod) -> String
    public var trialName: @Sendable (Int, PurchasePeriod) -> String

    public init(
        planName: @escaping @Sendable (PurchasePeriod) -> String,
        unitName: @escaping @Sendable (PurchasePeriod) -> String,
        trialName: @escaping @Sendable (Int, PurchasePeriod) -> String
    ) {
        self.planName = planName
        self.unitName = unitName
        self.trialName = trialName
    }

    public static let english = PurchasePeriodNames(
        planName: { period in
            switch period {
            case .day: return "Daily Plan"
            case .week: return "Weekly Plan"
            case .month: return "Monthly Plan"
            case .year: return "Yearly Plan"
            }
        },
        unitName: { period in
            switch period {
            case .day: return "day"
            case .week: return "week"
            case .month: return "month"
            case .year: return "year"
            }
        },
        trialName: { count, period in
            let unit: String
            switch period {
            case .day: unit = "Day"
            case .week: unit = "Week"
            case .month: unit = "Month"
            case .year: unit = "Year"
            }
            return "\(count)-\(unit) Trial"
        }
    )
}

// MARK: - Palette

/// Colors of the purchase scaffold that are not the accent. Defaults derive from the
/// current foreground (`Color.primary` at reduced opacity) so the kit follows the host's
/// color scheme without touching system greys; apps pass their `AppColors` for an exact
/// match with the rest of the UI.
public struct PurchasePalette: Sendable {
    /// Title, benefit copy, plan names, close button.
    public var text: Color
    /// Plan price line, "plans unavailable" message.
    public var supportingText: Color
    /// Restore / terms links and their underline.
    public var footerText: Color
    /// Plan card stroke when not selected.
    public var cardBorder: Color
    /// Plan card fill when not selected.
    public var cardFill: Color
    /// Text on top of the accent (CTA label, check mark, badge).
    public var onAccent: Color
    /// Fill of the "SAVE nn%" badge.
    public var badgeFill: Color

    public init(
        text: Color = Color.primary,
        supportingText: Color = Color.primary.opacity(0.65),
        footerText: Color = Color.primary.opacity(0.55),
        cardBorder: Color = Color.primary.opacity(0.15),
        cardFill: Color = Color.primary.opacity(0.03),
        onAccent: Color = .white,
        badgeFill: Color = .red
    ) {
        self.text = text
        self.supportingText = supportingText
        self.footerText = footerText
        self.cardBorder = cardBorder
        self.cardFill = cardFill
        self.onAccent = onAccent
        self.badgeFill = badgeFill
    }
}

// MARK: - Plan Preview

/// Display-only plan for screenshots and simulator QA, used by `PurchaseScaffold`
/// only while StoreKit has no products. It renders the same card as a real product;
/// tapping the CTA does nothing because there is no `Product` to buy.
public struct PurchasePlanPreview: Identifiable, Sendable {
    public let id: String
    /// Localised price as the store would display it ("R$ 29,90").
    public let price: String
    /// Numeric price, so the save-% badge can be computed against the weekly plan.
    public let priceValue: Decimal
    public let period: PurchasePeriod?
    /// Free-trial length; 0 = no trial.
    public let trialCount: Int
    public let trialPeriod: PurchasePeriod

    public init(
        id: String,
        price: String,
        priceValue: Decimal,
        period: PurchasePeriod?,
        trialCount: Int = 0,
        trialPeriod: PurchasePeriod = .week
    ) {
        self.id = id
        self.price = price
        self.priceValue = priceValue
        self.period = period
        self.trialCount = trialCount
        self.trialPeriod = trialPeriod
    }
}

// MARK: - Plan Display Model

/// A presentation model derived from a StoreKit `Product`.
struct PurchasePlan: Identifiable {
    // MARK: - Properties
    let id: String
    let price: String
    let priceValue: Decimal
    let period: PurchasePeriod?
    let unitLabel: String
    let durationPlanName: String
    let hasTrial: Bool
    /// Length of the free trial in calendar days (nil without a trial) — feeds `TrialTimelineView`.
    let trialDays: Int?

    // MARK: - Init
    init(product: Product, names: PurchasePeriodNames) {
        self.id = product.id
        self.price = product.displayPrice
        self.priceValue = product.price
        self.period = product.subscription.map { PurchasePeriod.of($0.subscriptionPeriod) }
        self.unitLabel = self.period.map(names.unitName) ?? ""
        self.hasTrial = product.subscription?.introductoryOffer?.paymentMode == .freeTrial
        self.trialDays = TrialTimeline.days(of: product)

        if hasTrial, let offer = product.subscription?.introductoryOffer {
            // Count and unit are normalised together: a 7-day trial reported as
            // `.day × 7` must read "1-Week Trial", never "7-Week Trial".
            let trial = PurchasePeriod.countOf(offer.period)
            self.durationPlanName = names.trialName(trial.count, trial.period)
        } else if let period = self.period {
            self.durationPlanName = names.planName(period)
        } else {
            self.durationPlanName = product.displayName
        }
    }

    init(preview: PurchasePlanPreview, names: PurchasePeriodNames) {
        self.id = preview.id
        self.price = preview.price
        self.priceValue = preview.priceValue
        self.period = preview.period
        self.unitLabel = preview.period.map(names.unitName) ?? ""
        self.hasTrial = preview.trialCount > 0
        self.trialDays = hasTrial ? TrialTimeline.days(count: preview.trialCount, period: preview.trialPeriod) : nil

        if hasTrial {
            self.durationPlanName = names.trialName(preview.trialCount, preview.trialPeriod)
        } else if let period = preview.period {
            self.durationPlanName = names.planName(period)
        } else {
            self.durationPlanName = preview.id
        }
    }
}

// MARK: - Pricing

enum PurchasePricing {
    /// Annualised weekly price used to strike-through the yearly plan.
    static func annualisedWeeklyPrice(in plans: [PurchasePlan]) -> Decimal? {
        guard let weekly = plans.first(where: { $0.period == .week }) else { return nil }
        return weekly.priceValue * 52
    }

    /// Percentage saved by the yearly plan vs paying weekly for a year.
    /// `nil` when there is no weekly plan to compare against or no real saving —
    /// the badge is hidden then instead of showing a made-up number.
    static func percentageSaved(in plans: [PurchasePlan]) -> Int? {
        guard
            let fullPrice = annualisedWeeklyPrice(in: plans),
            fullPrice > 0,
            let yearly = plans.first(where: { $0.period == .year })
        else { return nil }

        let ratio = (yearly.priceValue / fullPrice) as NSDecimalNumber
        let saved = 100 - Int(ratio.doubleValue * 100)
        return saved > 0 ? saved : nil
    }

    /// Localised currency string for an annualised value, matched to a sample plan's locale.
    static func annualisedDisplay(in plans: [PurchasePlan]) -> String? {
        guard
            let value = annualisedWeeklyPrice(in: plans),
            let weekly = plans.first(where: { $0.period == .week })?.priceFormat
        else { return nil }
        return weekly.string(from: value as NSDecimalNumber)
    }
}

private extension PurchasePlan {
    /// A currency formatter inferred from the displayed price string.
    var priceFormat: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter
    }
}

// MARK: - Feature Row

struct PurchaseFeatureRow: View {
    // MARK: - Properties
    let feature: PurchaseFeature
    let accentColor: Color
    var palette = PurchasePalette()

    // MARK: - View Body
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: feature.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 27, height: 27)
                .foregroundStyle(accentColor)
            Text(feature.title)
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 32)
    }
}

// MARK: - Plan Card

struct PurchasePlanCard: View {
    // MARK: - Properties
    let plan: PurchasePlan
    let isSelected: Bool
    let accentColor: Color
    var palette = PurchasePalette()
    var cornerRadius: CGFloat = 6
    let thenText: String
    let perText: String
    let saveText: String
    let percentageSaved: Int?
    /// Dense paywall: smaller badge and padding so the CTA stays above the fold.
    var compact = false

    // MARK: - View Body
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(plan.durationPlanName)
                    .font(.headline.bold())
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(plan.hasTrial ? "\(thenText) \(plan.price) \(perPhrase)" : "\(plan.price) \(perPhrase)")
                    .font(compact ? .subheadline : .body)
                    .foregroundStyle(palette.supportingText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            // Savings badge only on the yearly plan, and only when a weekly plan gives a real comparison.
            if plan.period == .year, let saved = percentageSaved {
                Text("\(saveText) \(saved)%")
                    .font(compact ? .caption2.bold() : .caption.bold())
                    .foregroundStyle(palette.onAccent)
                    .padding(compact ? 6 : 8)
                    .background(palette.badgeFill)
                    .cornerRadius(min(6, cornerRadius))
            }

            selectionIndicator
        }
        .padding(.horizontal)
        .padding(.vertical, compact ? 8 : 10)
        .frame(minHeight: compact ? 50 : 56)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(isSelected ? accentColor.opacity(0.08) : palette.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(isSelected ? accentColor : palette.cardBorder, lineWidth: isSelected ? 1.5 : 1)
        )
    }

    // MARK: - Subviews
    private var perPhrase: String {
        plan.unitLabel.isEmpty ? "" : "\(perText) \(plan.unitLabel)"
    }

    private var selectionIndicator: some View {
        ZStack {
            Image(systemName: isSelected ? "circle.fill" : "circle")
                .foregroundStyle(isSelected ? accentColor : palette.cardBorder)
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(palette.onAccent)
                    .scaleEffect(0.7)
            }
        }
        .font(.title3.bold())
    }
}

// MARK: - Hero

/// The paywall hero (asset image or SF Symbol) with the periodic "shake" that draws the eye.
struct PurchaseHeroView: View {
    // MARK: - Properties
    let heroSymbol: String
    let heroImageName: String?
    let accentColor: Color
    let height: CGFloat

    // MARK: - State
    @State private var shakeDegrees: Double = 0
    @State private var shakeZoom: CGFloat = 0.9

    // MARK: - View Body
    var body: some View {
        Group {
            if let heroImageName {
                Image(heroImageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: heroSymbol)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(accentColor)
            }
        }
        .frame(height: height)
        .scaleEffect(shakeZoom)
        .rotationEffect(.degrees(shakeDegrees))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { startShaking() }
        }
    }

    // MARK: - Shake
    private func startShaking() {
        let total = 0.7
        let shakes = 3
        let initialAngle = 10.0

        withAnimation(.easeInOut(duration: total / 2)) {
            shakeZoom = 0.95
            DispatchQueue.main.asyncAfter(deadline: .now() + total / 2) {
                withAnimation(.easeInOut(duration: total / 2)) { shakeZoom = 0.9 }
            }
        }

        for i in 0..<shakes {
            let delay = (total / Double(shakes)) * Double(i)
            let angle = initialAngle - (initialAngle / Double(shakes)) * Double(i)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: total / Double(shakes * 2))) { shakeDegrees = angle }
                withAnimation(.easeInOut(duration: total / Double(shakes * 2)).delay(total / Double(shakes * 2))) {
                    shakeDegrees = -angle
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + total) {
            withAnimation { shakeDegrees = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { startShaking() }
        }
    }
}
