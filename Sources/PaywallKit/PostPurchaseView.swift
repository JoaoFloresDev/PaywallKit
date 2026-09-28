//
//  PostPurchaseView.swift
//  PaywallKit
//
//  Shown right after a successful purchase: what the user just unlocked plus ONE next
//  step. A confirmation with a concrete next action keeps day-0 cancellations down
//  (research 2026-09, findings 6 and 9). Asset-free: every string comes from the app,
//  the hero is an SF Symbol. Present it when `StoreKitManager.shared.isPremium` flips
//  to true (or from the `purchase(_:)` result) — the kit never presents it by itself.
//
//  Usage:
//      .fullScreenCover(isPresented: $showPostPurchase) {
//          PostPurchaseView(
//              gradient: [AppColors.primary, AppColors.primary.opacity(0.85)],
//              title: String(localized: "postPurchase.title"),
//              subtitle: String(localized: "postPurchase.subtitle"),
//              unlocked: [
//                  .init(symbol: "infinity", title: String(localized: "postPurchase.unlocked1")),
//                  .init(symbol: "sparkles", title: String(localized: "postPurchase.unlocked2")),
//                  .init(symbol: "icloud.fill", title: String(localized: "postPurchase.unlocked3"))
//              ],
//              primaryButtonText: String(localized: "postPurchase.cta"),
//              onPrimary: { showPostPurchase = false; openFirstProFeature() },
//              notificationsButtonText: String(localized: "postPurchase.notifications"),
//              onEnableNotifications: { await NotificationService.shared.requestAuthorization() }
//          )
//      }
//

import SwiftUI

// MARK: - PostPurchaseView

public struct PostPurchaseView: View {
    // MARK: - Configuration
    private let gradient: [Color]
    private let accent: Color
    private let heroSymbol: String
    private let title: String
    private let subtitle: String?
    private let unlocked: [PaywallFeatureItem]
    private let primaryButtonText: String
    private let onPrimary: () -> Void
    private let notificationsButtonText: String?
    private let onEnableNotifications: (@MainActor () async -> Void)?

    // MARK: - State
    @State private var showHero = false
    @State private var showTitle = false
    @State private var visibleRows = 0
    @State private var showButtons = false
    @State private var isRequestingNotifications = false
    @State private var notificationsHandled = false

    // MARK: - Init
    /// - Parameters:
    ///   - unlocked: 2-3 "what you unlocked" rows (max 4). Concrete outcomes, not the plan list.
    ///   - onPrimary: the ONE next step (open the feature the user came for); host dismisses.
    ///   - onEnableNotifications: optional secondary action that requests the notification
    ///     permission. The button shows a spinner until it returns and is hidden afterwards
    ///     (asked once here; the app keeps its own toggle in Settings). Omit both
    ///     notification parameters to hide the secondary button.
    public init(
        gradient: [Color],
        title: String,
        subtitle: String? = nil,
        unlocked: [PaywallFeatureItem],
        primaryButtonText: String,
        onPrimary: @escaping () -> Void,
        notificationsButtonText: String? = nil,
        onEnableNotifications: (@MainActor () async -> Void)? = nil,
        heroSymbol: String = "checkmark.seal.fill",
        accent: Color? = nil
    ) {
        precondition(gradient.count >= 2, "PostPurchaseView requires at least 2 gradient colors")
        precondition(!unlocked.isEmpty && unlocked.count <= 4, "PostPurchaseView shows 2-3 unlocked rows (max 4)")
        self.gradient = gradient
        self.accent = accent ?? gradient.first ?? .blue
        self.heroSymbol = heroSymbol
        self.title = title
        self.subtitle = subtitle
        self.unlocked = unlocked
        self.primaryButtonText = primaryButtonText
        self.onPrimary = onPrimary
        self.notificationsButtonText = notificationsButtonText
        self.onEnableNotifications = onEnableNotifications
    }

    private var showsNotificationsButton: Bool {
        notificationsButtonText != nil && onEnableNotifications != nil && !notificationsHandled
    }

    // MARK: - View Body
    public var body: some View {
        ZStack {
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)
                hero
                titleBlock
                    .padding(.top, 24)
                unlockedList
                    .padding(.top, 28)
                Spacer(minLength: 24)
                buttons
            }
            .padding(.horizontal, 24)
        }
        .onAppear(perform: handleAppear)
    }

    // MARK: - Subviews
    private var hero: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 120, height: 120)
            Image(systemName: heroSymbol)
                .font(.system(size: 56, weight: .semibold))
                .foregroundStyle(.white)
        }
        .scaleEffect(showHero ? 1 : 0.6)
        .opacity(showHero ? 1 : 0)
    }

    private var titleBlock: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(showTitle ? 1 : 0)
        .offset(y: showTitle ? 0 : 16)
    }

    private var unlockedList: some View {
        VStack(spacing: 12) {
            ForEach(Array(unlocked.enumerated()), id: \.element.id) { index, item in
                unlockedRow(item)
                    .opacity(index < visibleRows ? 1 : 0)
                    .offset(y: index < visibleRows ? 0 : 16)
            }
        }
    }

    private func unlockedRow(_ item: PaywallFeatureItem) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.white.opacity(0.2)).frame(width: 44, height: 44)
                Image(systemName: item.symbol)
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
            }
            Text(item.title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.white)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.15)))
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            primaryButton
            if showsNotificationsButton {
                notificationsButton
            }
        }
        .opacity(showButtons ? 1 : 0)
        .offset(y: showButtons ? 0 : 16)
        .padding(.bottom, 32)
    }

    private var primaryButton: some View {
        Button(action: handlePrimary) {
            Text(primaryButtonText)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(accent)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 16).fill(PaywallCTAFill.gradient(.white)))
                .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("paywall.postPurchase.primary")
        .accessibilityLabel(primaryButtonText)
    }

    private var notificationsButton: some View {
        Button(action: requestNotifications) {
            ZStack {
                Text(notificationsButtonText ?? "")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(isRequestingNotifications ? 0 : 1)
                if isRequestingNotifications {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .disabled(isRequestingNotifications)
        .accessibilityIdentifier("paywall.postPurchase.notifications")
        .accessibilityLabel(notificationsButtonText ?? "")
    }

    // MARK: - Actions
    private func handleAppear() {
        PaywallAnalytics.log(PaywallAnalytics.Event.postPurchaseShown,
                             ["placement": "post_purchase_view", "rows": unlocked.count])
        startEntranceAnimations()
    }

    private func handlePrimary() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onPrimary()
    }

    /// Loading state for the system prompt (RULES: every button that triggers a
    /// permission request spins until the completion arrives, on every path).
    private func requestNotifications() {
        guard let onEnableNotifications, !isRequestingNotifications else { return }
        isRequestingNotifications = true
        Task { @MainActor in
            await onEnableNotifications()
            isRequestingNotifications = false
            withAnimation(.easeInOut(duration: 0.25)) { notificationsHandled = true }
        }
    }

    // MARK: - Private Methods
    private func startEntranceAnimations() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { showHero = true }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeOut(duration: 0.5)) { showTitle = true }
        }

        for index in unlocked.indices {
            let delay = 0.45 + (0.15 * Double(index))
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.4)) { visibleRows = index + 1 }
            }
        }

        let buttonDelay = 0.45 + (0.15 * Double(unlocked.count)) + 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + buttonDelay) {
            withAnimation(.easeOut(duration: 0.4)) { showButtons = true }
        }
    }
}
