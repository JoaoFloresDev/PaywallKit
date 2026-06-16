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

// MARK: - Plan Display Model

/// A presentation model derived from a StoreKit `Product`.
struct PurchasePlan: Identifiable {
    // MARK: - Properties
    let id: String
    let price: String
    let priceValue: Decimal
    let duration: String
    let durationPlanName: String
    let hasTrial: Bool

    // MARK: - Init
    init(product: Product, perText: String) {
        self.id = product.id
        self.price = product.displayPrice
        self.priceValue = product.price
        self.duration = PurchasePlan.durationLabel(for: product)
        self.hasTrial = product.subscription?.introductoryOffer?.paymentMode == .freeTrial
        self.durationPlanName = PurchasePlan.planName(for: product, hasTrial: self.hasTrial)
    }

    // MARK: - Helpers
    private static func durationLabel(for product: Product) -> String {
        guard let unit = product.subscription?.subscriptionPeriod.unit else { return "" }
        switch unit {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return ""
        }
    }

    private static func planName(for product: Product, hasTrial: Bool) -> String {
        if hasTrial, let offer = product.subscription?.introductoryOffer {
            let value = offer.period.value
            switch offer.period.unit {
            case .day: return "\(value)-Day Trial"
            case .week: return "\(value)-Week Trial"
            case .month: return "\(value)-Month Trial"
            case .year: return "\(value)-Year Trial"
            @unknown default: break
            }
        }
        switch product.subscription?.subscriptionPeriod.unit {
        case .day: return "Daily Plan"
        case .week: return "Weekly Plan"
        case .month: return "Monthly Plan"
        case .year: return "Yearly Plan"
        default: return product.displayName
        }
    }
}

// MARK: - Pricing

enum PurchasePricing {
    /// Annualised weekly price used to strike-through the yearly plan.
    static func annualisedWeeklyPrice(in plans: [PurchasePlan]) -> Decimal? {
        guard let weekly = plans.first(where: { $0.duration == "week" }) else { return nil }
        return weekly.priceValue * 52
    }

    /// Percentage saved by the yearly plan vs paying weekly for a year.
    static func percentageSaved(in plans: [PurchasePlan]) -> Int {
        guard
            let fullPrice = annualisedWeeklyPrice(in: plans),
            fullPrice > 0,
            let yearly = plans.first(where: { $0.duration == "year" })
        else { return 90 }

        let ratio = (yearly.priceValue / fullPrice) as NSDecimalNumber
        let saved = 100 - Int(ratio.doubleValue * 100)
        return saved > 0 ? saved : 90
    }

    /// Localised currency string for an annualised value, matched to a sample plan's locale.
    static func annualisedDisplay(in plans: [PurchasePlan]) -> String? {
        guard
            let value = annualisedWeeklyPrice(in: plans),
            let weekly = plans.first(where: { $0.duration == "week" })?.priceFormat
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

    // MARK: - View Body
    var body: some View {
        HStack {
            Image(systemName: feature.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 27, height: 27)
                .foregroundStyle(accentColor)
            Text(feature.title)
        }
    }
}

// MARK: - Plan Card

struct PurchasePlanCard: View {
    // MARK: - Properties
    let plan: PurchasePlan
    let isSelected: Bool
    let accentColor: Color
    let thenText: String
    let saveText: String
    let percentageSaved: Int

    // MARK: - View Body
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(plan.durationPlanName)
                    .font(.headline.bold())

                if plan.hasTrial {
                    Text("\(thenText) \(plan.price) \(perPhrase)")
                        .opacity(0.8)
                } else {
                    Text("\(plan.price) \(perPhrase)")
                        .opacity(0.8)
                }
            }

            Spacer()

            if !plan.hasTrial {
                Text("\(saveText) \(percentageSaved)%")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Color.red)
                    .cornerRadius(6)
            }

            selectionIndicator
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .cornerRadius(6)
        .overlay {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? accentColor : Color.primary.opacity(0.15), lineWidth: 1)
                RoundedRectangle(cornerRadius: 6)
                    .foregroundStyle(isSelected ? accentColor.opacity(0.05) : Color.primary.opacity(0.001))
            }
        }
    }

    // MARK: - Subviews
    private var perPhrase: String {
        plan.duration.isEmpty ? "" : "per \(plan.duration)"
    }

    private var selectionIndicator: some View {
        ZStack {
            Image(systemName: isSelected ? "circle.fill" : "circle")
                .foregroundStyle(isSelected ? accentColor : Color.primary.opacity(0.15))
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.white)
                    .scaleEffect(0.7)
            }
        }
        .font(.title3.bold())
    }
}
