//
//  PaywallProPromptSheet.swift
//  PaywallKit
//
//  The "this is a Pro feature" bottom sheet — shown the moment a user taps a locked
//  element. Same brand-gradient model as PaywallScaffold (GambitStudio paywall standard). From here the
//  user opens the full paywall (onDiscover) or dismisses (onDismiss).
//
//  Usage (host owns the two-step presentation):
//      .sheet(isPresented: $showPrompt) {
//          PaywallProPromptSheet(
//              gradient: [AppColors.primary, AppColors.primary.opacity(0.8)],
//              title: String(localized: "pro.gate.title"),
//              message: String(localized: "pro.gate.message"),
//              perks: [.init(symbol: "wand.and.stars", title: "…"), …],
//              discoverButtonText: String(localized: "pro.gate.discover"),
//              dismissButtonText: String(localized: "pro.gate.notNow"),
//              onDiscover: { showPrompt = false; openPaywall() },
//              onDismiss: { showPrompt = false }
//          )
//          .presentationDetents([.height(500)])
//          .presentationDragIndicator(.hidden)
//      }
//

import SwiftUI

public struct PaywallProPromptSheet: View {
    // MARK: - Configuration
    private let gradient: [Color]
    private let accent: Color
    private let title: String
    private let message: String
    private let perks: [PaywallFeatureItem]
    private let discoverButtonText: String
    private let dismissButtonText: String
    private let onDiscover: () -> Void
    private let onDismiss: () -> Void

    // MARK: - Init
    public init(
        gradient: [Color],
        accent: Color? = nil,
        title: String,
        message: String,
        perks: [PaywallFeatureItem],
        discoverButtonText: String,
        dismissButtonText: String,
        onDiscover: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.gradient = gradient
        self.accent = accent ?? gradient.first ?? .blue
        self.title = title
        self.message = message
        self.perks = perks
        self.discoverButtonText = discoverButtonText
        self.dismissButtonText = dismissButtonText
        self.onDiscover = onDiscover
        self.onDismiss = onDismiss
    }

    // MARK: - View Body
    public var body: some View {
        ZStack {
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                ZStack {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.85, blue: 0.0).opacity(0.2))
                        .frame(width: 76, height: 76)
                    Image(systemName: "crown.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Color(red: 1.0, green: 0.85, blue: 0.0))
                }
                .padding(.top, 4)

                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                VStack(spacing: 10) {
                    ForEach(perks) { perk in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.white.opacity(0.2)).frame(width: 34, height: 34)
                                Image(systemName: perk.symbol)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.white)
                            }
                            Text(perk.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 2)

                Button(action: onDiscover) {
                    Text(discoverButtonText)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)

                Button(action: onDismiss) {
                    Text(dismissButtonText)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
