//
//  PurchaseSocialProofView.swift
//  PaywallKit
//
//  Verifiable social proof for the paywall: the store rating and its count, plus one short
//  quote. Placed between the benefits and the plan cards (research 2026-09: proof before the
//  CTA; never "App of the Year"-style claims). The app passes REAL numbers — the kit renders
//  whatever it receives, so pass the live rating from the store, never an invented one.
//
//  Usage:
//      PurchaseScaffold(
//          ...,
//          socialProof: PurchaseSocialProof(
//              rating: "4,8",
//              ratingCountText: String(localized: "paywall.social.count \\(count)"),
//              quote: String(localized: "paywall.social.quote"),
//              author: String(localized: "paywall.social.author")
//          )
//      )
//

import SwiftUI

// MARK: - Model

public struct PurchaseSocialProof: Sendable {
    /// Rating as displayed ("4,8"); nil hides the stars row.
    public let rating: String?
    /// "1.240 avaliações" — the app formats the count in its locale.
    public let ratingCountText: String?
    /// One short quote; nil hides the quote row.
    public let quote: String?
    /// "— Marina, São Paulo".
    public let author: String?

    public init(rating: String? = nil, ratingCountText: String? = nil, quote: String? = nil, author: String? = nil) {
        self.rating = rating
        self.ratingCountText = ratingCountText
        self.quote = quote
        self.author = author
    }
}

// MARK: - View

struct PurchaseSocialProofView: View {
    // MARK: - Properties
    let proof: PurchaseSocialProof
    let accentColor: Color
    var palette = PurchasePalette()
    var cornerRadius: CGFloat = 6
    /// The densest paywall layout keeps the stars and the count and drops the quote.
    var showsQuote = true

    // MARK: - View Body
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if proof.rating != nil || proof.ratingCountText != nil {
                ratingRow
            }
            if showsQuote, let quote = proof.quote {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\u{201C}\(quote)\u{201D}")
                        .font(.footnote)
                        .italic()
                        .foregroundStyle(palette.text)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let author = proof.author {
                        Text(author)
                            .font(.caption2)
                            .foregroundStyle(palette.supportingText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: cornerRadius).fill(palette.cardFill))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("paywall.socialProof")
    }

    // MARK: - Subviews
    private var ratingRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
            }
            if let rating = proof.rating {
                Text(rating)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.text)
            }
            if let count = proof.ratingCountText {
                Text(count)
                    .font(.subheadline)
                    .foregroundStyle(palette.supportingText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
