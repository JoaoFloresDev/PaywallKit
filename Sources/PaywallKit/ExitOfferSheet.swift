//
//  ExitOfferSheet.swift
//  PaywallKit
//
//  Welcome/exit offer shown ONCE per user right after the paywall is dismissed or a purchase is
//  abandoned: a real introductory offer of a product the app configured in App Store Connect
//  (the kit never fabricates a discount — the price shown is `introductoryOffer.displayPrice`),
//  with a real 24-hour deadline persisted on device. Post-abandon offers are 17% of revenue in
//  Superwall's 18-app test, with LOWER refunds; Adapty measures 10-15% of ARPU for a 24 h welcome
//  offer (research 2026-09, finding 5). Urgency is legal only when true (finding 8): the deadline
//  never resets and the sheet never comes back once it was shown.
//
//  Why a separate product: the main paywall keeps 2 plans (finding 12). The offer product (a
//  monthly with a discounted first month, for example) is loaded here by id and only sold here.
//  A promotional offer (signed JWS) can be passed through `purchaseOptions`.
//
//  Usage — automatic, from PurchaseScaffold:
//      PurchaseScaffold(..., exitOffer: ExitOfferConfiguration(productID: "app.pro.monthly", strings: ...))
//
//  Usage — standalone (the host decides when):
//      .sheet(isPresented: $showOffer) {
//          ExitOfferSheet(productID: "app.pro.monthly", strings: ..., accentColor: AppColors.primary,
//                         reason: .dismiss, onFinished: { showOffer = false })
//      }
//

import SwiftUI
import StoreKit

// MARK: - Strings

public struct ExitOfferStrings: Sendable {
    /// "Before you go — one offer, once".
    public var title: String
    /// Optional line under the title.
    public var subtitle: String?
    /// Receives the offer price and the regular price: "First month for R$ 3,49, then R$ 6,99".
    public var priceLine: @Sendable (_ offerPrice: String, _ regularPrice: String) -> String
    /// Receives the time left ("23 h 12 min"): "Expires in %@".
    public var deadlineLabel: @Sendable (String) -> String
    public var ctaText: String
    public var dismissText: String
    /// Shown while the product loads or when the store has no offer for this user.
    public var unavailableText: String

    public init(
        title: String,
        subtitle: String? = nil,
        priceLine: @escaping @Sendable (String, String) -> String,
        deadlineLabel: @escaping @Sendable (String) -> String,
        ctaText: String,
        dismissText: String,
        unavailableText: String
    ) {
        self.title = title
        self.subtitle = subtitle
        self.priceLine = priceLine
        self.deadlineLabel = deadlineLabel
        self.ctaText = ctaText
        self.dismissText = dismissText
        self.unavailableText = unavailableText
    }
}

// MARK: - Reason

public enum ExitOfferReason: String, Sendable {
    /// The user closed the paywall.
    case dismiss
    /// The user started a purchase and cancelled the system sheet.
    case abandon
}

// MARK: - Preview

/// Display-only offer for screenshots/simulator QA when StoreKit returns no product. Never sold.
public struct ExitOfferPreview: Sendable {
    public let offerPrice: String
    public let regularPrice: String

    public init(offerPrice: String, regularPrice: String) {
        self.offerPrice = offerPrice
        self.regularPrice = regularPrice
    }
}

// MARK: - Configuration

/// What `PurchaseScaffold` needs to present the sheet by itself after a dismiss/abandon.
public struct ExitOfferConfiguration {
    public let productID: String
    public let strings: ExitOfferStrings
    public let purchaseOptions: Set<Product.PurchaseOption>
    public let preview: ExitOfferPreview?

    public init(
        productID: String,
        strings: ExitOfferStrings,
        purchaseOptions: Set<Product.PurchaseOption> = [],
        preview: ExitOfferPreview? = nil
    ) {
        self.productID = productID
        self.strings = strings
        self.purchaseOptions = purchaseOptions
        self.preview = preview
    }
}

// MARK: - ExitOffer (state)

