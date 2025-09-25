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
    // Card style per spec: bg: rgba(255,255,255,0.03), border: rgba(255,255,255,0.08)
    static let tileBG            = Color.p3(1, 1, 1, 0.03)
    static let tileBorder        = Color.p3(1, 1, 1, 0.08)

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
    static let headerButtonBorder = Color.p3(0.325, 0.239, 0.401) // #533D66
    static let buttonBGDefault   = Color.white.opacity(0.12)       // fallback until exact Figma hex is provided

    // App background gradient (Dashboard): linear-gradient(114.2deg, #31233B 0.9%, #130D16 100%)
    static let appBGStart        = Color.p3(0.192, 0.137, 0.231) // #31233B
    static let appBGEnd          = Color.p3(0.074, 0.051, 0.086) // #130D16
    static let gaugeLabel        = Color.white.opacity(0.5)
    static let labelEmphasised   = Color.white.opacity(0.5)
    
    // Hex color initializer
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var i: UInt64 = 0
        Scanner(string: s).scanHexInt64(&i)
        let r = Double((i >> 16) & 0xFF) / 255
        let g = Double((i >> 8) & 0xFF) / 255
        let b = Double(i & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

// MARK: - Typography tokens (Figma)
extension Font {
    static let headerEmphasised   = Font.custom("Inter", size: 12).weight(.semibold)
    static let buttonContent      = Font.custom("Inter", size: 12).weight(.semibold)
    // Title emphasised: Inter-Bold 32pt (single-line; center/alignment is applied per-usage)
    static let titleEmphasised    = Font.custom("Inter", size: 32).weight(.bold)
    static let title40            = Font.custom("Inter", size: 40).weight(.bold)
    static let secondaryEmphasised = Font.custom("Inter", size: 12).weight(.semibold)
    static let caption            = Font.custom("Inter", size: 10)
    // Body: Inter-Medium 18pt
    static let body18             = Font.custom("Inter", size: 18).weight(.medium)
    static let captionEmphasised  = Font.custom("Inter", size: 10).weight(.semibold)
    static let secondary12        = Font.custom("Inter", size: 12)
    // Label emphasised: Inter-SemiBold 10pt
    static let gaugeLabel         = Font.custom("Inter", size: 10).weight(.semibold)
}

// A clean tile modifier that matches your CSS-like spec
struct TileModifier: ViewModifier {
    var height: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.tileBG)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.tileBorder, lineWidth: 1)
            )
    }
}

extension View {
    func tile(height: CGFloat) -> some View { modifier(TileModifier(height: height)) }
}

