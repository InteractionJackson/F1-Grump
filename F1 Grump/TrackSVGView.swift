import SwiftUI
import PocketSVG
import UIKit

struct TrackSVGView: UIViewRepresentable {
    /// Pass a filename without extension (e.g. "gb-1948").
    /// We look in bundle subdirectory "assets/track outlines" or at root.
    let filename: String
    var carPoints: [CGPoint] = []      // normalized 0..1
    var playerIndex: Int = 0

    func makeUIView(context: Context) -> TrackSVGContainer {
        let v = TrackSVGContainer()
        v.backgroundColor = .clear
        v.loadSVG(named: filename)
        v.setCarPoints(carPoints, playerIndex: playerIndex)
        return v
    }

    func updateUIView(_ uiView: TrackSVGContainer, context: Context) {
        uiView.loadSVG(named: filename)
        uiView.setCarPoints(carPoints, playerIndex: playerIndex)
    }
}

final class TrackSVGContainer: UIView {
    private var baseLayer = CALayer()
    private var layers: [CAShapeLayer] = []
    private let dotsLayer = CAShapeLayer()
    private var normalizedPoints: [CGPoint] = []
    private var playerIdx: Int = 0
    private var currentName = ""
    private var fittedRect: CGRect = .zero
    private var combinedPath: CGPath?

