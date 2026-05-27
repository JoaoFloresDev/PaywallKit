//
//  PaywallScaffold.swift
//  PaywallKit
//
//  Reusable paywall view — AppLock-style. Hero gradient + features + plan cards + CTA + restore.
//
//  Usage:
//      PaywallScaffold(
//          gradient: [AppColors.primary, AppColors.primary.opacity(0.9)],
//          title: String(localized: "premium.title"),
//          subtitle: String(localized: "premium.subtitle"),
//          features: [
//              .init(symbol: "lock.shield.fill", title: String(localized: "premium.feature.password.title")),
//              .init(symbol: "faceid", title: String(localized: "premium.feature.faceid.title")),
//              .init(symbol: "folder.badge.plus", title: String(localized: "premium.feature.unlimited.title")),
//              .init(symbol: "headphones", title: String(localized: "premium.feature.support.title"))
//          ],
//          ctaButtonText: String(localized: "premium.button.subscribe"),
//          restoreButtonText: String(localized: "premium.button.restore"),
//          eulaText: String(localized: "legal.eula"),
//          privacyText: String(localized: "legal.privacy"),
//          activeStateConfig: .init(
//              title: String(localized: "premium.active.title"),
//              description: String(localized: "premium.active.description"),
//              manageButtonText: String(localized: "premium.manage.subscription")
//          )
//      )
//

import SwiftUI
import StoreKit

// MARK: - Public Types

public struct PaywallFeatureItem: Identifiable, Sendable {
    public let id = UUID()
    public let symbol: String
    public let title: String

    public init(symbol: String, title: String) {
        self.symbol = symbol
        self.title = title
    }
}

public struct PaywallActiveStateConfig {
    public let title: String
    public let description: String
    public let manageButtonText: String

    public init(title: String, description: String, manageButtonText: String) {
        self.title = title
        self.description = description
        self.manageButtonText = manageButtonText
    }
}

public enum PaywallPlanLabel {
    case monthly(title: String, period: String)
    case yearly(title: String, period: String, recommendedBadge: String?)
    case lifetime(title: String, period: String)
}

// MARK: - Scaffold

public struct PaywallScaffold: View {
    // MARK: - Configuration
    private let gradient: [Color]
    private let title: String
    private let subtitle: String
    private let features: [PaywallFeatureItem]
    private let monthlyLabel: PaywallPlanLabel?
    private let yearlyLabel: PaywallPlanLabel?
    private let lifetimeLabel: PaywallPlanLabel?
    private let ctaButtonText: String
    private let restoreButtonText: String
    private let eulaText: String
    private let privacyText: String
    private let activeStateConfig: PaywallActiveStateConfig

    // MARK: - State
    @StateObject private var storeKit = StoreKitManager.shared
    @AppStorage("isPremium") private var isPremium = false
    @Environment(\.dismiss) var dismiss
    @State private var selectedProductID: String?
    @State private var showingError = false
    @State private var errorMessage = ""

    // MARK: - Init
    public init(
        gradient: [Color],
        title: String,
        subtitle: String,
        features: [PaywallFeatureItem],
        monthlyLabel: PaywallPlanLabel? = nil,
        yearlyLabel: PaywallPlanLabel? = nil,
        lifetimeLabel: PaywallPlanLabel? = nil,
        ctaButtonText: String,
        restoreButtonText: String,
        eulaText: String,
        privacyText: String,
        activeStateConfig: PaywallActiveStateConfig
    ) {
        self.gradient = gradient
        self.title = title
        self.subtitle = subtitle
        self.features = features
        self.monthlyLabel = monthlyLabel
        self.yearlyLabel = yearlyLabel
        self.lifetimeLabel = lifetimeLabel
        self.ctaButtonText = ctaButtonText
        self.restoreButtonText = restoreButtonText
        self.eulaText = eulaText
        self.privacyText = privacyText
        self.activeStateConfig = activeStateConfig
    }

