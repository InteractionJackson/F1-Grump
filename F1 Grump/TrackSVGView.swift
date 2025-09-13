import SwiftUI
import PocketSVG
import UIKit

struct TrackSVGView: UIViewRepresentable {
    /// Pass a filename without extension (e.g. "gb-1948").
    /// We look in bundle subdirectory "assets/track outlines" or at root.
    let filename: String

    func makeUIView(context: Context) -> TrackSVGContainer {
        let v = TrackSVGContainer()
        v.backgroundColor = .clear
        v.loadSVG(named: filename)
        return v
    }

    func updateUIView(_ uiView: TrackSVGContainer, context: Context) {
        uiView.loadSVG(named: filename)
    }
}

final class TrackSVGContainer: UIView {
    private var baseLayer = CALayer()
    private var layers: [CAShapeLayer] = []
    private var currentName = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        layer.addSublayer(baseLayer)
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError() }

    func loadSVG(named name: String) {
        guard name != currentName else { return }
        currentName = name
        layers.forEach { $0.removeFromSuperlayer() }
        layers.removeAll()

        // Try exact match first
        var url = Bundle.main.url(forResource: name, withExtension: "svg", subdirectory: "assets/track outlines")
              ?? Bundle.main.url(forResource: name, withExtension: "svg")
        // If not found, try fuzzy match against all files in the folder
        if url == nil {
            url = bestMatchURL(for: name)
        }
        guard let url else { return }

        // Parse paths
        let paths = SVGBezierPath.pathsFromSVG(at: url)
        guard !paths.isEmpty else { return }

        // Merge into layers
        for p in paths {
            let shape = CAShapeLayer()
            shape.path = p.cgPath
            shape.fillColor = UIColor.clear.cgColor
            shape.strokeColor = UIColor.white.cgColor
            shape.lineWidth = 16
            shape.lineJoin = .round
            shape.lineCap = .round
            baseLayer.addSublayer(shape)
            layers.append(shape)
        }
        setNeedsLayout()
    }

    private func bestMatchURL(for hint: String) -> URL? {
        let normHint = normalize(hint)
        let urls = Bundle.main.urls(forResourcesWithExtension: "svg", subdirectory: "assets/track outlines") ?? []
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