    private enum DotMapping: CaseIterable {
        case xy, flipX, flipY, flipXY, swap, swapFlipX, swapFlipY, swapFlipXY
    }
    private var mapping: DotMapping = .xy
    private var mappingResolved = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        layer.addSublayer(baseLayer)
        dotsLayer.fillColor = UIColor.black.cgColor
        dotsLayer.strokeColor = UIColor.clear.cgColor
        dotsLayer.lineWidth = 0
        baseLayer.addSublayer(dotsLayer)
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError() }

    func loadSVG(named name: String) {
        guard name != currentName else { return }
        currentName = name
        layers.forEach { $0.removeFromSuperlayer() }
        layers.removeAll()
        combinedPath = nil
        mappingResolved = false

        // Try exact match first
        var url = Bundle.main.url(forResource: name, withExtension: "svg", subdirectory: "assets/track outlines")
              ?? Bundle.main.url(forResource: name, withExtension: "svg")
        // If not found, try fuzzy match against all files in the folder
        if url == nil {
            url = bestMatchURL(for: name)
        }
        guard let url else {
            #if DEBUG
            print("⚠️ TrackSVGView: SVG not found for '", name, "'")
            let sub = Bundle.main.urls(forResourcesWithExtension: "svg", subdirectory: "assets/track outlines")?.map { $0.lastPathComponent } ?? []
            let root = Bundle.main.urls(forResourcesWithExtension: "svg", subdirectory: nil)?.map { $0.lastPathComponent } ?? []
            print("Available track SVGs (assets/track outlines):", sub)
            print("Available SVGs (bundle root):", root)
            #endif
            return
        }

        // Parse paths
        let paths = SVGBezierPath.pathsFromSVG(at: url)
        guard !paths.isEmpty else {
            #if DEBUG
            print("⚠️ TrackSVGView: SVG had no paths at", url)
            #endif
            return
        }

        // Merge into layers
        for p in paths {
            let shape = CAShapeLayer()
            shape.path = p.cgPath
            shape.fillColor = UIColor.white.cgColor
            shape.strokeColor = UIColor.clear.cgColor
            shape.lineWidth = 0
            shape.lineJoin = .round
            shape.lineCap = .round
            baseLayer.addSublayer(shape)
            layers.append(shape)
        }
        setNeedsLayout()
    }

    func setCarPoints(_ pts: [CGPoint], playerIndex: Int) {
        normalizedPoints = pts
        playerIdx = playerIndex
        renderDots()
    }

    private func bestMatchURL(for hint: String) -> URL? {
        let normHint = normalize(hint)
        var urls = Bundle.main.urls(forResourcesWithExtension: "svg", subdirectory: "assets/track outlines") ?? []
        if urls.isEmpty {
            urls = Bundle.main.urls(forResourcesWithExtension: "svg", subdirectory: nil) ?? []
        }
        // Prefer names without the trailing " - White_*" part
        var best: (score: Int, url: URL)?
        for u in urls {
            let base = u.deletingPathExtension().lastPathComponent
            let cleaned = base.replacingOccurrences(of: #"\s*-\s*white[\w-]*$"#, with: "", options: .regularExpression, range: nil)
            let norm = normalize(cleaned)
            let score = matchScore(a: normHint, b: norm)
            if score > (best?.score ?? -1) { best = (score, u) }
        }
        return best?.url
    }

    private func normalize(_ s: String) -> String {
        let lowered = s.lowercased()
        let stripped = lowered.replacingOccurrences(of: "white", with: "")
        return stripped.replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }

    private func matchScore(a: String, b: String) -> Int {
        if a == b { return 1000 }
        if a.contains(b) || b.contains(a) { return 800 }
        // partial overlap count
        let common = Set(a).intersection(Set(b)).count
        return common
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        baseLayer.frame = bounds
        // Compute union
        let union = layers.reduce(CGRect.null) { r, l in
            r.union(l.path?.boundingBoxOfPath ?? .null)
        }
        guard union.width > 0, union.height > 0 else { return }
        let t = aspectFitTransform(for: union, in: bounds)
        for l in layers { l.setAffineTransform(t) }
        // Cache the fitted drawing rect (where the track was drawn)
        fittedRect = union.applying(t)
        // Build a combined path in view coordinates for hit-testing
        let combined = CGMutablePath()
        for l in layers {
            if let p = l.path {
                var lt = l.affineTransform()
                if let tp = p.copy(using: &lt) { combined.addPath(tp) }
            }
        }
        combinedPath = combined.copy()
        renderDots()
    }

    private func renderDots() {
        // Build a path of small circles from normalized 0..1 points
        let path = UIBezierPath()
        let rOthers: CGFloat = 3
        let rPlayer: CGFloat = 5
        // Use the same fitted rect as the SVG so dots sit on top correctly
        let rect = (fittedRect.width > 0 && fittedRect.height > 0) ? fittedRect : bounds
        // Resolve the best flip/swap mapping once we have enough data and a path
        if !mappingResolved, normalizedPoints.count >= 8, let hitPath = combinedPath {
            mapping = bestMapping(for: normalizedPoints, in: rect, hitPath: hitPath)
            mappingResolved = true
            #if DEBUG
            print("TrackSVGView: resolved dot mapping =", mapping)
            #endif
        }
        for (i, p) in normalizedPoints.enumerated() {
            let mapped = mapPoint(p, in: rect, mapping: mapping)
            let x = mapped.x
            let y = mapped.y
            let r = (i == playerIdx) ? rPlayer : rOthers
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            path.append(UIBezierPath(ovalIn: rect))
        }
        dotsLayer.path = path.cgPath
        dotsLayer.opacity = normalizedPoints.isEmpty ? 0 : 1
    }

    private func mapPoint(_ p: CGPoint, in rect: CGRect, mapping: DotMapping) -> CGPoint {
        // base axes
        let x = CGFloat(p.x)
        let y = CGFloat(p.y)
        var u: CGFloat = 0
        var v: CGFloat = 0
        switch mapping {
        case .xy:          (u, v) = (x, 1 - y)
        case .flipX:       (u, v) = (1 - x, 1 - y)
        case .flipY:       (u, v) = (x, y)
        case .flipXY:      (u, v) = (1 - x, y)
        case .swap:        (u, v) = (y, 1 - x)
        case .swapFlipX:   (u, v) = (1 - y, 1 - x)
        case .swapFlipY:   (u, v) = (y, x)
        case .swapFlipXY:  (u, v) = (1 - y, x)
        }
        // Maintain the same aspect-fit scaling used by the SVG: we already use the fittedRect for position,
        // but if normalization used independent axes, compensate by uniform scaling around rect center.
        // Compute extents of normalized points to refine scale so dots sit within the track bbox.
        return CGPoint(x: rect.minX + u * rect.width,
                       y: rect.minY + v * rect.height)
    }

    private func bestMapping(for pts: [CGPoint], in rect: CGRect, hitPath: CGPath) -> DotMapping {
        // Try all mappings and pick the one that places the most points inside the track fill
        var best = DotMapping.xy
        var bestScore = -1
        let candidates = DotMapping.allCases
        // Use a sample of up to 100 points
        let sample = pts.prefix(100)
        for m in candidates {
            var inside = 0
            for p in sample {
                let q = mapPoint(p, in: rect, mapping: m)
                if hitPath.contains(q, using: .winding, transform: .identity) { inside += 1 }
            }
            if inside > bestScore {
                bestScore = inside
                best = m
            }
        }
        return best
    }
}

private func aspectFitTransform(for src: CGRect, in dst: CGRect) -> CGAffineTransform {
    guard src.width > 0, src.height > 0, dst.width > 0, dst.height > 0 else { return .identity }
    let sx = dst.width / src.width
    let sy = dst.height / src.height
    let s = min(sx, sy)
    let tx = dst.midX - src.midX * s
    let ty = dst.midY - src.midY * s
    return CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: tx, ty: ty)
}


