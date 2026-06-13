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
    private let onClose: (() -> Void)?
    private let privacyURL: URL
    private let termsURL: URL

    // MARK: - State
    @StateObject private var storeKit = StoreKitManager.shared
    @AppStorage("isPremium") private var isPremium = false
    @Environment(\.dismiss) var dismiss
    @State private var selectedProductID: String?
    @State private var showingError = false
    @State private var errorMessage = ""

    // Entrance animation state (AirDraw model)
    @State private var showHeader = false
    @State private var showBenefits = false
    @State private var showPlans = false
    @State private var showButton = false
    @State private var iconPulse = false

    // GambitStudio standard legal URLs (overridable via init).
    private static let defaultPrivacyURL = URL(string: "https://drive.google.com/file/d/147xkp4cekrxhrBYZnzV-J4PzCSqkix7t/view?usp=sharing")!
    private static let defaultTermsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

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
        activeStateConfig: PaywallActiveStateConfig,
        privacyURL: URL? = nil,
        termsURL: URL? = nil,
        onClose: (() -> Void)? = nil
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
        self.privacyURL = privacyURL ?? PaywallScaffold.defaultPrivacyURL
        self.termsURL = termsURL ?? PaywallScaffold.defaultTermsURL
        self.onClose = onClose
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
            .toolbarBackground(.hidden, for: .navigationBar)
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
                startAnimations()
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Entrance Animations
    private func startAnimations() {
        withAnimation(.easeOut(duration: 0.5)) { showHeader = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { withAnimation(.easeOut(duration: 0.5)) { showBenefits = true } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { withAnimation(.easeOut(duration: 0.5)) { showPlans = true } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { withAnimation(.easeOut(duration: 0.5)) { showButton = true } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { iconPulse = true }
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var closeToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { onClose?() ?? dismiss() }) {
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
                Circle().fill(Color(red: 1.0, green: 0.85, blue: 0.0).opacity(0.2)).frame(width: 140, height: 140)
                Image(systemName: "crown.fill").font(.system(size: 70)).foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.0))
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
    //
    // 3-zone vertical layout, anchored top + bottom:
    //   [top]    crown + title + subtitle
    //   [middle] features list + plan cards (yearly + monthly)
    //   [bottom] CTA + restore button
    //
    // Spacer() between zones distributes empty space naturally on any screen
    // size (iPhone SE → 16 Pro Max) without each zone needing manual padding.
    // Horizontal padding is unified at 24pt for the whole view.
    private var purchaseStateView: some View {
        VStack(spacing: 0) {
            // TOP — header (pulsing crown + entrance)
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.85, blue: 0.0).opacity(0.2))
                        .frame(width: 92, height: 92)
                        .scaleEffect(iconPulse ? 1.08 : 1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: iconPulse)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.0))
                }
                Text(title)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
            .opacity(showHeader ? 1 : 0)
            .offset(y: showHeader ? 0 : 20)

            Spacer(minLength: 24)

            // MIDDLE — features (icon-in-circle) + plans
            VStack(spacing: 20) {
                VStack(spacing: 14) {
                    ForEach(features) { f in
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(Color.white.opacity(0.2)).frame(width: 44, height: 44)
                                Image(systemName: f.symbol)
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white)
                            }
                            Text(f.title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .opacity(showBenefits ? 1 : 0)
                .offset(y: showBenefits ? 0 : 20)

                planCards
                    .opacity(showPlans ? 1 : 0)
                    .offset(y: showPlans ? 0 : 20)
            }

            Spacer(minLength: 24)

            // BOTTOM — CTA + restore + legal links
            VStack(spacing: 12) {
                Button(action: subscribe) {
                    HStack {
                        if storeKit.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: gradient.first ?? .blue))
                        } else {
                            Text(ctaButtonText)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(gradient.first ?? .blue)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(14)
                }
                .disabled(storeKit.isLoading)
                .opacity(storeKit.isLoading ? 0.6 : 1.0)

                HStack(spacing: 12) {
                    Button(action: restore) {
                        Text(restoreButtonText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .disabled(storeKit.isLoading)
                    Text("·").foregroundStyle(.white.opacity(0.4))
                    Link(privacyText, destination: privacyURL)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("·").foregroundStyle(.white.opacity(0.4))
                    Link(eulaText, destination: termsURL)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.bottom, 8)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 20)
        }
        .padding(.horizontal, 24)
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
                    Text(title).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
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
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                        .offset(x: -14, y: -10)
                }
            }
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
