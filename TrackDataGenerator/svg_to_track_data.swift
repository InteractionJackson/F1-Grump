#!/usr/bin/env swift

import Foundation
import CoreGraphics

// Tool to convert existing SVG track outlines to proper track data
// This uses the real F1 circuit shapes from the assets folder

struct SVGToTrackData {
    static func convertAllSVGs() {
        print("🏁 Converting SVG track outlines to track data...")
        
        let svgDirectory = "../F1 Grump/assets/track outlines"
        let fileManager = FileManager.default
        
        guard let svgFiles = try? fileManager.contentsOfDirectory(atPath: svgDirectory) else {
            print("❌ Could not read SVG directory")
            return
        }
        
        var tracks: [TrackData] = []
        
        for filename in svgFiles.filter({ $0.hasSuffix(".svg") }) {
            let filePath = "\(svgDirectory)/\(filename)"
            let trackName = filename.replacingOccurrences(of: ".svg", with: "")
            
            if let trackData = convertSVGToTrackData(filePath: filePath, trackName: trackName) {
                tracks.append(trackData)
                print("✅ Converted \(trackName): \(trackData.points.count) points")
            } else {
                print("❌ Failed to convert \(trackName)")
            }
        }
        
        generateSwiftFile(tracks: tracks)
        print("🏆 Converted \(tracks.count) SVG tracks to track data!")
    }
    
    static func convertSVGToTrackData(filePath: String, trackName: String) -> TrackData? {
        guard let svgContent = try? String(contentsOfFile: filePath) else {
            return nil
        }
        
        // Extract path data from SVG
        guard let pathData = extractPathFromSVG(svgContent) else {
            return nil
        }
        
        // Parse SVG path commands to points
        let points = parseSVGPath(pathData)
        
        if points.isEmpty {
            return nil
        }
        
        // Normalize points to 0-1 range
        let normalizedPoints = normalizePoints(points)
        
        // Calculate bounds (estimated from normalized data)
        let bounds = estimateBounds(for: trackName)
        let aspectRatio = calculateAspectRatio(points: normalizedPoints)
        
        return TrackData(
            name: mapTrackName(trackName),
            points: normalizedPoints,
            bounds: bounds,
            aspectRatio: aspectRatio
        )
    }
    
    static func extractPathFromSVG(_ svgContent: String) -> String? {
        // Look for <path d="..." /> elements
        let pathPattern = #"<path[^>]*d\s*=\s*[\"']([^\"']+)[\"'][^>]*/?>"#
        
        guard let regex = try? NSRegularExpression(pattern: pathPattern, options: [.caseInsensitive]) else {
            return nil
        }
        
        let range = NSRange(svgContent.startIndex..<svgContent.endIndex, in: svgContent)
        let matches = regex.matches(in: svgContent, options: [], range: range)
        
        // Find the longest path (likely the main track outline)
        var longestPath = ""
        for match in matches {
            if match.numberOfRanges > 1 {
                let pathRange = Range(match.range(at: 1), in: svgContent)!
                let pathData = String(svgContent[pathRange])
                if pathData.count > longestPath.count {
                    longestPath = pathData
                }
            }
        }
        
        return longestPath.isEmpty ? nil : longestPath
    }
    
