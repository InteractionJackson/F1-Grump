#if false
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
    private let dotsLayer = CAShapeLayer()
    private let outlineLayer = CAShapeLayer()
    private var normalizedPoints: [CGPoint] = []
    private var sampleCloud: [CGPoint] = []
    private var playerIdx: Int = 0
    private var currentName = ""
    private var fittedRect: CGRect = .zero
    private var combinedPath: CGPath?

    // Similarity transform (rotation + uniform scale + translation), optional reflection
    private var similarityTransform: CGAffineTransform = .identity
    private var transformResolved = false
    private var cachedTrackName: String = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        layer.addSublayer(baseLayer)
        outlineLayer.strokeColor = UIColor.clear.cgColor
        outlineLayer.fillColor = UIColor(white: 1, alpha: 0.10).cgColor
        outlineLayer.lineWidth = 0
        outlineLayer.lineJoin = .round
        outlineLayer.lineCap = .round
        outlineLayer.name = "polylineOutline"
        baseLayer.addSublayer(outlineLayer)
        dotsLayer.fillColor = UIColor.systemGreen.cgColor
        dotsLayer.strokeColor = UIColor.black.withAlphaComponent(0.6).cgColor
        dotsLayer.lineWidth = 1
        baseLayer.addSublayer(dotsLayer)
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError() }

    func loadSVG(named name: String) {
        guard name != currentName else { return }
        currentName = name
        outlineLayer.path = nil
        combinedPath = nil
        transformResolved = false
        cachedTrackName = name
        if let t = TrackPolylineStore.shared.loadTransform(track: name) {
            similarityTransform = t
            transformResolved = true
        }

        // Force-load from bundle subdirectory "assets/track outlines" only (no root fallback)
        var url = Bundle.main.url(forResource: name, withExtension: "svg", subdirectory: "assets/track outlines")
        // If exact name not found, try fuzzy match within that subdirectory only
        if url == nil { url = bestMatchURL(for: name) }
        guard let url else {
            #if DEBUG
            print("⚠️ TrackSVGView: SVG not found for '", name, "'")
            let sub = Bundle.main.urls(forResourcesWithExtension: "svg", subdirectory: "assets/track outlines")?.map { $0.lastPathComponent } ?? []
            print("Available track SVGs (assets/track outlines only):", sub)
            #endif
            return
        }

        // Parse paths; if SVG empty, fall back to geojson outline
        let paths = SVGBezierPath.pathsFromSVG(at: url)
        if !paths.isEmpty {
            let combined = CGMutablePath()
            for p in paths { combined.addPath(p.cgPath) }
            combinedPath = combined.copy()
        } else {
            #if DEBUG
            print("⚠️ TrackSVGView: SVG had no paths at", url, "— attempting GeoJSON fallback for", name)
            #endif
            let segs = loadGeoJSONOutline(named: name)
            if !segs.isEmpty {
                let combined = CGMutablePath()
                for seg in segs where !seg.isEmpty {
                    combined.addLines(between: seg)
                }
                combinedPath = combined.copy()
            }
        }
        guard combinedPath != nil else { return }
        setNeedsLayout()
    }

    func setCarPoints(_ pts: [CGPoint], playerIndex: Int) {
        normalizedPoints = pts
        playerIdx = playerIndex
        // Accumulate a denser, more complete cloud for alignment
        if !pts.isEmpty {
            if sampleCloud.count < 2000 {
                // Simple de-dup by bucketing to 1% grid to avoid flooding
                for p in pts {
                    let q = CGPoint(x: (p.x*100).rounded()/100, y: (p.y*100).rounded()/100)
                    if !sampleCloud.contains(where: { abs($0.x - q.x) < 0.0001 && abs($0.y - q.y) < 0.0001 }) {
                        sampleCloud.append(q)
                    }
                }
            } else {
                sampleCloud.removeFirst(min(pts.count, sampleCloud.count/10))
            }
        }
        renderDots()
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
        // Compute fitted rect and outline path if we have a combined SVG path
        if let cp = combinedPath {
            let svgBounds = cp.boundingBoxOfPath
            let t = aspectFitTransform(for: svgBounds, in: bounds)
            fittedRect = svgBounds.applying(t)
            var tVar = t
            if let tp = cp.copy(using: &tVar) {
                outlineLayer.path = tp
            }
            // Outline path changed → recompute transform next render
            transformResolved = false
        }
        renderDots()
    }

    private func renderDots() {
        // Build a path of small circles from normalized 0..1 points
        let path = UIBezierPath()
        let rOthers: CGFloat = 3
        let rPlayer: CGFloat = 5
        // Use the exact fitted rect that the SVG occupies
        let rect = (fittedRect.width > 0 && fittedRect.height > 0) ? fittedRect : bounds
        // Resolve a best-fit similarity transform once we have enough data and an outline path
        if !transformResolved, sampleCloud.count >= 200, let outlinePath = outlineLayer.path, rect.width > 0, rect.height > 0 {
            similarityTransform = resolveSimilarityTransform(points01: sampleCloud, targetRect: rect, outlinePath: outlinePath)
            transformResolved = true
            TrackPolylineStore.shared.saveTransform(track: cachedTrackName, transform: similarityTransform)
            #if DEBUG
            print("TrackSVGView: resolved similarity transform")
            #endif
        }
        var inside = 0
        var mappedPoints: [CGPoint] = []
        mappedPoints.reserveCapacity(normalizedPoints.count)
        for (_, p) in normalizedPoints.enumerated() {
            let mapped = mapPointSimilarity(p, fallbackRect: rect)
            mappedPoints.append(mapped)
            if rect.contains(mapped) { inside += 1 }
        }
        // If nothing lands inside, fall back for this frame and try to re-resolve later
        if transformResolved && inside == 0 {
            #if DEBUG
            print("TrackSVGView: no dots inside bounds after transform – using fallback this frame")
            #endif
            transformResolved = false
            mappedPoints.removeAll(keepingCapacity: true)
            for p in normalizedPoints { mappedPoints.append(mapPointSimilarity(p, fallbackRect: rect)) }
        }

        for (i, mapped) in mappedPoints.enumerated() {
            let x = mapped.x
            let y = mapped.y
            let r = (i == playerIdx) ? rPlayer : rOthers
            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
            path.append(UIBezierPath(ovalIn: rect))
        }
        dotsLayer.path = path.cgPath
        dotsLayer.opacity = normalizedPoints.isEmpty ? 0 : 1
        dotsLayer.isHidden = normalizedPoints.isEmpty
    }

    private func mapPointSimilarity(_ p: CGPoint, fallbackRect: CGRect) -> CGPoint {
        // Base mapping from normalized telemetry (0..1) to a unit square with UIKit Y-down
        let base = CGPoint(x: CGFloat(p.x), y: CGFloat(p.y))
        if transformResolved {
            return base.applying(similarityTransform)
        } else {
            // Fallback: simple aspect-fit into the fittedRect
            return CGPoint(x: fallbackRect.minX + base.x * fallbackRect.width,
                           y: fallbackRect.minY + base.y * fallbackRect.height)
        }
    }

    // Compute a best-fit transform from normalized points (0..1) to the outline's fitted rect.
    // Preserve base scale-to-rect; adjust only rotation/translation (and optional mirror) around centroids.
    private func resolveSimilarityTransform(points01: [CGPoint], targetRect: CGRect, outlinePath: CGPath) -> CGAffineTransform {
        // 1) Base mapping to fitted rect
        let baseT = fallbackTransform(for: targetRect)
        let srcUnit = points01.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        let srcViewBase = srcUnit.map { $0.applying(baseT) }

        // 2) Build dense samples from outline by arc length to match count
        let outlineDense = samplePathByLength(outlinePath, targetCount: max(200, min(1000, srcViewBase.count)))
        guard !outlineDense.isEmpty, srcViewBase.count >= 3 else { return baseT }

        // 3) Procrustes: compute rotation (and optional mirror) around centers
        func procrustes(_ A: [CGPoint], _ B: [CGPoint], allowMirror: Bool) -> CGAffineTransform {
            // Center
            func centroid(_ pts: [CGPoint]) -> CGPoint {
                var cx: CGFloat = 0, cy: CGFloat = 0
                for p in pts { cx += p.x; cy += p.y }
                let n = CGFloat(max(1, pts.count))
                return CGPoint(x: cx/n, y: cy/n)
            }
            let muA = centroid(A), muB = centroid(B)
            let A0 = A.map { CGPoint(x: $0.x - muA.x, y: $0.y - muA.y) }
            let B0 = B.map { CGPoint(x: $0.x - muB.x, y: $0.y - muB.y) }
            // Cross-covariance 2x2
            var h11: CGFloat = 0, h12: CGFloat = 0, h21: CGFloat = 0, h22: CGFloat = 0
            for k in 0..<A0.count { h11 += A0[k].x * B0[k].x; h12 += A0[k].x * B0[k].y; h21 += A0[k].y * B0[k].x; h22 += A0[k].y * B0[k].y }
            // SVD(H) for 2x2 via closed form using atan2
            // Compute rotation R that maximizes trace(R^T H)
            let rotAngle = atan2(h12 - h21, h11 + h22)
            var R = CGAffineTransform(rotationAngle: rotAngle)
            if allowMirror {
                // Check if mirroring improves alignment by flipping X
                let rotM = CGAffineTransform(a: -cos(rotAngle), b: -sin(rotAngle), c: sin(rotAngle), d: -cos(rotAngle), tx: 0, ty: 0)
                // Score by sum of dot products
                func score(_ T: CGAffineTransform) -> CGFloat {
                    var s: CGFloat = 0
                    for k in 0..<A0.count { let v = A0[k].applying(T); s += v.x * B0[k].x + v.y * B0[k].y }
                    return s
                }
                if score(rotM) > score(R) { R = rotM }
            }
            // Uniform scale s = trace(R^T H) / ||A0||^2
            var num: CGFloat = 0, den: CGFloat = 0
            for k in 0..<A0.count {
                let v = A0[k].applying(R)
                num += v.x * B0[k].x + v.y * B0[k].y
                den += A0[k].x * A0[k].x + A0[k].y * A0[k].y
            }
            let s = (den > 0) ? (num / den) : 1
            // Translation
            let t = CGAffineTransform(translationX: muB.x, y: muB.y)
                .concatenating(CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: 0, ty: 0))
                .concatenating(R)
                .concatenating(CGAffineTransform(translationX: -muA.x, y: -muA.y))
            return t
        }

        // 4) ICP (iterative closest point) to avoid point-correspondence issues
        func rms(_ T: CGAffineTransform) -> CGFloat {
            var s: CGFloat = 0
            let n = min(srcViewBase.count, outlineDense.count)
            for i in 0..<n {
                let v = srcViewBase[i].applying(T)
                let o = outlineDense[i]
                let dx = v.x - o.x
                let dy = v.y - o.y
                s += dx * dx + dy * dy
            }
            return sqrt(max(0, s / CGFloat(max(1, n))))
        }
        func nearest(_ p: CGPoint, in cloud: [CGPoint]) -> CGPoint {
            var best = cloud[0]
            var bd = CGFloat.greatestFiniteMagnitude
            for q in cloud {
                let dx = p.x - q.x, dy = p.y - q.y
                let d = dx*dx + dy*dy
                if d < bd { bd = d; best = q }
            }
            return best
        }
        func solveICP(for srcView: [CGPoint]) -> CGAffineTransform {
            var T = CGAffineTransform.identity
            var lastErr = CGFloat.greatestFiniteMagnitude
            for _ in 0..<7 {
                var targets: [CGPoint] = []
                targets.reserveCapacity(srcView.count)
                for p in srcView { targets.append(nearest(p.applying(T), in: outlineDense)) }
                let Tstep = procrustes(srcView, targets, allowMirror: true)
                T = Tstep.concatenating(T)
                let err = rms(T)
                if abs(lastErr - err) < 0.25 { break }
                lastErr = err
            }
            return T
        }

        // Try orientation variants in unit space: identity, flipX, flipY, flipBoth (around unit center)
        func flipUnit(_ p: CGPoint, flipX: Bool, flipY: Bool) -> CGPoint {
            let cx: CGFloat = 0.5, cy: CGFloat = 0.5
            let fx: CGFloat = flipX ? -1.0 : 1.0
            let fy: CGFloat = flipY ? -1.0 : 1.0
            let x = cx + (p.x - cx) * fx
            let y = cy + (p.y - cy) * fy
            return CGPoint(x: x, y: y)
        }
        var candidates: [CGAffineTransform] = []
        let variants: [(Bool,Bool)] = [(false,false),(true,false),(false,true),(true,true)]
        for (fx, fy) in variants {
            let srcVarUnit = srcUnit.map { flipUnit($0, flipX: fx, flipY: fy) }
            let srcVarView = srcVarUnit.map { $0.applying(baseT) }
            let Ticp = solveICP(for: srcVarView)
            candidates.append(baseT.concatenating(Ticp))
        }
        // Try quarter-turn rotations about rect center to handle SVGs rotated by 90/180 deg
        let c = CGPoint(x: targetRect.midX, y: targetRect.midY)
        func rotAbout(_ angle: CGFloat) -> CGAffineTransform {
            CGAffineTransform(translationX: c.x, y: c.y)
                .rotated(by: angle)
                .translatedBy(x: -c.x, y: -c.y)
        }
        func rmsGlobal(_ Tf: CGAffineTransform) -> CGFloat {
            var s: CGFloat = 0
            let n = min(srcUnit.count, outlineDense.count)
            for i in 0..<n {
                let v = srcUnit[i].applying(Tf)
                let o = outlineDense[i]
                let dx = v.x - o.x, dy = v.y - o.y
                s += dx*dx + dy*dy
            }
            return sqrt(max(0, s / CGFloat(max(1, n))))
        }
        candidates = candidates.flatMap { T in [
            T,
            T.concatenating(rotAbout(CGFloat.pi / 2)),
            T.concatenating(rotAbout(CGFloat.pi)),
            T.concatenating(rotAbout(CGFloat(3) * CGFloat.pi / 2))
        ]}
        var best = candidates.first!
        var bestErr = rmsGlobal(best)
        for cand in candidates.dropFirst() {
            let e = rmsGlobal(cand)
            if e < bestErr { bestErr = e; best = cand }
        }
        return best
    }

    private func fallbackTransform(for rect: CGRect) -> CGAffineTransform {
        // Map unit square directly into rect
        return CGAffineTransform(a: rect.width, b: 0, c: 0, d: rect.height, tx: rect.minX, ty: rect.minY)
    }

    private struct Stats {
        let centroid: CGPoint
        let extents: CGSize
        let angle: CGFloat      // principal axis angle in radians
    }

    private func stats(for pts: [CGPoint]) -> Stats? {
        guard pts.count >= 3 else { return nil }
        var cx: CGFloat = 0, cy: CGFloat = 0
        for p in pts { cx += p.x; cy += p.y }
        cx /= CGFloat(pts.count); cy /= CGFloat(pts.count)
        var sxx: CGFloat = 0, syy: CGFloat = 0, sxy: CGFloat = 0
        var minX = CGFloat.greatestFiniteMagnitude, maxX: CGFloat = -.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude, maxY: CGFloat = -.greatestFiniteMagnitude
        for p in pts {
            let dx = p.x - cx
            let dy = p.y - cy
            sxx += dx * dx
            syy += dy * dy
            sxy += dx * dy
            if p.x < minX { minX = p.x }; if p.x > maxX { maxX = p.x }
            if p.y < minY { minY = p.y }; if p.y > maxY { maxY = p.y }
        }
        // Principal angle from covariance (largest eigenvector)
        // For 2x2 cov [[sxx, sxy],[sxy, syy]] eigenvector angle:
        let two = CGFloat(2)
        let angle = 0.5 * atan2(two * sxy, sxx - syy)
        return Stats(centroid: CGPoint(x: cx, y: cy),
                     extents: CGSize(width: max(1e-6, maxX - minX), height: max(1e-6, maxY - minY)),
                     angle: angle)
    }

    private func collectPathPoints(from path: CGPath, maxPoints: Int) -> [CGPoint] {
        var points: [CGPoint] = []
        points.reserveCapacity(min(maxPoints, 1024))
        path.applyWithBlock { elemPtr in
            let e = elemPtr.pointee
            let tp = e.type
            // Append end points and control points; good enough for PCA
            switch tp {
            case .moveToPoint:
                points.append(e.points[0])
            case .addLineToPoint:
                points.append(e.points[0])
            case .addQuadCurveToPoint:
                points.append(e.points[0]) // control
                points.append(e.points[1]) // end
            case .addCurveToPoint:
                points.append(e.points[0]) // control1
                points.append(e.points[1]) // control2
                points.append(e.points[2]) // end
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }
        if points.count > maxPoints {
            // Downsample uniformly
            let step = max(1, points.count / maxPoints)
            var out: [CGPoint] = []
            out.reserveCapacity(maxPoints)
            for i in stride(from: 0, through: points.count - 1, by: step) {
                out.append(points[i])
                if out.count >= maxPoints { break }
            }
            return out
        }
        return points
    }

    private func samplePathByLength(_ path: CGPath, targetCount: Int) -> [CGPoint] {
        // Flatten path into polyline
        var pts: [CGPoint] = []
        path.applyWithBlock { ep in
            let e = ep.pointee
            switch e.type {
            case .moveToPoint:
                pts.append(e.points[0])
            case .addLineToPoint:
                pts.append(e.points[0])
            case .addQuadCurveToPoint:
                pts.append(e.points[1])
            case .addCurveToPoint:
                pts.append(e.points[2])
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }
        if pts.count < 2 { return pts }
        // Arc-length resample
        var lens: [CGFloat] = [0]
        lens.reserveCapacity(pts.count)
        for i in 1..<pts.count {
            lens.append(lens[i-1] + hypot(pts[i].x - pts[i-1].x, pts[i].y - pts[i-1].y))
        }
        let total = lens.last ?? 0
        let n = max(2, targetCount)
        var out: [CGPoint] = []
        out.reserveCapacity(n)
        for k in 0..<n {
            let d = (CGFloat(k) / CGFloat(n - 1)) * total
            // Find segment
            var i = 1
            while i < lens.count && lens[i] < d { i += 1 }
            if i >= lens.count { out.append(pts.last!) }
            else {
                let d0 = lens[i-1], d1 = lens[i]
                let t = (d1 > d0) ? (d - d0) / (d1 - d0) : 0
                let p0 = pts[i-1], p1 = pts[i]
                out.append(CGPoint(x: p0.x + (p1.x - p0.x) * t, y: p0.y + (p1.y - p0.y) * t))
            }
        }
        return out
    }

    private func wrapAngle(_ a: CGFloat) -> CGFloat {
        var x = a
        let pi = CGFloat.pi
        while x > pi { x -= 2 * pi }
        while x < -pi { x += 2 * pi }
        return x
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


#endif
