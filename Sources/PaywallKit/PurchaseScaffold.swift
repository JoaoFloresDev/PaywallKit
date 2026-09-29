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
//  Trial-toggle audit (28/09/2026, research 2026-09 finding 7): this scaffold never had the
//  "free trial toggle" of the original (Apple rejects it under 3.1.2 since Jan/2026) — the
//  trial lives in ONE plan (the intro offer configured in ASC) and the user only picks a card.
//  Keep it that way: no switch that adds/removes the trial.
//
//  Layout: one column — hero, title, benefits, optional social proof, the plan cards (annual
//  pre-selected, weekly as the price anchor), the trial timeline while the selected plan has a
//  trial, the CTA and the legal footer. Classic column: slack split between the bands, scrolls
//  on short canvases. With social proof/timeline: the densest-that-fits of
//  `PurchaseColumnMetrics`, so the CTA and footer stay above the fold. Colors come from
//  `PurchasePalette`; `backgroundColor:` paints the surface edge to edge.
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
//              privacyURL: URL(string: "https://gambitstudiotech.com/privacy"),
//              backgroundColor: AppColors.background,
//              palette: PurchasePalette(text: AppColors.textPrimary, supportingText: AppColors.textSecondary)
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
    private let backgroundColor: Color?
    private let palette: PurchasePalette
    private let cornerRadius: CGFloat
    private let previewPlans: [PurchasePlanPreview]
    private let socialProof: PurchaseSocialProof?
    private let trialTimeline: TrialTimelineStrings?
    private let exitOffer: ExitOfferConfiguration?

    // MARK: - Localized Copy
    private let startTrialText: String
    private let unlockNowText: String
    private let restoreText: String
    private let termsText: String
    private let perText: String
    private let thenText: String
    private let saveText: String
    private let nothingRestoredText: String
    private let plansUnavailableText: String
    private let retryText: String
    private let periodNames: PurchasePeriodNames

    // MARK: - Dependencies
    @ObservedObject private var store = StoreKitManager.shared

    // MARK: - State
    @State private var selectedProductID: String = ""
    @State private var showCloseButton = false
    @State private var progress: CGFloat = 0
    @State private var showNoneRestoredAlert = false
    @State private var showTermsSheet = false
    @State private var shownAt = Date()
    @State private var showExitOffer = false
    @State private var exitOfferReason: ExitOfferReason = .dismiss

    // MARK: - Init
    /// `backgroundColor` (nil = transparent, the host paints behind), `palette`
    /// (theme-derived defaults) and `cornerRadius` (plan cards + CTA, 6 = historical
    /// look; pass the app radius so the paywall matches its cards) keep the previous
    /// rendering when omitted. `previewPlans`
    /// renders display-only cards when StoreKit returns no products — for screenshots
    /// and simulator QA where no `.storekit` configuration is applied; never for sale.
    /// `socialProof` (real rating + one quote, between benefits and plans), `trialTimeline`
    /// ("Today / Day 5 / Day 7" under the plan cards while the selected plan has a trial) and
    /// `exitOffer` (a real intro-offer product shown once after dismiss/abandon) are opt-in.
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
        nothingRestoredText: String = "No purchases restored",
        plansUnavailableText: String = "Couldn't load the plans. Check your connection and try again.",
        retryText: String = "Try again",
        periodNames: PurchasePeriodNames = .english,
        backgroundColor: Color? = nil,
        palette: PurchasePalette = PurchasePalette(),
        cornerRadius: CGFloat = 6,
        previewPlans: [PurchasePlanPreview] = [],
        socialProof: PurchaseSocialProof? = nil,
        trialTimeline: TrialTimelineStrings? = nil,
        exitOffer: ExitOfferConfiguration? = nil
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
        self.plansUnavailableText = plansUnavailableText
        self.retryText = retryText
        self.periodNames = periodNames
        self.backgroundColor = backgroundColor
        self.palette = palette
        self.cornerRadius = cornerRadius
        self.previewPlans = previewPlans
        self.socialProof = socialProof
        self.trialTimeline = trialTimeline
        self.exitOffer = exitOffer
    }

    // MARK: - Computed
    /// Real StoreKit products first; the preview cards only stand in while the store has none.
    private var usesPreviewPlans: Bool {
        store.products.isEmpty && !previewPlans.isEmpty
    }

    private var plans: [PurchasePlan] {
        if usesPreviewPlans {
            return previewPlans.map { PurchasePlan(preview: $0, names: periodNames) }
        }
        return store.products.map { PurchasePlan(product: $0, names: periodNames) }
    }

    private var isLoadingPlans: Bool {
        store.isLoading && !usesPreviewPlans
    }

    private var selectedPlan: PurchasePlan? {
        plans.first { $0.id == selectedProductID }
    }

    private var selectedHasTrial: Bool {
        selectedPlan?.hasTrial ?? false
    }

    /// Social proof and/or the trial timeline add ~200pt to the column: it is laid out through
    /// the density ladder of `PurchaseColumnMetrics` so the CTA stays above the fold.
    private var isDense: Bool {
        socialProof != nil || trialTimeline != nil
    }

    /// The exit offer auto-presents once per install, only when the app configured a product.
    private var canPresentExitOffer: Bool {
        exitOffer != nil && ExitOffer.canPresent() && !store.isPremium
    }

    private var callToActionText: String {
        selectedHasTrial ? startTrialText : unlockNowText
    }

    private var percentageSaved: Int? {
        PurchasePricing.percentageSaved(in: plans)
    }

    // MARK: - View Body
    public var body: some View {
        ZStack(alignment: .top) {
            if let backgroundColor {
                backgroundColor.ignoresSafeArea()
            }
            GeometryReader { geo in
                column(canvasHeight: geo.size.height)
            }
            .padding(.horizontal)
            .accessibilityHidden(showExitOffer)   // the offer card is modal for VoiceOver
            closeRow
                .padding(.horizontal)
                .accessibilityHidden(showExitOffer)
        }
        .onAppear(perform: handleAppear)
        .onChange(of: store.products) { _, _ in selectDefaultPlanIfNeeded() }
        .onChange(of: store.isPremium) { _, isPremium in
            if isPremium { dismissSoon() }
        }
        .overlay {
            if showExitOffer, let exitOffer {
                ExitOfferOverlay(configuration: exitOffer, accentColor: accentColor, palette: palette,
                                 backgroundColor: backgroundColor, cornerRadius: cornerRadius,
                                 reason: exitOfferReason, onFinished: finishExitOffer)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.25), value: showExitOffer)
    }

    // MARK: - Subviews
    private var closeRow: some View {
        HStack {
            Spacer()
            if hasCooldown && !showCloseButton {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(palette.text)
                    .opacity(0.1 + 0.1 * progress)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 20, height: 20)
                    .frame(width: 44, height: 44)
            } else {
                // Visually subtle on purpose, but the hit area is 44pt and VoiceOver/QA can reach it:
                // "xmark" gets the system-localized "Close" label, and the id lets Maestro tap it.
                Button {
                    PaywallAnalytics.log("paywall_dismissed", ["placement": "purchase_scaffold",
                                                               "seconds": Int(Date().timeIntervalSince(shownAt))])
                    if canPresentExitOffer {
                        exitOfferReason = .dismiss
                        showExitOffer = true
                    } else {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18)
                        .foregroundStyle(palette.text)
                        .opacity(0.2)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("paywall.close")
            }
        }
        .padding(.top, 4)
    }

    /// Classic layout: one density, scrolls on short canvases. Dense layout: the first density
    /// of the ladder whose natural height fits the screen; scrolling only when none fits.
    @ViewBuilder
    private func column(canvasHeight: CGFloat) -> some View {
        if isDense {
            ViewThatFits(in: .vertical) {
                ForEach(PurchaseColumnDensity.denseLadder, id: \.self) { density in
                    content(canvasHeight: canvasHeight, metrics: PurchaseColumnMetrics(density: density))
                }
                scrollingColumn(canvasHeight: canvasHeight, density: .minimal)
            }
        } else {
            scrollingColumn(canvasHeight: canvasHeight, density: .regular)
        }
    }

    private func scrollingColumn(canvasHeight: CGFloat, density: PurchaseColumnDensity) -> some View {
        ScrollView(showsIndicators: false) {
            content(canvasHeight: canvasHeight, metrics: PurchaseColumnMetrics(density: density))
                .frame(minHeight: canvasHeight)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    /// The column. Unbounded spacers share the slack 1 (top) : 2 (benefits → plans); the two
    /// bounded ones between hero/title/benefits grow up to a cap so the top block breathes
    /// on tall phones without drifting apart. Everything else is intrinsic, so the plan
    /// cards always sit directly above the CTA.
    private func content(canvasHeight: CGFloat, metrics m: PurchaseColumnMetrics) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: m.leadingGap)

            if let heroHeight = m.heroHeight(canvasHeight: canvasHeight) {
                PurchaseHeroView(heroSymbol: heroSymbol, heroImageName: heroImageName,
                                 accentColor: accentColor, height: heroHeight)
                Spacer(minLength: m.bandMin).frame(maxHeight: m.heroTitleMax)
            }

            Text(title)
                .font(.system(size: m.titleSize, weight: .semibold))
                .foregroundStyle(palette.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: m.bandMin).frame(maxHeight: m.titleBenefitsMax)

            featureList(m)

            if let socialProof {
                Spacer(minLength: m.proofGap).frame(maxHeight: 16)
                PurchaseSocialProofView(proof: socialProof, accentColor: accentColor, palette: palette,
                                        cornerRadius: cornerRadius, showsQuote: m.showsQuote)
            }

            Spacer(minLength: m.plansGap)
            Spacer(minLength: m.plansExtraGap)

            planList(m)
            trialTimelineBlock(m)
            purchaseButton(m)
            footer(m)
        }
        .padding(.top, m.topInset)
        .frame(maxWidth: .infinity)
    }

    private func featureList(_ m: PurchaseColumnMetrics) -> some View {
        VStack(alignment: .leading, spacing: m.featureSpacing) {
            ForEach(features) { feature in
                PurchaseFeatureRow(feature: feature, accentColor: accentColor, palette: palette)
            }
        }
        .font(.system(size: m.featureSize))
        .padding(.horizontal, 8)
    }

    /// Shown when StoreKit returned no products (offline, or subscriptions not yet live):
    /// a blank plan area with a dead CTA gives the user nothing to act on.
    private var plansUnavailable: some View {
        VStack(spacing: 12) {
            Text(plansUnavailableText)
                .font(.subheadline)
                .foregroundStyle(palette.supportingText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button(retryText) {
                Task { await store.loadProducts() }
            }
            .font(.headline)
            .tint(accentColor)
            .frame(minHeight: 44)
            .accessibilityIdentifier("paywall.retry")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }

    @ViewBuilder
    private func planList(_ m: PurchaseColumnMetrics) -> some View {
        if plans.isEmpty && !isLoadingPlans {
            plansUnavailable
        } else {
            planCards(compact: m.compactCards)
        }
    }

    private func planCards(compact: Bool) -> some View {
        VStack(spacing: 10) {
            ForEach(plans) { plan in
                Button {
                    withAnimation { selectedProductID = plan.id }
                    PaywallAnalytics.log(PaywallAnalytics.Event.planSelected,
                                         ["product_id": plan.id, "period": plan.period.map(periodName) ?? "lifetime",
                                          "trial": plan.hasTrial])
                } label: {
                    PurchasePlanCard(
                        plan: plan,
                        isSelected: selectedProductID == plan.id,
                        accentColor: accentColor,
                        palette: palette,
                        cornerRadius: cornerRadius,
                        thenText: thenText,
                        perText: perText,
                        saveText: saveText,
                        percentageSaved: percentageSaved,
                        compact: compact
                    )
                }
                .tint(palette.text)
                .accessibilityIdentifier("paywall.plan.\(plan.id)")
            }
        }
        .opacity(isLoadingPlans ? 0 : 1)
        .overlay { if isLoadingPlans { ProgressView().tint(palette.text) } }
    }

    /// "How your trial works" — only while the selected plan has a trial (research 2026-09, finding 6).
    @ViewBuilder
    private func trialTimelineBlock(_ m: PurchaseColumnMetrics) -> some View {
        if let trialTimeline, let plan = selectedPlan, plan.hasTrial, let days = plan.trialDays, !isLoadingPlans {
            TrialTimelineView(
                trialDays: days,
                price: plan.unitLabel.isEmpty ? plan.price : "\(plan.price) \(perText) \(plan.unitLabel)",
                strings: trialTimeline,
                accentColor: accentColor,
                palette: palette,
                cornerRadius: cornerRadius,
                compact: m.compactCards
            )
            .padding(.top, m.timelineTop)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private func purchaseButton(_ m: PurchaseColumnMetrics) -> some View {
        ZStack {
            ProgressView().tint(palette.text).opacity(isLoadingPlans ? 1 : 0)

            Button {
                guard !store.isLoading, let product = store.product(for: selectedProductID) else { return }
                Task { await purchase(product) }
            } label: {
                HStack {
                    Spacer()
                    Text(callToActionText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.right")
                    Spacer()
                }
                .frame(minHeight: 44)
                .padding(.vertical, 6)
                .padding(.horizontal)
                .foregroundStyle(palette.onAccent)
                .font(.title3.bold())
                .contentShape(Rectangle())
            }
            .background(PaywallCTAFill.gradient(accentColor))   // same fill as the exit-offer CTA
            .cornerRadius(cornerRadius)
            .opacity(isLoadingPlans ? 0 : (plans.isEmpty ? 0.4 : 1))
            .disabled(plans.isEmpty)
            .accessibilityIdentifier("paywall.purchase")
            .padding(.top, m.ctaTop)
        }
    }

    private func footer(_ m: PurchaseColumnMetrics) -> some View {
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
            .underlined(palette.footerText)
            .accessibilityIdentifier("paywall.restore")

            Button(termsText) { showTermsSheet = true }
                .underlined(palette.footerText)
                .accessibilityIdentifier("paywall.terms")
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
        .foregroundStyle(palette.footerText)
        .font(.system(size: 15))
        .padding(.top, m.footerTop)
        .padding(.bottom, m.footerBottom)
    }

    // MARK: - Purchase
    /// A cancelled system sheet is the moment the exit offer is for (finding 5: "abandon").
    private func purchase(_ product: Product) async {
        let transaction = try? await store.purchase(product)
        guard transaction == nil, !store.isPremium, canPresentExitOffer else { return }
        exitOfferReason = .abandon
        showExitOffer = true
    }

    private func periodName(_ period: PurchasePeriod) -> String {
        switch period {
        case .day: return "daily"
        case .week: return "weekly"
        case .month: return "monthly"
        case .year: return "yearly"
        }
    }

    // MARK: - Lifecycle
    private func handleAppear() {
        if store.isPremium { isPresented = false }
        shownAt = Date()
        if !store.isPremium { PaywallAnalytics.log("paywall_shown", ["placement": "purchase_scaffold"]) }
        selectDefaultPlanIfNeeded()
        if store.products.isEmpty && !store.isLoading {
            Task { await store.loadProducts() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeIn(duration: allowCloseAfter)) { progress = 1.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + allowCloseAfter) {
                withAnimation { showCloseButton = true }
            }
        }
    }

    /// Products load asynchronously, so the paywall can appear before any plan
    /// exists to select. Products are price-sorted, so the first one is the
    /// headline plan (the yearly, where the trial lives).
    private func selectDefaultPlanIfNeeded() {
        let available = plans
        guard available.contains(where: { $0.id == selectedProductID }) == false else { return }
        selectedProductID = available.first?.id ?? ""
    }

    /// Declined or done: the paywall closes with the offer (purchase closes it via `isPremium`).
    private func finishExitOffer() {
        showExitOffer = false
        if !store.isPremium { isPresented = false }
    }

    private func dismissSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isPresented = false }
    }
}

// MARK: - Underline Modifier

private extension View {
    /// Footnote link with a 1pt underline in the footer color; keeps the 44pt hit height.
    func underlined(_ color: Color) -> some View {
        font(.footnote)
            .frame(minHeight: 44)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(color)
                    .padding(.bottom, 12),
                alignment: .bottom
            )
    }
}
