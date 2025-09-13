//
//  Theme.swift
//  F1 Grump
//
//  Created by Matt Jackson on 12/09/2025.
//

import SwiftUI

// Display-P3 colors, like your spec
extension Color {
    static func p3(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> Color {
        Color(.displayP3, red: r, green: g, blue: b, opacity: a)
    }
    static let appGradientTop    = Color.p3(0.639, 0.475, 0.886) // #A379E2
    static let appGradientBottom = Color.p3(0.490, 0.255, 0.839) // #7D41D6
    static let tileBG            = Color.p3(0, 0, 0, 0.21)
    static let tileBorder        = Color.p3(0, 0, 0, 0.47)

    // Dashboard (dark) tokens
    static let textPrimary       = Color.white
    static let textSecondary     = Color.white.opacity(0.8)
    static let progressTrack     = Color.white.opacity(0.08)
    static let accentRPM         = Color.green
    static let accentERS         = Color.cyan
    static let accentBrake       = Color.red

    // DRS chip (open)
    static let drsOpenBG         = Color.p3(0.478, 0.808, 0.882) // #7ACEE1
    static let drsOpenText       = Color.p3(0.067, 0.251, 0.294) // #11404B

    // Sector text colors
    static let sectorFastest     = Color.p3(0.706, 0.478, 0.882) // #B47AE1
    static let sectorPersonal    = Color.p3(0.498, 0.882, 0.478) // #7FE17A
    static let sectorOver        = Color.p3(0.882, 0.780, 0.478) // #E1C77A

    // Header / chrome
    static let headerBG          = Color.p3(0.08, 0.06, 0.13, 0.85)
    static let headerBorder      = Color.p3(0, 0, 0, 0.35)
    static let headerIcon        = Color.white
}

// A clean tile modifier that matches your CSS-like spec
struct TileModifier: ViewModifier {
    var height: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
            .background(Color.tileBG)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.tileBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

extension View {
    func tile(height: CGFloat) -> some View { modifier(TileModifier(height: height)) }
}