    static func parseSVGPath(_ pathData: String) -> [CGPoint] {
        var points: [CGPoint] = []
        var currentPoint = CGPoint.zero
        
        // Simple SVG path parser - handles M, L, C, Z commands
        let commands = pathData.replacingOccurrences(of: ",", with: " ")
                                .components(separatedBy: .whitespacesAndNewlines)
                                .filter { !$0.isEmpty }
        
        var i = 0
        while i < commands.count {
            let command = commands[i]
            
            switch command.uppercased() {
            case "M": // Move to
                if i + 2 < commands.count,
                   let x = Double(commands[i + 1]),
                   let y = Double(commands[i + 2]) {
                    currentPoint = CGPoint(x: x, y: y)
                    points.append(currentPoint)
                    i += 3
                } else {
                    i += 1
                }
                
            case "L": // Line to
                if i + 2 < commands.count,
                   let x = Double(commands[i + 1]),
                   let y = Double(commands[i + 2]) {
                    currentPoint = CGPoint(x: x, y: y)
                    points.append(currentPoint)
                    i += 3
                } else {
                    i += 1
                }
                
            case "C": // Cubic Bezier curve
                if i + 6 < commands.count,
                   let x1 = Double(commands[i + 1]),
                   let y1 = Double(commands[i + 2]),
                   let x2 = Double(commands[i + 3]),
                   let y2 = Double(commands[i + 4]),
                   let x = Double(commands[i + 5]),
                   let y = Double(commands[i + 6]) {
                    // Sample points along the curve
                    let startPoint = currentPoint
                    let control1 = CGPoint(x: x1, y: y1)
                    let control2 = CGPoint(x: x2, y: y2)
                    let endPoint = CGPoint(x: x, y: y)
                    
                    // Add intermediate points for smooth curves
                    for t in stride(from: 0.2, through: 1.0, by: 0.2) {
                        let point = bezierPoint(t: t, p0: startPoint, p1: control1, p2: control2, p3: endPoint)
                        points.append(point)
                    }
                    
                    currentPoint = endPoint
                    i += 7
                } else {
                    i += 1
                }
                
            case "Z": // Close path
                if !points.isEmpty {
                    points.append(points.first!)
                }
                i += 1
                
            default:
                // Try to parse as coordinates
                if let x = Double(command), i + 1 < commands.count, let y = Double(commands[i + 1]) {
                    currentPoint = CGPoint(x: x, y: y)
                    points.append(currentPoint)
                    i += 2
                } else {
                    i += 1
                }
            }
        }
        
        return points
    }
    