/// Once-per-user + real deadline, persisted in UserDefaults.
public enum ExitOffer {
    static let shownKey = "paywallkit.exitOffer.shownAt"
    static let deadlineKey = "paywallkit.exitOffer.deadline"
    /// How long the offer stays valid after it was first shown.
    nonisolated(unsafe) public static var window: TimeInterval = 24 * 3_600

    public static var shownAt: Date? { UserDefaults.standard.object(forKey: shownKey) as? Date }
    public static var deadline: Date? { UserDefaults.standard.object(forKey: deadlineKey) as? Date }
    public static var hasBeenShown: Bool { shownAt != nil }

    /// The scaffold auto-presents only when the sheet was never shown.
    public static func canPresent(now: Date = Date()) -> Bool { !hasBeenShown }

    /// Still inside the 24 h window (for a host that re-surfaces the offer, e.g. a banner).
    public static func isActive(now: Date = Date()) -> Bool {
        guard let deadline else { return false }
        return deadline > now
    }

    /// Records the first presentation and fixes the deadline. Idempotent.
    public static func markShown(now: Date = Date()) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: shownKey) == nil { defaults.set(now, forKey: shownKey) }
        if defaults.object(forKey: deadlineKey) == nil { defaults.set(now.addingTimeInterval(window), forKey: deadlineKey) }
    }

    #if DEBUG
    /// QA only: lets the sheet be shown again on this install.
    public static func reset() {
        UserDefaults.standard.removeObject(forKey: shownKey)
        UserDefaults.standard.removeObject(forKey: deadlineKey)
    }
    #endif
}

// MARK: - ExitOfferSheet

public struct ExitOfferSheet: View {
    // MARK: - Configuration
    private let productID: String
    private let strings: ExitOfferStrings
    private let accentColor: Color
    private let palette: PurchasePalette
    private let backgroundColor: Color?
    private let cornerRadius: CGFloat
    private let reason: ExitOfferReason
    private let purchaseOptions: Set<Product.PurchaseOption>
    private let preview: ExitOfferPreview?
    private let onFinished: () -> Void

    // MARK: - Dependencies
    @ObservedObject private var store = StoreKitManager.shared

    // MARK: - State
    @State private var product: Product?
    @State private var isLoading = true
    @State private var isPurchasing = false

    // MARK: - Init
    /// - Parameters:
    ///   - productID: the offer product (must carry an introductory offer in ASC / the .storekit file).
    ///   - onFinished: called when the sheet is done (purchased, declined or nothing to offer); the host dismisses.
    public init(
        productID: String,
        strings: ExitOfferStrings,
        accentColor: Color,
        palette: PurchasePalette = PurchasePalette(),
        backgroundColor: Color? = nil,
        cornerRadius: CGFloat = 6,
        reason: ExitOfferReason,
        purchaseOptions: Set<Product.PurchaseOption> = [],
        preview: ExitOfferPreview? = nil,
        onFinished: @escaping () -> Void
    ) {
        self.productID = productID
        self.strings = strings
        self.accentColor = accentColor
        self.palette = palette
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.reason = reason
        self.purchaseOptions = purchaseOptions
        self.preview = preview
        self.onFinished = onFinished
    }

    public init(configuration: ExitOfferConfiguration, accentColor: Color, palette: PurchasePalette = PurchasePalette(),
                backgroundColor: Color? = nil, cornerRadius: CGFloat = 6, reason: ExitOfferReason,
                onFinished: @escaping () -> Void) {
        self.init(productID: configuration.productID, strings: configuration.strings, accentColor: accentColor,
                  palette: palette, backgroundColor: backgroundColor, cornerRadius: cornerRadius, reason: reason,
                  purchaseOptions: configuration.purchaseOptions, preview: configuration.preview, onFinished: onFinished)
    }

    // MARK: - Computed
    private var offerPrice: String? {
        if let product { return product.subscription?.introductoryOffer?.displayPrice }
        return preview?.offerPrice
    }

    private var regularPrice: String? {
        product?.displayPrice ?? preview?.regularPrice
    }

    private var hasOffer: Bool { offerPrice != nil && regularPrice != nil }

