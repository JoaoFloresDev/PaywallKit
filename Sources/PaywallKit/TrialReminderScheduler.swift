//
//  TrialReminderScheduler.swift
//  PaywallKit
//
//  Local notifications that keep the promise the paywall timeline makes ("we remind you
//  before the trial ends"): a value nudge 6 h after the purchase, a heads-up 2 days before the
//  charge and one on the morning of the last day (research 2026-09, finding 6 — RevenueCat's
//  three pushes; Blinkist's opt-in went 6% → 74% when the reminder was promised).
//
//  Nothing is scheduled unless the user opts in on the post-purchase screen
//  (`PostPurchaseView(onEnableReminders:)`): `enable(trialEnd:strings:)` requests the
//  notification permission, then schedules. `StoreKitManager` cancels the reminders when a
//  transaction that is no longer a free trial arrives (the trial converted or the user changed
//  plan), so no "your trial ends soon" lands on a paying subscriber. Every reminder emits
//  `trial_reminder_scheduled` (`days_before`, `kind`) through `PaywallAnalytics`.
//
//  Usage (post-purchase screen):
//      PostPurchaseView(
//          ...,
//          remindersButtonText: String(localized: "postPurchase.reminders"),
//          onEnableReminders: {
//              guard let end = StoreKitManager.shared.trialEndDate else { return }
//              _ = await TrialReminderScheduler.enable(trialEnd: end, strings: reminderStrings)
//          }
//      )
//

import Foundation
import StoreKit
import UserNotifications

// MARK: - Strings

/// Copy of the three reminders. The kit never ships user-facing text.
public struct TrialReminderStrings: Sendable {
    /// 6 h after the purchase: point at the feature worth opening today.
    public var valueNudgeTitle: String
    public var valueNudgeBody: String
    /// 2 days before the charge — the body receives the days left.
    public var beforeEndTitle: String
    public var beforeEndBody: @Sendable (Int) -> String
    /// Morning of the last free day.
    public var lastDayTitle: String
    public var lastDayBody: String

    public init(
        valueNudgeTitle: String,
        valueNudgeBody: String,
        beforeEndTitle: String,
        beforeEndBody: @escaping @Sendable (Int) -> String,
        lastDayTitle: String,
        lastDayBody: String
    ) {
        self.valueNudgeTitle = valueNudgeTitle
        self.valueNudgeBody = valueNudgeBody
        self.beforeEndTitle = beforeEndTitle
        self.beforeEndBody = beforeEndBody
        self.lastDayTitle = lastDayTitle
        self.lastDayBody = lastDayBody
    }
}

// MARK: - Reminder

public enum TrialReminderKind: String, CaseIterable, Sendable {
    case valueNudge = "value_nudge"
    case beforeEnd = "before_end"
    case lastDay = "last_day"
}

/// One planned reminder: when it fires and how many whole days before the charge that is.
public struct TrialReminder: Sendable, Equatable {
    public let kind: TrialReminderKind
    public let fireDate: Date
    public let daysBefore: Int

    var identifier: String { TrialReminderScheduler.identifierPrefix + kind.rawValue }
}

// MARK: - Scheduler

public enum TrialReminderScheduler {
    // MARK: - Constants
    static let identifierPrefix = "paywallkit.trialReminder."
    static let scheduledKey = "paywallkit.trialReminders.scheduled"