    static func bezierPoint(t: Double, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGPoint {
        let u = 1.0 - t
        let tt = t * t
        let uu = u * u
        let uuu = uu * u
        let ttt = tt * t
        
        let x = uuu * p0.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + ttt * p3.x
        let y = uuu * p0.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + ttt * p3.y
        
        return CGPoint(x: x, y: y)
    }
    
    static func normalizePoints(_ points: [CGPoint]) -> [CGPoint] {
        guard !points.isEmpty else { return [] }
        
        let minX = points.map { $0.x }.min() ?? 0
        let maxX = points.map { $0.x }.max() ?? 1
        let minY = points.map { $0.y }.min() ?? 0
        let maxY = points.map { $0.y }.max() ?? 1
        
        let width = maxX - minX
        let height = maxY - minY
        
        guard width > 0 && height > 0 else { return points }
        
        return points.map { point in
            CGPoint(
                x: (point.x - minX) / width,
                y: (point.y - minY) / height
            )
        }
    }
    
    static func calculateAspectRatio(points: [CGPoint]) -> Double {
        guard !points.isEmpty else { return 1.0 }
        
        let minX = points.map { $0.x }.min() ?? 0
        let maxX = points.map { $0.x }.max() ?? 1
        let minY = points.map { $0.y }.min() ?? 0
        let maxY = points.map { $0.y }.max() ?? 1
        
        let width = maxX - minX
        let height = maxY - minY
        
        return height > 0 ? Double(width / height) : 1.0
    }
    
    static func mapTrackName(_ filename: String) -> String {
        // Map SVG filenames to TrackMap names
        let mappings: [String: String] = [
            "Albert Park": "Melbourne",
            "Bahrain": "Bahrain",
            "Baku City": "Baku",
            "Barcelona-Catalunya": "Barcelona",
            "Circuit of the Americas": "COTA",
            "Gilles Villeneuve": "Montreal",
            "Hungaroring": "Hungaroring",
            "Imola": "Imola",
            "Interlagos": "Interlagos",
            "Jeddah Corniche": "Jeddah",
            "Jeddah": "Jeddah_Alt", // Avoid duplicate - use alternate name
            "Las Vegas": "Las Vegas",
            "Lusail": "Qatar",
            "Marina Bay": "Singapore",
            "Mexico": "Mexico",
            "Miami": "Miami",
            "Monaco": "Monaco",
            "Monza": "Monza",
            "Red Bull Ring": "Red Bull Ring",
            "Shanghai": "Shanghai",
            "Silverstone": "Silverstone",
            "Spa-Francorchamps": "Spa",
            "Suzuka": "Suzuka",
            "Yas Marina": "Yas Marina",
            "Zandvoort": "Zandvoort"
        ]
        
        return mappings[filename] ?? filename
    }
    
    static func estimateBounds(for trackName: String) -> (Float, Float, Float, Float) {
        // Estimated realistic bounds for each track (from research/experience)
        let bounds: [String: (Float, Float, Float, Float)] = [
            "Bahrain": (-1200, 800, -600, 1000),
            "Melbourne": (-800, 1200, -1000, 600),
            "Shanghai": (-900, 1100, -800, 1200),
            "Barcelona": (-700, 1300, -600, 1400),
            "Monaco": (-400, 600, -500, 500),
            "Montreal": (-600, 1400, -500, 1500),
            "Silverstone": (-800, 1200, -1000, 600),
            "Hungaroring": (-500, 1500, -400, 1600),
            "Spa": (-1000, 1000, -1200, 800),
            "Monza": (-600, 1400, -800, 1200),
            "Singapore": (-800, 1200, -700, 1300),
            "Suzuka": (-900, 1100, -800, 1200),
            "Yas Marina": (-1100, 900, -900, 1100),
            "COTA": (-1000, 1000, -1100, 900),
            "Interlagos": (-700, 1300, -600, 1400),
            "Red Bull Ring": (-600, 1400, -500, 1500),
            "Mexico": (-800, 1200, -700, 1300),
            "Baku": (-1200, 800, -600, 1400),
            "Zandvoort": (-500, 1500, -400, 1600),
            "Imola": (-600, 1400, -500, 1500),
            "Jeddah": (-1000, 1000, -800, 1200),
            "Miami": (-900, 1100, -700, 1300),
            "Las Vegas": (-1400, 600, -800, 1200),
            "Qatar": (-800, 1200, -600, 1400)
        ]
        
        return bounds[trackName] ?? (-1000, 1000, -1000, 1000)
    }
    
    static func generateSwiftFile(tracks: [TrackData]) {
        var swiftCode = """
        import Foundation
        import CoreGraphics

        // F1 track data generated from real SVG circuit outlines
        // Converted from /F1 Grump/assets/track outlines/
        // Generated on \(Date())

        struct PrebuiltTrackOutline: Codable {
            let name: String
            let points: [CGPoint]
            let bounds: PrebuiltTrackBounds
            let aspectRatio: Double
            let generatedAt: Date
        }

        struct PrebuiltTrackBounds: Codable {
            let minX: Float
            let maxX: Float
            let minZ: Float
            let maxZ: Float
        }

        struct PrebuiltTrackData {
            static let tracks: [String: PrebuiltTrackOutline] = [
        """
        
        for track in tracks.sorted(by: { $0.name < $1.name }) {
            swiftCode += """
            
                "\(track.name)": PrebuiltTrackOutline(
                    name: "\(track.name)",
                    points: [
            """
            
            for point in track.points {
                swiftCode += "\n                CGPoint(x: \(point.x), y: \(point.y)),"
            }
            
            swiftCode += """
            
                    ],
                    bounds: PrebuiltTrackBounds(
                        minX: \(track.bounds.0),
                        maxX: \(track.bounds.1),
                        minZ: \(track.bounds.2),
                        maxZ: \(track.bounds.3)
                    ),
                    aspectRatio: \(track.aspectRatio),
                    generatedAt: Date()
                ),
            """
        }
        
        swiftCode += """
        
            ]
            
            static func getTrack(name: String) -> PrebuiltTrackOutline? {
                return tracks[name]
            }
            
            static func hasTrack(name: String) -> Bool {
                return tracks[name] != nil
            }
            
            static var availableTrackNames: [String] {
                return Array(tracks.keys).sorted()
            }
            
            static var trackCount: Int {
                return tracks.count
            }
        }
        """
        
        let outputPath = "../F1 Grump/Sources/PrebuiltTrackData.swift"
        
        do {
            try swiftCode.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print("📝 Generated Swift file: \(outputPath)")
            print("🏆 Tracks converted:")
            for track in tracks.sorted(by: { $0.name < $1.name }) {
                print("   ✅ \(track.name): \(track.points.count) points")
            }
        } catch {
            print("❌ Failed to write file: \(error)")
        }
    }
}

struct TrackData {
    let name: String
    let points: [CGPoint]
    let bounds: (Float, Float, Float, Float)
    let aspectRatio: Double
}

// Convert all SVG tracks!
SVGToTrackData.convertAllSVGs()
