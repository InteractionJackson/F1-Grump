// README: TrackOverlayView
// Pure SwiftUI overlay that draws a track SVG (no basemap) and car dots on top.
// - Scales SVG to fit its container with a configurable inset.
// - Accepts car points in normalized [0,1]×[0,1] SVG space (or provide a transform).
// - Uses SVGPathLoader.loadViewBox to cache and reuse parsed path.

import SwiftUI

public struct TrackOverlayView: View {
    public let assetName: String
    public let carPoints01: [CGPoint]
    public let playerIndex: Int
    public var inset: CGFloat = 8

    public init(assetName: String, carPoints01: [CGPoint], playerIndex: Int, inset: CGFloat = 8) {
        self.assetName = assetName
        self.carPoints01 = carPoints01
        self.playerIndex = playerIndex
        self.inset = inset
    }

    public var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                guard let raw = SVGPathLoader.shared.loadViewBox(assetName: assetName) else { return }
                let vb = raw.viewBox
                var T = Self.fit(viewBox: vb, into: CGRect(x: inset, y: inset, width: size.width - inset*2, height: size.height - inset*2))
                if let path = raw.path.copy(using: &T) {
                    ctx.stroke(Path(path), with: .color(Color(red: 0.604, green: 0.902, blue: 1.0).opacity(0.7)), lineWidth: 2, lineCap: .round, lineJoin: .round)
                }
                // Car dots in normalized space (0..1). Map into fitted rect
                let rect = CGRect(x: inset, y: inset, width: size.width - inset*2, height: size.height - inset*2)
                for (i, p) in carPoints01.enumerated() {
                    let x = rect.minX + rect.width * p.x
                    let y = rect.minY + rect.height * (1 - p.y) // y up
                    let r: CGFloat = (i == playerIndex) ? 4 : 3
                    let color: Color = (i == playerIndex) ? .cyan : .white.opacity(0.85)
                    let ellipse = Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r*2, height: r*2))
                    ctx.fill(ellipse, with: .color(color))
                }
            }
        }
    }

    private static func fit(viewBox vb: CGRect, into rect: CGRect) -> CGAffineTransform {
        let sx = rect.width / vb.width
        let sy = rect.height / vb.height
        let s = min(sx, sy)
        let tx = rect.midX - vb.midX * s
        let ty = rect.midY - vb.midY * s
        return CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: tx, ty: ty)
    }
}