    // MARK: - View Body
    public var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                if isPremium { activeStateView } else { purchaseStateView }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { closeToolbar }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                isPremium = storeKit.isPremium
                if storeKit.products.isEmpty && !storeKit.isLoading {
                    Task { await storeKit.loadProducts() }
                }
                if selectedProductID == nil {
                    selectedProductID = storeKit.yearlyProduct?.id ?? storeKit.products.first?.id
                }
            }
        }
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var closeToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
            }
        }
    }

    // MARK: - Active state
    private var activeStateView: some View {
        VStack(spacing: 30) {
            Spacer()
            ZStack {
                Circle().fill(Color.yellow.opacity(0.2)).frame(width: 140, height: 140)
                Image(systemName: "crown.fill").font(.system(size: 70)).foregroundStyle(.yellow)
            }
            VStack(spacing: 12) {
                Text(activeStateConfig.title)
                    .font(.system(size: 32, weight: .bold)).foregroundStyle(.white)
                Text(activeStateConfig.description)
                    .font(.system(size: 17)).foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center).padding(.horizontal, 50)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 16) {
                ForEach(features) { feature in
                    activeFeatureBadge(feature)
                }
            }
            .padding(.horizontal, 40)
            Spacer()
            Button(action: openSubscriptionManagement) {
                Text(activeStateConfig.manageButtonText)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.vertical, 14).padding(.horizontal, 30)
                    .background(RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5))
            }
            .padding(.bottom, 30)
        }
    }

    private func activeFeatureBadge(_ item: PaywallFeatureItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.symbol)
                .font(.system(size: 20)).foregroundStyle(.white).frame(width: 30)
            Text(item.title)
                .font(.system(size: 16, weight: .medium)).foregroundStyle(.white)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22)).foregroundStyle(.green)
        }
        .padding(.vertical, 12).padding(.horizontal, 20)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.15)))
    }

    // MARK: - Purchase state
    private var purchaseStateView: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 50)).foregroundStyle(.yellow).padding(.top, 30)
                Text(title)
                    .font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 14)).foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center).padding(.horizontal, 40)
            }
            .padding(.bottom, 25)

            VStack(spacing: 12) {
                ForEach(features) { f in
                    HStack(spacing: 12) {
                        Image(systemName: f.symbol)
                            .font(.system(size: 18)).foregroundStyle(.white).frame(width: 24)
                        Text(f.title)
                            .font(.system(size: 15, weight: .medium)).foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18)).foregroundStyle(.green)
                    }
                }
            }
            .padding(.horizontal, 30).padding(.bottom, 25)

            planCards.padding(.horizontal, 20).padding(.bottom, 20)

            Button(action: subscribe) {
                HStack {
                    if storeKit.isLoading {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: gradient.first ?? .blue))
                    } else {
                        Text(ctaButtonText)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(gradient.first ?? .blue)
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(Color.white).cornerRadius(14)
            }
            .disabled(storeKit.isLoading)
            .opacity(storeKit.isLoading ? 0.6 : 1.0)
            .padding(.horizontal, 20).padding(.bottom, 15)

            Button(action: restore) {
                Text(restoreButtonText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .disabled(storeKit.isLoading)
            .padding(.bottom, 20)
        }
    }

    private var planCards: some View {
        VStack(spacing: 10) {
            if storeKit.products.isEmpty && storeKit.isLoading {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2).frame(height: 120)
            } else {
                if let p = storeKit.yearlyProduct, let label = yearlyLabel, case let .yearly(title, period, badge) = label {
                    planCard(product: p, title: title, period: period, badge: badge)
                }
                if let p = storeKit.monthlyProduct, let label = monthlyLabel, case let .monthly(title, period) = label {
                    planCard(product: p, title: title, period: period, badge: nil)
                }
                if let p = storeKit.lifetimeProduct, let label = lifetimeLabel, case let .lifetime(title, period) = label {
                    planCard(product: p, title: title, period: period, badge: nil)
                }
            }
        }
    }

    private func planCard(product: Product, title: String, period: String, badge: String?) -> some View {
        let isSelected = selectedProductID == product.id
        return Button(action: { selectedProductID = product.id }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Color.white, lineWidth: 2).frame(width: 24, height: 24)
                    if isSelected { Circle().fill(Color.white).frame(width: 12, height: 12) }
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                        if let badge {
                            Text(badge).font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.green.opacity(0.6)).cornerRadius(4)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
                    Text(period).font(.system(size: 12)).foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(isSelected ? 0.25 : 0.15))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white, lineWidth: isSelected ? 2 : 0)))
        }
    }

    // MARK: - Actions
    private func subscribe() {
        guard let id = selectedProductID, let product = storeKit.product(for: id) else {
            errorMessage = "No product selected"
            showingError = true
            return
        }
        Task {
            do {
                let tx = try await storeKit.purchase(product)
                isPremium = storeKit.isPremium
                if tx != nil && isPremium { dismiss() }
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func restore() {
        Task {
            await storeKit.restorePurchases()
            isPremium = storeKit.isPremium
            if isPremium {
                dismiss()
            } else {
                errorMessage = "No purchases found to restore"
                showingError = true
            }
        }
    }

    private func openSubscriptionManagement() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}
