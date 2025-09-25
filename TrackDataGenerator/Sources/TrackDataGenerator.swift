import Foundation
import Network
import ArgumentParser

@main
struct TrackDataGenerator: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "track-generator",
        abstract: "Generate F1 track outlines from telemetry data",
        discussion: """
        This tool collects F1 telemetry data and generates clean track outlines
        for all F1 circuits. The generated data can be embedded into the F1 Grump app.
        
        Usage:
        1. Start F1 24 with UDP telemetry enabled (port 20777)
        2. Run this tool: swift run TrackDataGenerator --collect
        3. Drive clean laps on each track you want to capture
        4. Generated track data will be saved to TrackData/
        """
    )
    
    @Flag(help: "Collect telemetry data from F1 game")
    var collect = false
    
    @Flag(help: "Generate track outlines from collected data")
    var generate = false
    
    @Flag(help: "Export track data for embedding in app")
    var export = false
    
    @Option(help: "UDP port to listen on")
    var port: Int = 20777
    
    @Option(help: "Output directory for track data")
    var output: String = "TrackData"
    
    func run() async throws {
        print("🏁 F1 Track Data Generator")
        print("========================")
        
        if collect {
            await collectTelemetryData()
        }
        
        if generate {
            try generateTrackOutlines()
        }
        
        if export {
            try exportForApp()
        }
        
        if !collect && !generate && !export {
            print("Please specify --collect, --generate, or --export")
            print("Use --help for more information")
        }
    }
    
    func collectTelemetryData() async {
        print("\n📡 Starting telemetry collection on port \(port)")
        print("Instructions:")
        print("1. Start F1 24 with UDP telemetry enabled")
        print("2. Go to each track and drive 2-3 clean laps")
        print("3. Press Ctrl+C when done")
        
        let collector = TelemetryCollector(port: port, outputDir: output)
        await collector.start()
    }
    
    func generateTrackOutlines() throws {
        print("\n🎨 Generating track outlines from collected data")
        
        let generator = TrackOutlineGenerator(dataDir: output)
        try generator.generateAll()
        
        print("✅ Track outlines generated successfully")
    }
    
    func exportForApp() throws {
        print("\n📦 Exporting track data for F1 Grump app")
        
        let exporter = AppDataExporter(dataDir: output)
        try exporter.export()
        
        print("✅ Track data exported for app embedding")
    }
}

// MARK: - Telemetry Collector

class TelemetryCollector {
    private let port: Int
    private let outputDir: String
    private var listener: NWListener?
    private var isRunning = false
    private var trackData: [String: [TrackPoint]] = [:]
    private var currentTrack = ""
    
    init(port: Int, outputDir: String) {
        self.port = port
        self.outputDir = outputDir
        
        // Create output directory
        try? FileManager.default.createDirectory(
            atPath: outputDir,
            withIntermediateDirectories: true
        )
    }
    
