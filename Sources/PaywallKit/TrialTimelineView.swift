//
//  TrialTimelineView.swift
//  PaywallKit
//
//  "How your free trial works" — three milestones: today (full access), a reminder before
//  the charge, and the charge itself. The objection #1 on a trial paywall is "I will forget
//  to cancel and get charged"; showing the schedule and promising the reminder lifted trial
//  starts 23% and cut complaints 55% (research 2026-09, finding 6). Apple also asks for the
//  trial length and the post-trial price on the purchase screen (finding 8) — this view is
//  both at once.
//
//  Asset-free; every string comes from the app. The days come from the product's intro
//  period (`TrialTimeline.days(of:)`), never from a hard-coded 7. `PurchaseScaffold` renders it
//  under the plan cards while the selected plan has a trial; it can also be used standalone.
//
//  Usage:
//      TrialTimelineView(
//          trialDays: 7,
//          price: "R$ 99,90 / ano",
//          strings: TrialTimelineStrings(
//              todayLabel: String(localized: "trial.today"),
//              dayLabel: { String(localized: "trial.day \($0)") },
//              accessTitle: String(localized: "trial.access"),
//              reminderTitle: String(localized: "trial.reminder"),
//              chargeTitle: { String(localized: "trial.charge \($0)") }
//          ),
//          accentColor: AppColors.primary
//      )
//

import SwiftUI
import StoreKit

// MARK: - Strings

/// Localized copy of the timeline. The kit never ships user-facing text.
public struct TrialTimelineStrings: Sendable {
    /// "Today".
    public var todayLabel: String
    /// "Day 5" — receives the day number.
    public var dayLabel: @Sendable (Int) -> String
    /// "Full access, all features unlocked".
    public var accessTitle: String
    /// "We remind you before the trial ends".
    public var reminderTitle: String
    /// "You are charged R$ 99,90 / year" — receives the price the app wants shown.
    public var chargeTitle: @Sendable (String) -> String
    /// Optional footnote under the milestones ("Cancel anytime in Settings, no charge").
    public var cancelNote: String?

    public init(
        todayLabel: String,
        dayLabel: @escaping @Sendable (Int) -> String,
        accessTitle: String,
        reminderTitle: String,
        chargeTitle: @escaping @Sendable (String) -> String,
        cancelNote: String? = nil
    ) {
        self.todayLabel = todayLabel
        self.dayLabel = dayLabel
        self.accessTitle = accessTitle
        self.reminderTitle = reminderTitle
        self.chargeTitle = chargeTitle
        self.cancelNote = cancelNote
    }
}

// MARK: - Timeline Model

/// The three milestones of a trial of `trialDays` days.
public struct TrialTimeline: Sendable, Equatable {
    public let trialDays: Int
    /// Day the reminder lands: two days before the charge, never before day 1.
    public var reminderDay: Int { max(1, trialDays - 2) }
    /// Day the first charge happens.
    public var chargeDay: Int { trialDays }

    public init(trialDays: Int) {
        self.trialDays = max(1, trialDays)
    }

    /// Trial length in days from the product's introductory offer; nil when it has no free trial.
    public static func days(of product: Product) -> Int? {
        guard let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        return days(unit: offer.period.unit, value: offer.period.value)
    }

    /// Calendar days of a StoreKit period (a week is 7, a month 30, a year 365).
    public static func days(unit: Product.SubscriptionPeriod.Unit, value: Int) -> Int {
        switch unit {
        case .day: return value
        case .week: return value * 7
        case .month: return value * 30
        case .year: return value * 365
        @unknown default: return value
        }
    }

    /// Same, from a normalised `(count, period)` pair (preview plans).
    public static func days(count: Int, period: PurchasePeriod) -> Int {
        switch period {
        case .day: return count
        case .week: return count * 7
        case .month: return count * 30
        case .year: return count * 365
        }
    }
}

// MARK: - TrialTimelineView

public struct TrialTimelineView: View {
    // MARK: - Configuration
    private let timeline: TrialTimeline
    private let price: String
    private let strings: TrialTimelineStrings
    private let accentColor: Color
    private let palette: PurchasePalette
    private let cornerRadius: CGFloat

    // MARK: - Init
    /// - Parameters:
    ///   - trialDays: length of the trial (use `TrialTimeline.days(of:)` on the product).
    ///   - price: the post-trial price as the app wants it read ("R$ 99,90 / ano").
    ///   - palette: same `PurchasePalette` the paywall uses, so the card matches its plan cards.
    public init(
        trialDays: Int,
        price: String,
        strings: TrialTimelineStrings,
        accentColor: Color,
        palette: PurchasePalette = PurchasePalette(),
        cornerRadius: CGFloat = 6
    ) {
        self.timeline = TrialTimeline(trialDays: trialDays)
        self.price = price
        self.strings = strings
        self.accentColor = accentColor
        self.palette = palette
        self.cornerRadius = cornerRadius
    }

    // MARK: - View Body
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            milestone(symbol: "lock.open.fill", label: strings.todayLabel, title: strings.accessTitle,
                      isFirst: true, isLast: false, id: "today")
            milestone(symbol: "bell.fill", label: strings.dayLabel(timeline.reminderDay), title: strings.reminderTitle,
                      isFirst: false, isLast: false, id: "reminder")
            milestone(symbol: "creditcard.fill", label: strings.dayLabel(timeline.chargeDay), title: strings.chargeTitle(price),
                      isFirst: false, isLast: true, id: "charge")
            if let note = strings.cancelNote {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(palette.supportingText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
                    .padding(.leading, 40)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: cornerRadius).fill(palette.cardFill))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(palette.cardBorder, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("paywall.trialTimeline")
    }

    // MARK: - Subviews
    /// One row: a dot on a vertical rail (the rail is hidden above the first and below the last).
    private func milestone(symbol: String, label: String, title: String, isFirst: Bool, isLast: Bool, id: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(accentColor.opacity(isFirst ? 0 : 0.35))
                    .frame(width: 2, height: 8)
                ZStack {
                    Circle().fill(accentColor.opacity(0.15)).frame(width: 28, height: 28)
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
                Rectangle()
                    .fill(accentColor.opacity(isLast ? 0 : 0.35))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accentColor)
                    .textCase(.uppercase)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(palette.text)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
            .padding(.bottom, isLast ? 0 : 10)

            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("paywall.trialTimeline.\(id)")
        .accessibilityLabel("\(label), \(title)")
    }
}
