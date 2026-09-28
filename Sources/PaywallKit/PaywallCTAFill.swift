//
//  PaywallCTAFill.swift
//  PaywallKit
//

import SwiftUI

// MARK: - Paywall CTA Fill
/// GambitStudio standard: a primary CTA is never a flat fill. It carries a soft
/// top-lit gradient that reads as a raised, tappable surface. Same recipe as
/// `OnboardingCTAFill` in OnboardingKit, kept here so PaywallKit stays dependency-free.
public enum PaywallCTAFill {

    // MARK: - Public Methods

    /// Soft sheen derived from a single colour — full strength on top, easing off below.
    public static func gradient(_ base: Color) -> LinearGradient {
        LinearGradient(
            colors: [base, base.opacity(0.86)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Explicit two-tone fill, for apps that own a light/base pair in their palette.
    public static func gradient(top: Color, bottom: Color) -> LinearGradient {
        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }
}