    func start() async {
        do {
            let params = NWParameters.udp
            listener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: UInt16(port)))
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .global())
            isRunning = true
            
            print("🎯 Listening for F1 telemetry on port \(port)...")
            
            // Keep running until interrupted
            while isRunning {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
            
        } catch {
            print("❌ Failed to start listener: \(error)")
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: .global())
        
        func receiveData() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 2048) { [weak self] data, _, isComplete, error in
                
                if let data = data, !data.isEmpty {
                    self?.processTelemetryPacket(data)
                }
                
                if !isComplete {
                    receiveData() // Continue receiving
                }
            }
        }
        
        receiveData()
    }
    
    private func processTelemetryPacket(_ data: Data) {
        guard data.count >= 24 else { return } // Minimum header size
        
        let packetFormat = data.readU8(offset: 0)
        let packetVersion = data.readU8(offset: 1)
        let packetId = data.readU8(offset: 2)
        
        // Parse based on packet type
        switch packetId {
        case 1: parseSessionPacket(data)
        case 6: parseMotionPacket(data)
        default: break
        }
    }
    
    private func parseSessionPacket(_ data: Data) {
        // Extract track ID (similar to your existing code)
        let headerSize = 24
        guard data.count > headerSize + 10 else { return }
        
        let candidates: [Int] = [7, 8, 9, 10]
        var trackId: Int8 = -127
        
        for offset in candidates {
            let value = Int8(bitPattern: data.readU8(offset: headerSize + offset))
            if value >= -1 && value <= 42 {
                trackId = value
                break
            }
        }
        
        let trackName = getTrackName(for: Int(trackId))
        if !trackName.isEmpty && trackName != currentTrack {
            currentTrack = trackName
            print("🏎️  Switched to track: \(trackName) (ID: \(trackId))")
            
            // Initialize track data if needed
            if trackData[trackName] == nil {
                trackData[trackName] = []
            }
        }
    }
    
    private func parseMotionPacket(_ data: Data) {
        guard !currentTrack.isEmpty else { return }
        
        let headerSize = 24
        guard data.count >= headerSize + (22 * 60) else { return } // 22 cars * 60 bytes per car
        
        // Parse all car positions
        for carIndex in 0..<22 {
            let offset = headerSize + (carIndex * 60)
            
            let worldX = data.readFloat(offset: offset + 0)
            let worldY = data.readFloat(offset: offset + 4)
            let worldZ = data.readFloat(offset: offset + 8)
            
            // Only collect valid positions
            if abs(worldX) < 10000 && abs(worldZ) < 10000 {
                let point = TrackPoint(
                    x: worldX,
                    z: worldZ,
                    timestamp: Date(),
                    carIndex: carIndex
                )
                
                trackData[currentTrack]?.append(point)
            }
        }
        
        // Print progress
        let totalPoints = trackData[currentTrack]?.count ?? 0
        if totalPoints % 1000 == 0 && totalPoints > 0 {
            print("📊 \(currentTrack): \(totalPoints) points collected")
        }
        
        // Auto-save periodically
        if totalPoints % 5000 == 0 && totalPoints > 0 {
            saveTrackData(trackName: currentTrack)
        }
    }
    
    private func saveTrackData(trackName: String) {
        guard let points = trackData[trackName], !points.isEmpty else { return }
        
        let filename = "\(outputDir)/\(trackName.replacingOccurrences(of: " ", with: "_"))_raw.json"
        
        do {
            let jsonData = try JSONEncoder().encode(points)
            try jsonData.write(to: URL(fileURLWithPath: filename))
            print("💾 Saved \(points.count) points for \(trackName)")
        } catch {
            print("❌ Failed to save \(trackName): \(error)")
        }
    }
    
    private func getTrackName(for id: Int) -> String {
        // Copy of your TrackMap logic
        switch id {
        case 0: return "Melbourne"
        case 1: return "Paul Ricard"
        case 2: return "Shanghai"
        case 3: return "Bahrain"
        case 4: return "Barcelona"
        case 5: return "Monaco"
        case 6: return "Montreal"
        case 7: return "Silverstone"
        case 8: return "Hockenheim"
        case 9: return "Hungaroring"
        case 10: return "Spa"
        case 11: return "Monza"
        case 12: return "Singapore"
        case 13: return "Suzuka"
        case 14: return "Yas Marina"
        case 15: return "COTA"
        case 16: return "Interlagos"
        case 17: return "Red Bull Ring"
        case 18: return "Sochi"
        case 19: return "Mexico"
        case 20: return "Baku"
        case 21: return "Sakhir Short"
        case 22: return "Silverstone Short"
        case 23: return "COTA Short"
        case 24: return "Suzuka Short"
        case 25: return "Monza Short"
        case 26: return "Hanoi"
        case 27: return "Zandvoort"
        case 28: return "Imola"
        case 29: return "Portimao"
        case 30: return "Jeddah"
        case 31: return "Miami"
        case 32: return "Las Vegas"
        case 33: return "Qatar"
        default: return ""
        }
    }
}

// MARK: - Data Structures

struct TrackPoint: Codable {
    let x: Float
    let z: Float
    let timestamp: Date
    let carIndex: Int
}

struct TrackOutline: Codable {
    let name: String
    let points: [CGPoint]
    let bounds: TrackBounds
    let aspectRatio: Double
    let generatedAt: Date
}