    // MARK: - Planning
    /// The reminders that still make sense for a trial ending at `trialEnd`, in firing order.
    /// Pure: `now` and `calendar` are injectable for tests. Skips anything already in the past,
    /// anything that would land after the charge, and the value nudge on trials too short for it.
    public static func plan(trialEnd: Date, now: Date = Date(), calendar: Calendar = .current) -> [TrialReminder] {
        var reminders: [TrialReminder] = []
        let hour: TimeInterval = 3_600
        let day: TimeInterval = 86_400

        let nudge = now.addingTimeInterval(6 * hour)
        if nudge < trialEnd.addingTimeInterval(-12 * hour) {
            reminders.append(TrialReminder(kind: .valueNudge, fireDate: nudge, daysBefore: wholeDays(from: nudge, to: trialEnd)))
        }

        let twoDaysBefore = at(hour: 10, daysBefore: 2, of: trialEnd, calendar: calendar)
            ?? trialEnd.addingTimeInterval(-2 * day)
        if twoDaysBefore > now.addingTimeInterval(hour), twoDaysBefore < trialEnd {
            reminders.append(TrialReminder(kind: .beforeEnd, fireDate: twoDaysBefore, daysBefore: 2))
        }

        var lastDay = at(hour: 9, daysBefore: 0, of: trialEnd, calendar: calendar) ?? trialEnd.addingTimeInterval(-12 * hour)
        if lastDay >= trialEnd { lastDay = trialEnd.addingTimeInterval(-12 * hour) }
        if lastDay > now.addingTimeInterval(hour),
           lastDay > (reminders.last?.fireDate ?? .distantPast).addingTimeInterval(hour) {
            reminders.append(TrialReminder(kind: .lastDay, fireDate: lastDay, daysBefore: 0))
        }
        return reminders
    }

    // MARK: - Scheduling
    /// Opt-in path for the post-purchase button: asks for the notification permission (alert +
    /// sound) and, if granted, schedules the reminders. Returns whether anything was scheduled.
    @discardableResult
    public static func enable(trialEnd: Date, strings: TrialReminderStrings, now: Date = Date()) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return false }
        let scheduled = await schedule(trialEnd: trialEnd, strings: strings, now: now, center: center)
        return !scheduled.isEmpty
    }

    /// Schedules without asking (the app already holds the permission). Replaces any reminders
    /// the kit scheduled before. Returns what was queued.
    @discardableResult
    public static func schedule(
        trialEnd: Date,
        strings: TrialReminderStrings,
        now: Date = Date(),
        center: UNUserNotificationCenter = .current()
    ) async -> [TrialReminder] {
        cancel(center: center)
        let reminders = plan(trialEnd: trialEnd, now: now)
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            switch reminder.kind {
            case .valueNudge:
                content.title = strings.valueNudgeTitle
                content.body = strings.valueNudgeBody
            case .beforeEnd:
                content.title = strings.beforeEndTitle
                content.body = strings.beforeEndBody(reminder.daysBefore)
            case .lastDay:
                content.title = strings.lastDayTitle
                content.body = strings.lastDayBody
            }
            content.sound = .default
            content.userInfo = ["kind": "trial", "reminder": reminder.kind.rawValue]
            let seconds = max(1, reminder.fireDate.timeIntervalSince(now))
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            let request = UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)
            do {
                try await center.add(request)
                PaywallAnalytics.log(PaywallAnalytics.Event.trialReminderScheduled,
                                     ["days_before": reminder.daysBefore, "kind": reminder.kind.rawValue])
            } catch {
                continue
            }
        }
        UserDefaults.standard.set(!reminders.isEmpty, forKey: scheduledKey)
        return reminders
    }

    /// Removes the kit's pending reminders (only those — the app's own notifications stay).
    public static func cancel(center: UNUserNotificationCenter = .current()) {
        let ids = TrialReminderKind.allCases.map { identifierPrefix + $0.rawValue }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        UserDefaults.standard.set(false, forKey: scheduledKey)
    }

    /// True while reminders scheduled by the kit are believed pending.
    public static var isScheduled: Bool {
        UserDefaults.standard.bool(forKey: scheduledKey)
    }

    // MARK: - Transactions
    /// End of the free trial a transaction represents; nil when it is not a free-trial period.
    @available(iOS 17.2, *)
    public static func trialEnd(of transaction: Transaction) -> Date? {
        guard transaction.offer?.paymentMode == .freeTrial else { return nil }
        return transaction.expirationDate
    }

    // MARK: - Helpers
    private static func wholeDays(from: Date, to: Date) -> Int {
        max(0, Int(to.timeIntervalSince(from) / 86_400))
    }

    /// `hour`:00 local time, `daysBefore` calendar days before `date`'s day.
    private static func at(hour: Int, daysBefore: Int, of date: Date, calendar: Calendar) -> Date? {
        guard let day = calendar.date(byAdding: .day, value: -daysBefore, to: date) else { return nil }
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = 0
        return calendar.date(from: components)
    }
}