    // MARK: - View Body
    public var body: some View {
        ZStack {
            if let backgroundColor { backgroundColor.ignoresSafeArea() }
            VStack(spacing: 20) {
                hero
                titleBlock
                if isLoading && !hasOffer {
                    ProgressView().tint(palette.text).frame(minHeight: 60)
                } else if hasOffer {
                    offerBlock
                } else {
                    Text(strings.unavailableText)
                        .font(.subheadline)
                        .foregroundStyle(palette.supportingText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 60)
                }
                buttons
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 16)
        }
        .accessibilityIdentifier("paywall.exitOffer")
        .task { await load() }
        .onAppear(perform: handleAppear)
        .onChange(of: store.isPremium) { _, isPremium in
            if isPremium { onFinished() }
        }
    }

    // MARK: - Subviews
    private var hero: some View {
        ZStack {
            Circle().fill(accentColor.opacity(0.15)).frame(width: 72, height: 72)
            Image(systemName: "gift.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(accentColor)
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 8) {
            Text(strings.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(palette.text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle = strings.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(palette.supportingText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var offerBlock: some View {
        VStack(spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(offerPrice ?? "")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(palette.text)
                Text(regularPrice ?? "")
                    .font(.title3)
                    .strikethrough()
                    .foregroundStyle(palette.supportingText)
            }
            Text(strings.priceLine(offerPrice ?? "", regularPrice ?? ""))
                .font(.subheadline)
                .foregroundStyle(palette.supportingText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            deadlinePill
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: cornerRadius).fill(palette.cardFill))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(accentColor, lineWidth: 1.5))
    }

    /// Real countdown to the persisted deadline, refreshed every minute.
    private var deadlinePill: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text(strings.deadlineLabel(Self.remainingText(until: ExitOffer.deadline, now: context.date)))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(accentColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(accentColor.opacity(0.12)))
        }
        .accessibilityIdentifier("paywall.exitOffer.deadline")
    }

    private var buttons: some View {
        VStack(spacing: 8) {
            Button(action: purchase) {
                ZStack {
                    Text(strings.ctaText)
                        .font(.title3.bold())
                        .foregroundStyle(palette.onAccent)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .opacity(isPurchasing ? 0 : 1)
                    if isPurchasing { ProgressView().tint(palette.onAccent) }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: cornerRadius).fill(PaywallCTAFill.gradient(accentColor)))
                .contentShape(Rectangle())
            }
            .disabled(!hasOffer || isPurchasing || product == nil)
            .opacity(hasOffer && product != nil ? 1 : 0.5)
            .accessibilityIdentifier("paywall.exitOffer.cta")
            .accessibilityLabel(strings.ctaText)

            Button(action: onFinished) {
                Text(strings.dismissText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.footerText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("paywall.exitOffer.dismiss")
            .accessibilityLabel(strings.dismissText)
        }
    }

    // MARK: - Actions
    private func handleAppear() {
        ExitOffer.markShown()
        PaywallAnalytics.log(PaywallAnalytics.Event.exitOfferShown,
                             ["reason": reason.rawValue, "product_id": productID])
    }

    private func load() async {
        isLoading = true
        if let cached = store.product(for: productID) {
            product = cached
        } else {
            product = (try? await Product.products(for: [productID]))?.first
        }
        isLoading = false
    }

    /// Loading state until StoreKit answers, on every path (RULES: async system requests).
    private func purchase() {
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        Task { @MainActor in
            defer { isPurchasing = false }
            let transaction = try? await store.purchase(product, options: purchaseOptions)
            if transaction != nil || store.isPremium { onFinished() }
        }
    }

    // MARK: - Helpers
    /// "23 h 12 min" / "45 min" / "0 min" once expired.
    static func remainingText(until deadline: Date?, now: Date) -> String {
        guard let deadline else { return "24 h" }
        let seconds = max(0, Int(deadline.timeIntervalSince(now)))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        return hours > 0 ? "\(hours) h \(minutes) min" : "\(minutes) min"
    }
}
