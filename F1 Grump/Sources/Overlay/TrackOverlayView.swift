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
    public var rotationDegrees: Double = 0 // rotate car points around center (0.5,0.5)
    public var scaleFactor: CGFloat = 1.2 // scale car positions from center
    public var offsetX: CGFloat = 0 // horizontal offset for car positions
    public var offsetY: CGFloat = 0 // vertical offset for car positions

    public init(assetName: String, carPoints01: [CGPoint], playerIndex: Int, inset: CGFloat = 8, rotationDegrees: Double = 0, scaleFactor: CGFloat = 1.2, offsetX: CGFloat = 0, offsetY: CGFloat = 0) {
        self.assetName = assetName
        self.carPoints01 = carPoints01
        self.playerIndex = playerIndex
        self.inset = inset
        self.rotationDegrees = rotationDegrees
        self.scaleFactor = scaleFactor
        self.offsetX = offsetX
        self.offsetY = offsetY
    }

    public var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                #if DEBUG
                print("TrackOverlayView: Rendering assetName='\(assetName)', carPoints=\(carPoints01.count), playerIndex=\(playerIndex), rotation=\(rotationDegrees)")
                #endif
                guard let raw = SVGPathLoader.shared.loadViewBox(assetName: assetName) else { 
                    #if DEBUG
                    print("TrackOverlayView: Failed to load SVG '\(assetName)'")
                    #endif
                    return 
                }
                let vb = raw.viewBox
                #if DEBUG
                print("TrackOverlayView: Drawing '\(assetName)', viewBox: \(vb), canvas size: \(size)")
                #endif
                var T = Self.fit(viewBox: vb, into: CGRect(x: inset, y: inset, width: size.width - inset*2, height: size.height - inset*2))
                if let path = raw.path.copy(using: &T) {
                    ctx.fill(Path(path), with: .color(Color.white.opacity(0.1)))
                    #if DEBUG
                    print("TrackOverlayView: Filled path for '\(assetName)'")
                    #endif
                }
                // Car dots in normalized space (0..1). Map into fitted rect
                let rect = CGRect(x: inset, y: inset, width: size.width - inset*2, height: size.height - inset*2)
                let radians = rotationDegrees * .pi / 180
                for (i, p) in carPoints01.enumerated() {
                    let rp = Self.rotate01(p, radians: radians)
                    // Scale from center to expand the car positions
                    let scaled = Self.scaleFromCenter(rp, factor: scaleFactor)
                    // Apply offset
                    let offsetted = CGPoint(x: scaled.x + offsetX, y: scaled.y + offsetY)
                    // Flip X coordinate horizontally to match SVG orientation
                    let x = rect.minX + rect.width * (1 - offsetted.x) // Horizontal flip
                    let y = rect.minY + rect.height * (1 - offsetted.y) // y up
                    let r: CGFloat = (i == playerIndex) ? 6 : 4
                    let color: Color = (i == playerIndex) ? .cyan : .white.opacity(0.95)
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

    // Rotate a normalized [0,1] point around the center (0.5, 0.5)
    private static func rotate01(_ p: CGPoint, radians: Double) -> CGPoint {
        if radians == 0 { return p }
        let cx: Double = 0.5
        let cy: Double = 0.5
        let dx = Double(p.x) - cx
        let dy = Double(p.y) - cy
        let cosA = cos(radians)
        let sinA = sin(radians)
        let rx = dx * cosA - dy * sinA + cx
        let ry = dx * sinA + dy * cosA + cy
        return CGPoint(x: rx, y: ry)
    }
    
    // Scale a normalized [0,1] point from center (0.5, 0.5)
    private static func scaleFromCenter(_ p: CGPoint, factor: CGFloat) -> CGPoint {
        let center: CGFloat = 0.5
        let dx = p.x - center
        let dy = p.y - center
        let scaledX = center + dx * factor
        let scaledY = center + dy * factor
        // Clamp to [0,1] to avoid going outside bounds
        return CGPoint(x: max(0, min(1, scaledX)), y: max(0, min(1, scaledY)))
    }
}