struct TrackBounds: Codable {
    let minX: Float
    let maxX: Float
    let minZ: Float
    let maxZ: Float
}

// MARK: - Track Outline Generator

class TrackOutlineGenerator {
    private let dataDir: String
    
    init(dataDir: String) {
        self.dataDir = dataDir
    }
    
    func generateAll() throws {
        let fileManager = FileManager.default
        let dataURL = URL(fileURLWithPath: dataDir)
        
        let rawFiles = try fileManager.contentsOfDirectory(at: dataURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" && $0.lastPathComponent.contains("_raw") }
        
        for file in rawFiles {
            try generateOutline(from: file)
        }
    }
    
    private func generateOutline(from file: URL) throws {
        print("🎨 Processing \(file.lastPathComponent)...")
        
        let data = try Data(contentsOf: file)
        let points = try JSONDecoder().decode([TrackPoint], data: data)
        
        guard !points.isEmpty else {
            print("⚠️  No points found in \(file.lastPathComponent)")
            return
        }
        
        // Extract track name from filename
        let filename = file.deletingPathExtension().lastPathComponent
        let trackName = filename.replacingOccurrences(of: "_raw", with: "").replacingOccurrences(of: "_", with: " ")
        
        // Generate clean outline
        let outline = generateCleanOutline(from: points, trackName: trackName)
        
        // Save processed outline
        let outputFile = file.deletingLastPathComponent()
            .appendingPathComponent("\(trackName.replacingOccurrences(of: " ", with: "_"))_outline.json")
        
        let outlineData = try JSONEncoder().encode(outline)
        try outlineData.write(to: outputFile)
        
        print("✅ Generated outline for \(trackName): \(outline.points.count) points")
    }
    
    private func generateCleanOutline(from rawPoints: [TrackPoint], trackName: String) -> TrackOutline {
        // Calculate bounds
        let minX = rawPoints.map { $0.x }.min() ?? 0
        let maxX = rawPoints.map { $0.x }.max() ?? 1
        let minZ = rawPoints.map { $0.z }.min() ?? 0
        let maxZ = rawPoints.map { $0.z }.max() ?? 1
        
        let bounds = TrackBounds(minX: minX, maxX: maxX, minZ: minZ, maxZ: maxZ)
        let aspectRatio = Double(maxX - minX) / Double(maxZ - minZ)
        
        // Convert to normalized CGPoints
        let normalizedPoints = rawPoints.map { point in
            CGPoint(
                x: CGFloat((point.x - minX) / (maxX - minX)),
                y: CGFloat((point.z - minZ) / (maxZ - minZ))
            )
        }
        
        // Generate clean outline using your existing algorithm
        let cleanOutline = generateTrackOutline(from: normalizedPoints)
        
        return TrackOutline(
            name: trackName,
            points: cleanOutline,
            bounds: bounds,
            aspectRatio: aspectRatio,
            generatedAt: Date()
        )
    }
    
    private func generateTrackOutline(from points: [CGPoint]) -> [CGPoint] {
        guard points.count > 10 else { return [] }
        
        // Remove outliers
        let cleanedPoints = removeOutliers(from: points)
        
        // Sample points
        let targetOutlinePoints = 80
        let samplingStep = max(1, cleanedPoints.count / targetOutlinePoints)
        
        var sampledPoints: [CGPoint] = []
        for i in stride(from: 0, to: cleanedPoints.count, by: samplingStep) {
            sampledPoints.append(cleanedPoints[i])
        }
        
        // Sort by angle from center
        let centerX = sampledPoints.map { $0.x }.reduce(0, +) / CGFloat(sampledPoints.count)
        let centerY = sampledPoints.map { $0.y }.reduce(0, +) / CGFloat(sampledPoints.count)
        let center = CGPoint(x: centerX, y: centerY)
        
        let sortedPoints = sampledPoints.sorted { point1, point2 in
            let angle1 = atan2(point1.y - center.y, point1.x - center.x)
            let angle2 = atan2(point2.y - center.y, point2.x - center.x)
            return angle1 < angle2
        }
        
        // Close the loop
        var outline = sortedPoints
        if !outline.isEmpty {
            outline.append(outline.first!)
        }
        
        return outline
    }
    
    private func removeOutliers(from points: [CGPoint]) -> [CGPoint] {
        guard points.count > 20 else { return points }
        
        let centerX = points.map { $0.x }.reduce(0, +) / CGFloat(points.count)
        let centerY = points.map { $0.y }.reduce(0, +) / CGFloat(points.count)
        let center = CGPoint(x: centerX, y: centerY)
        
        let distances = points.map { distance(from: $0, to: center) }
        let avgDistance = distances.reduce(0, +) / CGFloat(distances.count)
        
        let variance = distances.map { pow($0 - avgDistance, 2) }.reduce(0, +) / CGFloat(distances.count)
        let stdDev = sqrt(variance)
        let maxDistance = avgDistance + (stdDev * 2.5)
        
        return points.filter { distance(from: $0, to: center) <= maxDistance }
    }
    
    private func distance(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        return sqrt(dx*dx + dy*dy)
    }
}

// MARK: - App Data Exporter

class AppDataExporter {
    private let dataDir: String
    
