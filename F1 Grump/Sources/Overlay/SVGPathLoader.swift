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
    private var rawCache: [String: (path: CGPath, viewBox: CGRect)] = [:]
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

    // Load raw SVG path in its native viewBox coordinates (no projection). Cached by asset name.
    public func loadViewBox(assetName: String) -> (path: CGPath, viewBox: CGRect)? {
        lock.lock(); defer { lock.unlock() }
        if let r = rawCache[assetName] { return r }
        
        // Map TrackMap.name() outputs to actual SVG file names
        let trackMappings: [String: String] = [
            // Direct matches
            "Silverstone": "Silverstone",
            "Bahrain": "Bahrain", 
            "Imola": "Imola",
            "Miami": "Miami",
            "Monaco": "Monaco",
            "Hungaroring": "Hungaroring",
            "Monza": "Monza",
            "Suzuka": "Suzuka",
            "Mexico": "Mexico",
            "Interlagos": "Interlagos",
            "Las Vegas": "Las Vegas",
            "Shanghai": "Shanghai",
            "Zandvoort": "Zandvoort",
            // TrackMap.name() -> SVG file name mappings
            "Melbourne": "Albert Park",        // Australia
            "Barcelona": "Barcelona-Catalunya", // Spain
            "Baku": "Baku City",              // Azerbaijan  
            "Montreal": "Gilles Villeneuve",   // Canada
            "Red Bull Ring": "Red Bull Ring",  // Austria
            "Spa": "Spa-Francorchamps",       // Belgium
            "Singapore": "Marina Bay",         // Marina Bay
            "COTA": "Circuit of the Americas", // USA Austin
            "Yas Marina": "Yas Marina",        // Abu Dhabi
            "Jeddah": "Jeddah Corniche",       // Saudi Arabia
            "Qatar": "Lusail"                  // Qatar
        ]
        
        let actualFileName = trackMappings[assetName] ?? assetName
        
        #if DEBUG
        print("SVGPathLoader: Looking for '\(assetName)' -> '\(actualFileName)'")
        #endif
        
        // Try NSDataAsset with different path formats
        let assetPaths = [
            "track outlines/\(actualFileName)",
            "track_outlines_\(actualFileName)",
            actualFileName
        ]
        
        for assetPath in assetPaths {
            #if DEBUG
            print("SVGPathLoader: Trying NSDataAsset path: '\(assetPath)'")
            #endif
            if let asset = NSDataAsset(name: assetPath),
               let svgString = String(data: asset.data, encoding: .utf8) {
                #if DEBUG
                print("SVGPathLoader: Found NSDataAsset at '\(assetPath)', data size: \(asset.data.count)")
                #endif
                let paths = SVGBezierPath.paths(fromSVGString: svgString)
                if !paths.isEmpty {
                    let combined = CGMutablePath()
                    var viewBox = CGRect.null
                    for p in paths { combined.addPath(p.cgPath); viewBox = viewBox.union(p.cgPath.boundingBoxOfPath) }
                    let r = (combined.copy()!, viewBox)
                    rawCache[assetName] = r
                    #if DEBUG
                    print("SVGPathLoader: Loaded '\(assetName)' from asset catalog at '\(assetPath)', viewBox: \(viewBox)")
                    #endif
                    return r
                } else {
                    #if DEBUG
                    print("SVGPathLoader: NSDataAsset '\(assetPath)' found but no SVG paths parsed")
                    #endif
                }
            }
        }
        
        // Try bundle file lookup with various name patterns and subdirectories
        let candidateNames = [actualFileName, assetName]
        let subdirectories = [
            "Assets.xcassets/track outlines",
            "assets/track outlines", 
            "F1 Grump/Assets.xcassets/track outlines",
            nil // root bundle
        ]
        
        #if DEBUG
        print("SVGPathLoader: Trying bundle file lookup for candidates: \(candidateNames)")
        #endif
        
        for subdir in subdirectories {
            for candidate in candidateNames {
                #if DEBUG
                print("SVGPathLoader: Trying bundle path: '\(subdir ?? "root")/\(candidate).svg'")
                #endif
                if let url = Bundle.main.url(forResource: candidate, withExtension: "svg", subdirectory: subdir) {
                    #if DEBUG
                    print("SVGPathLoader: Found bundle file at '\(url.path)'")
                    #endif
                    let paths = SVGBezierPath.pathsFromSVG(at: url)
                    if !paths.isEmpty {
                        let combined = CGMutablePath()
                        var viewBox = CGRect.null
                        for p in paths { combined.addPath(p.cgPath); viewBox = viewBox.union(p.cgPath.boundingBoxOfPath) }
                        let r = (combined.copy()!, viewBox)
                        rawCache[assetName] = r
                        #if DEBUG
                        print("SVGPathLoader: Loaded '\(assetName)' from bundle as '\(candidate)' in '\(subdir ?? "root")', viewBox: \(viewBox)")
                        #endif
                        return r
                    } else {
                        #if DEBUG
                        print("SVGPathLoader: Bundle file '\(candidate).svg' found but no SVG paths parsed")
                        #endif
                    }
                }
            }
        }
        
        // Last resort: try direct file system access (development/debug only)
        #if DEBUG
        let directPaths = [
            "/Users/mattjackson/Documents/F1 Grump/F1 Grump/Assets.xcassets/track outlines/\(actualFileName).svg",
            "/Users/mattjackson/Documents/F1 Grump/assets/track outlines/\(actualFileName).svg"
        ]
        
        for directPath in directPaths {
            print("SVGPathLoader: Trying direct path: '\(directPath)'")
            let fileExists = FileManager.default.fileExists(atPath: directPath)
            print("SVGPathLoader: File exists check: \(fileExists)")
            
            if fileExists {
                do {
                    let svgString = try String(contentsOfFile: directPath, encoding: .utf8)
                    print("SVGPathLoader: Successfully read file, size: \(svgString.count)")
                    let paths = SVGBezierPath.paths(fromSVGString: svgString)
                    print("SVGPathLoader: Parsed \(paths.count) SVG paths")
                    if !paths.isEmpty {
                        let combined = CGMutablePath()
                        var viewBox = CGRect.null
                        for p in paths { combined.addPath(p.cgPath); viewBox = viewBox.union(p.cgPath.boundingBoxOfPath) }
                        let r = (combined.copy()!, viewBox)
                        rawCache[assetName] = r
                        print("SVGPathLoader: Loaded '\(assetName)' from direct file '\(directPath)', viewBox: \(viewBox)")
                        return r
                    } else {
                        print("SVGPathLoader: Direct file '\(directPath)' found but no SVG paths parsed")
                    }
                } catch {
                    print("SVGPathLoader: Error reading file '\(directPath)': \(error)")
                }
            }
        }
        #endif
        
        #if DEBUG
        print("SVGPathLoader: Failed to load SVG asset '\(assetName)' (tried: \(candidateNames))")
        #endif
        return nil
    }
}


