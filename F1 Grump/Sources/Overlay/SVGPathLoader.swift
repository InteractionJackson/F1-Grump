// README: SVGPathLoader
// Loads a track SVG from bundle subdirectory "assets/track outlines" and produces:
// - combined CGPath in Mercator meters (projected from the SVG viewBox into the config bbox)
// - viewBox size and mercator bounds (for transforms)
// Uses PocketSVG for path extraction and caches results in-memory.

import Foundation
import CoreGraphics
import PocketSVG

public final class SVGPathLoader {
    public static let shared = SVGPathLoader()
    private init() {}

    public struct Result {
        public let mercatorPath: CGPath
        public let mercatorBounds: CGRect
        public let viewBox: CGRect
    }

    private var cache: [String: Result] = [:] // key: cacheKey(assetName+bbox)
    private let lock = NSLock()

    public func load(assetName: String, bbox: TrackOverlayConfig.BBox) -> Result? {
        let key = "\(assetName)|\(bbox.west)|\(bbox.south)|\(bbox.east)|\(bbox.north)"
        lock.lock(); defer { lock.unlock() }
        if let cached = cache[key] { return cached }

        guard let url = Bundle.main.url(forResource: assetName, withExtension: "svg", subdirectory: "assets/track outlines") else {
            return nil
        }
        let paths = SVGBezierPath.pathsFromSVG(at: url)
        guard !paths.isEmpty else { return nil }

        // Merge into one path in SVG viewBox space
        let combined = CGMutablePath()
        var viewBox = CGRect.null
        for p in paths {
            combined.addPath(p.cgPath)
            viewBox = viewBox.union(p.cgPath.boundingBoxOfPath)
        }
        guard viewBox.isNull == false else { return nil }

        // Project SVG points into Mercator meters using bbox (linear in lon/lats across viewBox)
        let sx = viewBox.minX, sy = viewBox.minY
        let sw = viewBox.width, sh = viewBox.height

        func svgToMercator(_ pt: CGPoint) -> CGPoint {
            let u = (Double(pt.x - sx) / Double(sw))
            let v = (Double(pt.y - sy) / Double(sh))
            // SVG y-down -> north at v=0
            let lon = bbox.west + u * (bbox.east - bbox.west)
            let lat = bbox.north - v * (bbox.north - bbox.south)
            let m = WebMercator.lonLatToMeters(lon: lon, lat: lat)
            return CGPoint(x: m.x, y: m.y)
        }

        // Flatten to polyline by sampling path with current transform identity
        // We'll walk each element and transform endpoints to mercator
        let mercator = CGMutablePath()
        combined.applyWithBlock { elemPtr in
            let e = elemPtr.pointee
            switch e.type {
            case .moveToPoint:
                mercator.move(to: svgToMercator(e.points[0]))
            case .addLineToPoint:
                mercator.addLine(to: svgToMercator(e.points[0]))
            case .addQuadCurveToPoint:
                mercator.addLine(to: svgToMercator(e.points[1]))
            case .addCurveToPoint:
                mercator.addLine(to: svgToMercator(e.points[2]))
            case .closeSubpath:
                mercator.closeSubpath()
            @unknown default:
                break
            }
        }

        let bounds = mercator.boundingBoxOfPath
        let result = Result(mercatorPath: mercator.copy()!, mercatorBounds: bounds, viewBox: viewBox)
        cache[key] = result
        return result
    }
}


