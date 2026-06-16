//
//  PurchaseScaffold.swift
//  PaywallKit
//
//  High-converting "Adam Lyttle" style paywall: shaking hero, cooldown close
//  timer, save-% badge, trial detection and selectable plan cards. Wired to the
//  native StoreKit 2 layer (StoreKitManager) — no third-party SDKs.
//
//  Adapted for GambitStudio from Paywall-PurchaseView-SwiftUI by Adam Lyttle
//  (https://github.com/adamlyttleapps/Paywall-PurchaseView-SwiftUI, MIT).
//  The original stub PurchaseModel is replaced by StoreKitManager.shared and the
//  hero image is an SF Symbol by default so the kit drops in with zero assets.
//
//  Usage in your app:
//
//      // configure once at launch:
//      StoreKitManager.shared.configure(
//          weekly: "myapp.pro.weekly",
//          yearly: "myapp.pro.yearly"
//      )
//
//      .fullScreenCover(isPresented: $showPaywall) {
//          PurchaseScaffold(
//              isPresented: $showPaywall,
//              title: String(localized: "paywall.title"),
//              accentColor: AppColors.primary,
//              heroSymbol: "crown.fill",
//              features: [
//                  .init(title: String(localized: "paywall.feature1"), icon: "infinity"),
//                  .init(title: String(localized: "paywall.feature2"), icon: "sparkles"),
//                  .init(title: String(localized: "paywall.feature3"), icon: "lock.open.fill"),
//                  .init(title: String(localized: "paywall.feature4"), icon: "lock.square.stack")
//              ],
//              termsURL: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"),
//              privacyURL: URL(string: "https://gambitstudiotech.com/privacy")
//          )
//      }
//

import SwiftUI
import StoreKit

// MARK: - Feature Model

public struct PurchaseFeature: Identifiable, Sendable {
    public let id = UUID()
    public let title: String
    public let icon: String

    public init(title: String, icon: String) {
        self.title = title
        self.icon = icon
    }
}

// MARK: - Scaffold

public struct PurchaseScaffold: View {
    // MARK: - Configuration
    @Binding private var isPresented: Bool
    private let title: String
    private let accentColor: Color
    private let heroSymbol: String
    private let heroImageName: String?
    private let features: [PurchaseFeature]
    private let termsURL: URL?
    private let privacyURL: URL?
    private let hasCooldown: Bool
    private let allowCloseAfter: CGFloat

    // MARK: - Localized Copy
    private let startTrialText: String
    private let unlockNowText: String
    private let restoreText: String
    private let termsText: String
    private let perText: String
    private let thenText: String
    private let saveText: String
    private let nothingRestoredText: String

    // MARK: - Dependencies
    @ObservedObject private var store = StoreKitManager.shared

    // MARK: - State
    @State private var selectedProductID: String = ""
    @State private var shakeDegrees: Double = 0
    @State private var shakeZoom: CGFloat = 0.9
    @State private var showCloseButton = false
    @State private var progress: CGFloat = 0
    @State private var showNoneRestoredAlert = false
    @State private var showTermsSheet = false

    // MARK: - Init
    public init(
        isPresented: Binding<Bool>,
        title: String,
        accentColor: Color,
        features: [PurchaseFeature],
        heroSymbol: String = "crown.fill",
        heroImageName: String? = nil,
        termsURL: URL? = nil,
        privacyURL: URL? = nil,
        hasCooldown: Bool = true,
        allowCloseAfter: CGFloat = 5.0,
        startTrialText: String = "Start Free Trial",
        unlockNowText: String = "Unlock Now",
        restoreText: String = "Restore",
        termsText: String = "Terms of Use & Privacy Policy",
        perText: String = "per",
        thenText: String = "then",
        saveText: String = "SAVE",
        nothingRestoredText: String = "No purchases restored"
    ) {
        self._isPresented = isPresented
        self.title = title
        self.accentColor = accentColor
        self.features = features
        self.heroSymbol = heroSymbol
        self.heroImageName = heroImageName
        self.termsURL = termsURL
        self.privacyURL = privacyURL
        self.hasCooldown = hasCooldown
        self.allowCloseAfter = allowCloseAfter
        self.startTrialText = startTrialText
        self.unlockNowText = unlockNowText
        self.restoreText = restoreText
        self.termsText = termsText
        self.perText = perText
        self.thenText = thenText
        self.saveText = saveText
        self.nothingRestoredText = nothingRestoredText
    }

