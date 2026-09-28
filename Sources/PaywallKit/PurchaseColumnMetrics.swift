//
//  PurchaseColumnMetrics.swift
//  PaywallKit
//
//  The paywall column in progressively tighter densities. With social proof and/or the trial
//  timeline the column carries ~200pt more than the classic layout, and the CTA + legal footer
//  MUST stay above the fold (a CTA behind a scroll is a conversion bug, kits r2 review
//  28/09/2026). `PurchaseScaffold` offers the densities to a `ViewThatFits` in order and
//  renders the first one whose natural height fits the screen, so the choice adapts to the
//  phone AND to the locale (a long pt-BR benefit wraps where the en-US one does not).
//  What gives way, in order: the hero shrinks, then it goes; the gaps tighten; the cancel
//  note of the timeline goes (the charge line already says it); last, the social proof keeps
//  the stars and the count but drops the quote. Nothing is ever truncated — text wraps.
//

import SwiftUI

// MARK: - Density

enum PurchaseColumnDensity: CaseIterable {
    /// Classic column (no social proof, no timeline): scrolls on short canvases.
    case regular
    /// Dense, full hero band (64-88pt).
    case roomy
    /// Dense, small hero, tighter gaps.
    case compact
    /// Dense, no hero, compact timeline and cards.
    case tight
    /// `tight` + the social proof reduced to stars and count.
    case minimal

    /// Dense densities in the order the scaffold tries them.
    static let denseLadder: [PurchaseColumnDensity] = [.roomy, .compact, .tight, .minimal]
}

// MARK: - Metrics

struct PurchaseColumnMetrics {
    let density: PurchaseColumnDensity

    /// Hero height for the canvas; nil hides the hero.
    func heroHeight(canvasHeight: CGFloat) -> CGFloat? {
        switch density {
        case .regular: return min(140, max(80, canvasHeight * 0.16))
        case .roomy: return min(88, max(64, canvasHeight * 0.10))
        case .compact: return 48
        case .tight, .minimal: return nil
        }
    }

    /// Top inset of the column (the close row overlays the first 44pt).
    var topInset: CGFloat { density == .regular || density == .roomy ? 44 : 40 }
    var leadingGap: CGFloat { isDense ? (density == .roomy ? 12 : 4) : 16 }
    var bandMin: CGFloat { isDense ? (density == .roomy ? 12 : 8) : 20 }
    var heroTitleMax: CGFloat { isDense ? 20 : 40 }
    var titleBenefitsMax: CGFloat { isDense ? 20 : 48 }
    var titleSize: CGFloat { isDense ? (density == .roomy ? 26 : 24) : 30 }
    var featureSize: CGFloat { isDense ? (density == .roomy ? 17 : 16) : 19 }
    var featureSpacing: CGFloat { isDense ? (density == .roomy ? 8 : 4) : 14 }
    var proofGap: CGFloat { density == .roomy ? 12 : 8 }
    var plansGap: CGFloat { isDense ? (density == .roomy ? 12 : 8) : 16 }
    var plansExtraGap: CGFloat { isDense ? 0 : 8 }
    var timelineTop: CGFloat { density == .roomy ? 8 : 6 }
    var ctaTop: CGFloat { isDense ? (density == .roomy ? 10 : 8) : 16 }
    var footerTop: CGFloat { isDense ? 2 : 8 }
    var footerBottom: CGFloat { isDense ? 0 : 8 }
    /// Cards, badge and timeline in their compact variant.
    var compactCards: Bool { density == .tight || density == .minimal }
    var showsQuote: Bool { density != .minimal }

    private var isDense: Bool { density != .regular }
}