    init(dataDir: String) {
        self.dataDir = dataDir
    }
    
    func export() throws {
        print("📦 Exporting track data for F1 Grump app...")
        
        let fileManager = FileManager.default
        let dataURL = URL(fileURLWithPath: dataDir)
        
        let outlineFiles = try fileManager.contentsOfDirectory(at: dataURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" && $0.lastPathComponent.contains("_outline") }
        
        var allTracks: [String: TrackOutline] = [:]
        
        for file in outlineFiles {
            let data = try Data(contentsOf: file)
            let outline = try JSONDecoder().decode(TrackOutline, data: data)
            allTracks[outline.name] = outline
        }
        
        // Generate Swift file for embedding
        try generateSwiftFile(tracks: allTracks)
        
        // Generate JSON file for runtime loading
        try generateJSONFile(tracks: allTracks)
        
        print("✅ Exported \(allTracks.count) tracks")
    }
    
    private func generateSwiftFile(tracks: [String: TrackOutline]) throws {
        var swiftCode = """
        import Foundation
        import CoreGraphics

        // Auto-generated F1 track data
        // Generated on \(Date())

        struct PrebuiltTrackData {
            static let tracks: [String: TrackOutline] = [
        """
        
        for (name, outline) in tracks.sorted(by: { $0.key < $1.key }) {
            swiftCode += """
            
                "\(name)": TrackOutline(
                    name: "\(outline.name)",
                    points: [
            """
            
            for point in outline.points {
                swiftCode += "\n                CGPoint(x: \(point.x), y: \(point.y)),"
            }
            
            swiftCode += """
            
                    ],
                    bounds: TrackBounds(
                        minX: \(outline.bounds.minX),
                        maxX: \(outline.bounds.maxX),
                        minZ: \(outline.bounds.minZ),
                        maxZ: \(outline.bounds.maxZ)
                    ),
                    aspectRatio: \(outline.aspectRatio),
                    generatedAt: Date()
                ),
            """
        }
        
        swiftCode += """
        
            ]
        }
        """
        
        let outputFile = "../F1 Grump/Sources/PrebuiltTrackData.swift"
        try swiftCode.write(to: URL(fileURLWithPath: outputFile), atomically: true, encoding: .utf8)
        
        print("📝 Generated Swift file: \(outputFile)")
    }
    
    private func generateJSONFile(tracks: [String: TrackOutline]) throws {
        let jsonData = try JSONEncoder().encode(tracks)
        let outputFile = "\(dataDir)/all_tracks.json"
        try jsonData.write(to: URL(fileURLWithPath: outputFile))
        
        print("📄 Generated JSON file: \(outputFile)")
    }
}

// MARK: - Data Extensions

extension Data {
    func readU8(offset: Int) -> UInt8 {
        guard offset < count else { return 0 }
        return self[offset]
    }
    
    func readFloat(offset: Int) -> Float {
        guard offset + 4 <= count else { return 0 }
        return withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: Float.self)
        }
    }
}