    // MARK: - Computed
    private var plans: [PurchasePlan] {
        store.products.map { PurchasePlan(product: $0, perText: perText) }
    }

    private var selectedHasTrial: Bool {
        plans.first { $0.id == selectedProductID }?.hasTrial ?? false
    }

    private var callToActionText: String {
        selectedHasTrial ? startTrialText : unlockNowText
    }

    private var percentageSaved: Int {
        PurchasePricing.percentageSaved(in: plans)
    }

    // MARK: - View Body
    public var body: some View {
        ZStack(alignment: .top) {
            closeRow
            content
        }
        .padding(.horizontal)
        .onAppear(perform: handleAppear)
        .onChange(of: store.isPremium) { _, isPremium in
            if isPremium { dismissSoon() }
        }
    }

    // MARK: - Subviews
    private var closeRow: some View {
        HStack {
            Spacer()
            if hasCooldown && !showCloseButton {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .opacity(0.1 + 0.1 * progress)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "multiply")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20)
                    .opacity(0.2)
                    .onTapGesture { isPresented = false }
            }
        }
        .padding(.top)
    }

    private var content: some View {
        VStack(spacing: 20) {
            hero

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 30, weight: .semibold))
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading) {
                    ForEach(features) { feature in
                        PurchaseFeatureRow(feature: feature, accentColor: accentColor)
                    }
                }
                .font(.system(size: 19))
                .padding(.top)
            }

            Spacer()

            planList
            purchaseButton
            footer
        }
    }

    private var hero: some View {
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
        .frame(height: 120)
        .scaleEffect(shakeZoom)
        .rotationEffect(.degrees(shakeDegrees))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { startShaking() }
        }
    }

    private var planList: some View {
        VStack(spacing: 10) {
            ForEach(plans) { plan in
                Button {
                    withAnimation { selectedProductID = plan.id }
                } label: {
                    PurchasePlanCard(
                        plan: plan,
                        isSelected: selectedProductID == plan.id,
                        accentColor: accentColor,
                        thenText: thenText,
                        saveText: saveText,
                        percentageSaved: percentageSaved
                    )
                }
                .tint(.primary)
            }
        }
        .opacity(store.isLoading ? 0 : 1)
        .overlay { if store.isLoading { ProgressView() } }
    }

    private var purchaseButton: some View {
        ZStack {
            ProgressView().opacity(store.isLoading ? 1 : 0)

            Button {
                guard !store.isLoading, let product = store.product(for: selectedProductID) else { return }
                Task { try? await store.purchase(product) }
            } label: {
                HStack {
                    Spacer()
                    Text(callToActionText)
                    Image(systemName: "chevron.right")
                    Spacer()
                }
                .padding()
                .foregroundStyle(.white)
                .font(.title3.bold())
            }
            .background(accentColor)
            .cornerRadius(6)
            .opacity(store.isLoading ? 0 : 1)
            .padding(.top)
            .padding(.bottom, 4)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button(restoreText) {
                Task { await store.restorePurchases() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                    if !store.isPremium { showNoneRestoredAlert = true }
                }
            }
            .alert(isPresented: $showNoneRestoredAlert) {
                Alert(
                    title: Text(restoreText),
                    message: Text(nothingRestoredText),
                    dismissButton: .default(Text("OK"))
                )
            }
            .underlined()

            Button(termsText) { showTermsSheet = true }
                .underlined()
                .confirmationDialog(termsText, isPresented: $showTermsSheet, titleVisibility: .visible) {
                    if let termsURL {
                        Button("Terms of Use") { UIApplication.shared.open(termsURL) }
                    }
                    if let privacyURL {
                        Button("Privacy Policy") { UIApplication.shared.open(privacyURL) }
                    }
                    Button("Cancel", role: .cancel) {}
                }
        }
        .foregroundStyle(.gray)
        .font(.system(size: 15))
    }

    // MARK: - Lifecycle
    private func handleAppear() {
        if store.isPremium { isPresented = false }
        selectedProductID = store.products.first?.id ?? ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeIn(duration: allowCloseAfter)) { progress = 1.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + allowCloseAfter) {
                withAnimation { showCloseButton = true }
            }
        }
    }

    private func dismissSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isPresented = false }
    }

    // MARK: - Hero Shake
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

// MARK: - Underline Modifier

private extension View {
    func underlined() -> some View {
        font(.footnote)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(.gray),
                alignment: .bottom
            )
    }
}
