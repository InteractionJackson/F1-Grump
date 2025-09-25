import Foundation
import Network
import Combine
import CoreGraphics
import QuartzCore

final class TelemetryReceiver: ObservableObject {
    
    @Published var lapNumber = 0
    @Published var currentLapMS = 0
    @Published var lastLapMS = 0
    @Published var bestLapMS = 0
    @Published var sectorMS: [Int] = [0,0,0]
    @Published var lastSectorMS: [Int] = [0,0,0]
    
    @Published var tyreWearPercents: [Int]? // [FL, FR, RL, RR], 0–100
    @Published var trackDots: [CGPoint] = []      // other cars (world space)
    @Published var playerWorldPoint: CGPoint = .zero
    
    // UI-facing values
    @Published var packetCount: Int = 0
    @Published var speedKmh: Double = 0
    @Published var gear: Int = 0
    @Published var rpm: Double = 0
    @Published var rpmRedline: Double = 12000
    @Published var throttle: Float = 0
    @Published var brake: Double = 0
    @Published var drsActive: Bool = false
    @Published var drsOpen: Bool = false  // ← used by SpeedRpmTile
    @Published var ersPercent: Double = 0   // 0…1 of ERS store
    @Published var bestSectorMS: [Int] = [0, 0, 0]
    @Published var overallBestSectorMS: [Int] = [0, 0, 0]   // across all cars
    @Published var fuelPercent: Double = 1.0                 // 0…1 fuel remaining (placeholder until parsed)

    // Tyres & laps
    @Published var tyreInnerTemps: [Int] = [0,0,0,0]   // FL, FR, RL, RR
    @Published var tyreWear: [Int] = [0,0,0,0]
    @Published var currentLapTime: TimeInterval = 0
    @Published var lastLapTime: TimeInterval = 0
    @Published var bestLapTime: TimeInterval = 0
    @Published var sectorTimes: [TimeInterval] = [0,0,0]
    @Published var brakeTemps: [Int] = [0,0,0,0]
    @Published var overlayDamage: [String: CGFloat] = [:]   // keys: fl_tyre, fr_tyre, rl_tyre, rr_tyre, front_wing_left, front_wing_right, rear_wing

    // Track map - simplified for SVG-based approach
    @Published var recentPositions: [CGPoint] = []
    @Published var carPoints: [CGPoint] = []
    @Published var playerCarIndex: Int = 0
    @Published var trackName: String = ""
    @Published var worldAspect: CGFloat = 1.0
    @Published var teamIds: [UInt8] = []
    @Published var driverOrderItems: [DriverOrderItem] = []

    // Coordinate bounds for normalization
    private var minX: Float = .greatestFiniteMagnitude
    private var maxX: Float = -.greatestFiniteMagnitude
    private var minZ: Float = .greatestFiniteMagnitude
    private var maxZ: Float = -.greatestFiniteMagnitude
    private var boundsFrozen: Bool = false
    private var frozenMinX: Float = 0
    private var frozenMaxX: Float = 1
    private var frozenMinZ: Float = 0
    private var frozenMaxZ: Float = 1
    private var motionFramesObserved: Int = 0

    // ERS tracking
    private var ersEMA: Double = 0
    private var ersInitialized = false
    private let ersAlpha: Double = 0.05

    // Networking
    private var listener: NWListener?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "telemetry", qos: .userInitiated)

    // MARK: - Initialization
    init() {
        // Clean initialization - no track loading needed with SVG approach
    }

    // MARK: - Start/Stop
    func startListening(port: UInt16 = 20777) {
        guard listener == nil else { return }
        
        do {
            let params = NWParameters.udp
            params.allowLocalEndpointReuse = true
            params.allowFastOpen = true
            
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        print("TelemetryReceiver: Ready, listening on port \(port)")
                    case .failed(let error):
                        print("TelemetryReceiver: Failed with error: \(error)")
                        self?.listener = nil
                        // Retry after a short delay
                        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                            self?.startListening(port: port)
                        }
                    case .cancelled:
                        print("TelemetryReceiver: Cancelled")
                        self?.listener = nil
                    default:
                        break
                    }
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            
            listener?.start(queue: queue)
            
        } catch {
            print("TelemetryReceiver: Failed to start listener: \(error)")
        }
    }
    
    func stopListening() {
        listener?.cancel()
        listener = nil
        connection?.cancel()
        connection = nil
        print("TelemetryReceiver: Stopped listening")
    }
    
    private func handleNewConnection(_ newConnection: NWConnection) {
        connection?.cancel()
        connection = newConnection
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                #if DEBUG
                print("TelemetryReceiver: UDP connection ready")
                #endif
                self?.receiveData()
            case .failed(let error):
                print("TelemetryReceiver: Connection failed: \(error)")
                // For UDP, connection failures are common - just restart receiving
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                    self?.receiveData()
                }
            case .cancelled:
                #if DEBUG
                print("TelemetryReceiver: Connection cancelled")
                #endif
            default:
                break
            }
        }
        
        connection?.start(queue: queue)
    }
    
    private func receiveData() {
        guard let connection = connection else { return }
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 2048) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.processPacket(data)
            }
            
            if let error = error {
                print("TelemetryReceiver: Receive error: \(error)")
                // For UDP, errors are common - just keep trying
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    self?.receiveData()
                }
                return
            }
            
            // Continue receiving (UDP is connectionless, so we keep receiving)
            self?.receiveData()
        }
    }

    // MARK: - Demux
    private func processPacket(_ data: Data) {
        guard data.count >= 24 else { 
            #if DEBUG
            print("TelemetryReceiver: Packet too small (\(data.count) bytes)")
            #endif
            return 
        }
        
        let header = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: 0, as: PacketHeader.self)
        }
        
        #if DEBUG
        if packetCount % 60 == 0 { // Log every 60 packets (~1 second)
            print("TelemetryReceiver: Received packet ID \(header.packetId), count: \(packetCount)")
        }
        
        // Log packet types for debugging
        if packetCount % 300 == 0 { // Every 5 seconds
            print("TelemetryReceiver: Recent packet types - ID \(header.packetId) (0=Motion, 1=Session, 2=Lap, 4=Participants, 6=Telemetry, 7=Status)")
        }
        #endif
        
        DispatchQueue.main.async {
            self.packetCount += 1
        }
        
        switch header.packetId {
        case 0: parseMotion(data, header: header)
        case 1: parseSession(data, header: header)
        case 2: parseLapData(data, header: header)
        case 4: parseParticipants(data, header: header)
        case 6: parseCarTelemetry(data, header: header)
        case 7: parseCarStatus(data, header: header)
        case 11: parseSessionHistory(data, header: header)
        default: 
            #if DEBUG
            if packetCount % 100 == 0 {
                print("TelemetryReceiver: Unknown packet ID \(header.packetId)")
            }
            #endif
            break
        }
    }

    // MARK: - Parsers
    private func parseMotion(_ data: Data, header: PacketHeader) {
        guard data.count >= MemoryLayout<PacketMotionData>.size else { 
            #if DEBUG
            print("TelemetryReceiver: Motion packet too small (\(data.count) bytes)")
            #endif
            return 
        }
        
        #if DEBUG
        // Log motion packets occasionally
        if packetCount % 180 == 0 { // Every ~3 seconds
            print("TelemetryReceiver: Processing motion packet, \(header.numActiveCars) cars")
        }
        #endif
        
        let motion = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: 0, as: PacketMotionData.self)
        }
        
        let carCount = min(Int(header.numActiveCars), 22)
        let playerIndex = Int(header.playerCarIndex)
        
        // Extract world positions
        var worldXs: [Float] = []
        var worldZs: [Float] = []
        
        let carData = withUnsafeBytes(of: motion.carMotionData) { bytes in
            bytes.bindMemory(to: CarMotionData.self)
        }
        
        for i in 0..<carCount {
            let car = carData[i]
            worldXs.append(car.worldPositionX)
            worldZs.append(car.worldPositionZ)
        }
        
        // Update bounds
        for i in 0..<carCount {
            let x = worldXs[i]
            let z = worldZs[i]
            
            if x < minX { minX = x }
            if x > maxX { maxX = x }
            if z < minZ { minZ = z }
            if z > maxZ { maxZ = z }
        }
        
        motionFramesObserved += 1
        
        // Freeze bounds after observing enough data
        if motionFramesObserved == 180 && !boundsFrozen {
            let dxProbe = maxX - minX
            let dzProbe = maxZ - minZ
            let padX: Float = dxProbe * 0.12
            let padZ: Float = dzProbe * 0.12
            frozenMinX = minX - padX; frozenMaxX = maxX + padX
            frozenMinZ = minZ - padZ; frozenMaxZ = maxZ + padZ
            boundsFrozen = true
            
            #if DEBUG
            print("TelemetryReceiver: Bounds frozen after \(motionFramesObserved) frames, dx=\(dxProbe), dz=\(dzProbe)")
            #endif
        }
        
        // Normalize coordinates
        let useMinX: Float = boundsFrozen ? frozenMinX : minX
        let useMaxX: Float = boundsFrozen ? frozenMaxX : maxX
        let useMinZ: Float = boundsFrozen ? frozenMinZ : minZ
        let useMaxZ: Float = boundsFrozen ? frozenMaxZ : maxZ
        
        let dx = max(0.001, useMaxX - useMinX)
        let dz = max(0.001, useMaxZ - useMinZ)

        var points = [CGPoint]()
        points.reserveCapacity(carCount)
        
        for i in 0..<carCount {
            let nx = (worldXs[i] - useMinX) / dx
            let nz = (worldZs[i] - useMinZ) / dz
            points.append(CGPoint(x: CGFloat(nx), y: CGFloat(nz)))
        }

        // Publish updates
        DispatchQueue.main.async {
            self.carPoints = points
            self.worldAspect = CGFloat(dx / dz)
            
            #if DEBUG
            // Log car positions occasionally
            if self.packetCount % 180 == 0 && !points.isEmpty { // Every ~3 seconds
                print("TelemetryReceiver: Updated \(points.count) car positions, player at \(playerIndex < points.count ? points[playerIndex] : CGPoint.zero)")
            }
            #endif
            
            // Keep player position trail
            let p = points.indices.contains(playerIndex) ? points[playerIndex] : .zero
            self.recentPositions.append(p)
            if self.recentPositions.count > 800 {
                self.recentPositions.removeFirst(self.recentPositions.count - 800)
            }
        }
    }
    
    private func parseSession(_ data: Data, header: PacketHeader) {
        guard data.count >= MemoryLayout<PacketSessionData>.size else { return }
        
        let session = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: 0, as: PacketSessionData.self)
        }
        
        // Extract track name
        let trackId = Int(session.trackId)
        
        // Filter out invalid track IDs to reduce noise
        guard trackId >= 0 && trackId <= 29 else {
            #if DEBUG
            // Only log extreme invalid IDs to avoid spam
            if abs(trackId) > 100 {
                print("TelemetryReceiver: Ignoring invalid track ID: \(trackId)")
            }
            #endif
            return
        }
        
        let newTrackName = trackIdToName(trackId)
        
        DispatchQueue.main.async {
            if self.trackName != newTrackName {
                self.trackName = newTrackName
                self.resetTrackBounds()
                #if DEBUG
                print("TelemetryReceiver: Track changed to '\(newTrackName)' (ID: \(trackId))")
                #endif
            }
        }
    }
    
    private func parseParticipants(_ data: Data, header: PacketHeader) {
        guard data.count >= MemoryLayout<PacketParticipantsData>.size else { return }
        
        let participants = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: 0, as: PacketParticipantsData.self)
        }
        
        let carCount = min(Int(header.numActiveCars), 22)
        var newTeamIds: [UInt8] = []
        
        let participantData = withUnsafeBytes(of: participants.participants) { bytes in
            bytes.bindMemory(to: ParticipantData.self)
        }
        
        for i in 0..<carCount {
            let participant = participantData[i]
            newTeamIds.append(participant.teamId)
        }
        
        DispatchQueue.main.async {
            self.teamIds = newTeamIds
            self.playerCarIndex = Int(header.playerCarIndex)
        }
    }
    
    private func parseCarTelemetry(_ data: Data, header: PacketHeader) {
        guard data.count >= MemoryLayout<PacketCarTelemetryData>.size else { 
            #if DEBUG
            print("TelemetryReceiver: CarTelemetry packet too small")
            #endif
            return 
        }
        
        let telemetry = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: 0, as: PacketCarTelemetryData.self)
        }
        
        let playerIndex = Int(header.playerCarIndex)
        guard playerIndex < 22 else { 
            #if DEBUG
            print("TelemetryReceiver: Invalid player index \(playerIndex)")
            #endif
            return 
        }
        
        let carTelemetryData = withUnsafeBytes(of: telemetry.carTelemetryData) { bytes in
            bytes.bindMemory(to: CarTelemetryData.self)
        }
        
        let playerCar = carTelemetryData[playerIndex]
        
        DispatchQueue.main.async {
            self.speedKmh = Double(playerCar.speed)
            self.gear = Int(playerCar.gear)
            self.rpm = Double(playerCar.engineRPM)
            self.rpmRedline = Double(playerCar.revLightsPercent > 0 ? Int(playerCar.revLightsPercent) * 100 : 12000)
            self.throttle = playerCar.throttle
            self.brake = Double(playerCar.brake)
            self.drsOpen = playerCar.drs == 1
            
            #if DEBUG
            if self.packetCount % 60 == 0 { // Log every ~1 second
                print("TelemetryReceiver: Speed=\(self.speedKmh)km/h, RPM=\(self.rpm), Gear=\(self.gear)")
            }
            #endif
            
            // Update brake temperatures
            self.brakeTemps = [
                Int(playerCar.brakesTemperature.0),
                Int(playerCar.brakesTemperature.1),
                Int(playerCar.brakesTemperature.2),
                Int(playerCar.brakesTemperature.3)
            ]
            
            // Update tyre temperatures
            self.tyreInnerTemps = [
                Int(playerCar.tyresInnerTemperature.0),
                Int(playerCar.tyresInnerTemperature.1),
                Int(playerCar.tyresInnerTemperature.2),
                Int(playerCar.tyresInnerTemperature.3)
            ]
        }
    }
    
    private func parseCarStatus(_ data: Data, header: PacketHeader) {
        guard data.count >= MemoryLayout<PacketCarStatusData>.size else { return }
        
        let status = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: 0, as: PacketCarStatusData.self)
        }
        
        let playerIndex = Int(header.playerCarIndex)
        guard playerIndex < 22 else { return }
        
        let carStatusData = withUnsafeBytes(of: status.carStatusData) { bytes in
            bytes.bindMemory(to: CarStatusData.self)
        }
        
        let playerStatus = carStatusData[playerIndex]
        
        DispatchQueue.main.async {
            self.drsActive = playerStatus.drsAllowed == 1
            self.fuelPercent = Double(playerStatus.fuelRemainingLaps) / 50.0 // Rough estimate
            
            // Parse ERS with smoothing
            let rawErsPercent = Double(playerStatus.ersStoreEnergy) / 4000000.0 // Convert from Joules to percentage
            
            if !self.ersInitialized {
                self.ersEMA = rawErsPercent
                self.ersInitialized = true
            } else {
                self.ersEMA = self.ersAlpha * rawErsPercent + (1.0 - self.ersAlpha) * self.ersEMA
            }
            
            self.ersPercent = max(0.0, min(1.0, self.ersEMA))
            
            // Update tyre wear
            self.tyreWear = [
                Int(playerStatus.tyresWear.0),
                Int(playerStatus.tyresWear.1),
                Int(playerStatus.tyresWear.2),
                Int(playerStatus.tyresWear.3)
            ]
        }
    }
    
    private func parseLapData(_ data: Data, header: PacketHeader) {
        guard data.count >= MemoryLayout<PacketLapData>.size else { return }
        
        let lapData = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: 0, as: PacketLapData.self)
        }
        
        let playerIndex = Int(header.playerCarIndex)
        guard playerIndex < 22 else { return }
        
        let lapDataArray = withUnsafeBytes(of: lapData.lapData) { bytes in
            bytes.bindMemory(to: LapData.self)
        }
        
        let playerLap = lapDataArray[playerIndex]
        
        DispatchQueue.main.async {
            self.currentLapTime = TimeInterval(playerLap.currentLapTimeInMS) / 1000.0
            self.lastLapTime = TimeInterval(playerLap.lastLapTimeInMS) / 1000.0
            self.bestLapTime = TimeInterval(playerLap.bestLapTimeInMS) / 1000.0
            
            self.sectorTimes = [
                TimeInterval(playerLap.sector1TimeInMS) / 1000.0,
                TimeInterval(playerLap.sector2TimeInMS) / 1000.0,
                0 // Sector 3 is calculated
            ]
            
            if self.lastLapTime > 0 && self.sectorTimes[0] > 0 && self.sectorTimes[1] > 0 {
                self.sectorTimes[2] = self.lastLapTime - self.sectorTimes[0] - self.sectorTimes[1]
            }
        }
    }
    
    private func parseSessionHistory(_ data: Data, header: PacketHeader) {
        // Session history parsing for best times
        guard data.count >= MemoryLayout<PacketSessionHistoryData>.size else { return }
        
        let history = data.withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: 0, as: PacketSessionHistoryData.self)
        }
        
        DispatchQueue.main.async {
            // Update overall best sector times from session history
            if history.bestSector1TimeInMS > 0 {
                self.overallBestSectorMS[0] = Int(history.bestSector1TimeInMS)
            }
            if history.bestSector2TimeInMS > 0 {
                self.overallBestSectorMS[1] = Int(history.bestSector2TimeInMS)
            }
            if history.bestSector3TimeInMS > 0 {
                self.overallBestSectorMS[2] = Int(history.bestSector3TimeInMS)
            }
        }
    }
    
    // MARK: - Helper Functions
    private func resetTrackBounds() {
        minX = .greatestFiniteMagnitude
        maxX = -.greatestFiniteMagnitude
        minZ = .greatestFiniteMagnitude
        maxZ = -.greatestFiniteMagnitude
        boundsFrozen = false
        motionFramesObserved = 0
        recentPositions.removeAll()
    }
    
    private func trackIdToName(_ trackId: Int) -> String {
        let trackNames = [
            0: "Melbourne", 1: "Paul Ricard", 2: "Shanghai", 3: "Bahrain",
            4: "Barcelona", 5: "Monaco", 6: "Montreal", 7: "Silverstone",
            8: "Hockenheim", 9: "Hungaroring", 10: "Spa", 11: "Monza",
            12: "Singapore", 13: "Suzuka", 14: "Abu Dhabi", 15: "Brazil",
            16: "Austria", 17: "Sochi", 18: "Mexico", 19: "Baku",
            20: "Bahrain Short", 21: "Silverstone Short", 22: "Austin",
            23: "Brazil Short", 24: "Imola", 25: "Portimao", 26: "Jeddah",
            27: "Miami", 28: "Las Vegas", 29: "Losail"
        ]
        return trackNames[trackId] ?? "Unknown"
    }
}

// MARK: - F1 Data Structures
struct PacketHeader {
    let packetFormat: UInt16
    let gameMajorVersion: UInt8
    let gameMinorVersion: UInt8
    let packetVersion: UInt8
    let packetId: UInt8
    let sessionUID: UInt64
    let sessionTime: Float
    let frameIdentifier: UInt32
    let playerCarIndex: UInt8
    let secondaryPlayerCarIndex: UInt8
    let numActiveCars: UInt8
}

struct CarMotionData {
    let worldPositionX: Float
    let worldPositionY: Float
    let worldPositionZ: Float
    let worldVelocityX: Float
    let worldVelocityY: Float
    let worldVelocityZ: Float
    let worldForwardDirX: Int16
    let worldForwardDirY: Int16
    let worldForwardDirZ: Int16
    let worldRightDirX: Int16
    let worldRightDirY: Int16
    let worldRightDirZ: Int16
    let gForceLateral: Float
    let gForceLongitudinal: Float
    let gForceVertical: Float
    let yaw: Float
    let pitch: Float
    let roll: Float
}

struct PacketMotionData {
    let header: PacketHeader
    let carMotionData: (CarMotionData, CarMotionData, CarMotionData, CarMotionData, CarMotionData, CarMotionData, CarMotionData, CarMotionData, CarMotionData, CarMotionData, CarMotionData, CarMotionData, CarMotionData, CarMotionData, CarMotionData, CarMotionData, CarMotionData, CarMotionData, CarMotionData, CarMotionData, CarMotionData, CarMotionData)
}

struct PacketSessionData {
    let header: PacketHeader
    let weather: UInt8
    let trackTemperature: Int8
    let airTemperature: Int8
    let totalLaps: UInt8
    let trackLength: UInt16
    let sessionType: UInt8
    let trackId: Int8
    let formula: UInt8
    let sessionTimeLeft: UInt16
    let sessionDuration: UInt16
    let pitSpeedLimit: UInt8
    let gamePaused: UInt8
    let isSpectating: UInt8
    let spectatorCarIndex: UInt8
    let sliProNativeSupport: UInt8
    let numMarshalZones: UInt8
    // ... other fields as needed
}

struct ParticipantData {
    let aiControlled: UInt8
    let driverId: UInt8
    let networkId: UInt8
    let teamId: UInt8
    let myTeam: UInt8
    let raceNumber: UInt8
    let nationality: UInt8
    let name: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)
    let yourTelemetry: UInt8
    let showOnlineNames: UInt8
    let platform: UInt8
}

struct PacketParticipantsData {
    let header: PacketHeader
    let numActiveCars: UInt8
    let participants: (ParticipantData, ParticipantData, ParticipantData, ParticipantData, ParticipantData, ParticipantData, ParticipantData, ParticipantData, ParticipantData, ParticipantData, ParticipantData, ParticipantData, ParticipantData, ParticipantData, ParticipantData, ParticipantData, ParticipantData, ParticipantData, ParticipantData, ParticipantData, ParticipantData, ParticipantData)
}

struct CarTelemetryData {
    let speed: UInt16
    let throttle: Float
    let steer: Float
    let brake: Float
    let clutch: UInt8
    let gear: Int8
    let engineRPM: UInt16
    let drs: UInt8
    let revLightsPercent: UInt8
    let revLightsBitValue: UInt16
    let brakesTemperature: (UInt16, UInt16, UInt16, UInt16)
    let tyresSurfaceTemperature: (UInt8, UInt8, UInt8, UInt8)
    let tyresInnerTemperature: (UInt8, UInt8, UInt8, UInt8)
    let engineTemperature: UInt16
    let tyresPressure: (Float, Float, Float, Float)
    let surfaceType: (UInt8, UInt8, UInt8, UInt8)
}

struct PacketCarTelemetryData {
    let header: PacketHeader
    let carTelemetryData: (CarTelemetryData, CarTelemetryData, CarTelemetryData, CarTelemetryData, CarTelemetryData, CarTelemetryData, CarTelemetryData, CarTelemetryData, CarTelemetryData, CarTelemetryData, CarTelemetryData, CarTelemetryData, CarTelemetryData, CarTelemetryData, CarTelemetryData, CarTelemetryData, CarTelemetryData, CarTelemetryData, CarTelemetryData, CarTelemetryData, CarTelemetryData, CarTelemetryData)
    let mfdPanelIndex: UInt8
    let mfdPanelIndexSecondaryPlayer: UInt8
    let suggestedGear: Int8
}

struct CarStatusData {
    let tractionControl: UInt8
    let antiLockBrakes: UInt8
    let fuelMix: UInt8
    let frontBrakeBias: UInt8
    let pitLimiterStatus: UInt8
    let fuelInTank: Float
    let fuelCapacity: Float
    let fuelRemainingLaps: Float
    let maxRPM: UInt16
    let idleRPM: UInt16
    let maxGears: UInt8
    let drsAllowed: UInt8
    let drsActivationDistance: UInt16
    let actualTyreCompound: UInt8
    let visualTyreCompound: UInt8
    let tyresAgeLaps: UInt8
    let vehicleFiaFlags: Int8
    let ersStoreEnergy: Float
    let ersDeployMode: UInt8
    let ersHarvestedThisLapMGUK: Float
    let ersHarvestedThisLapMGUH: Float
    let ersDeployedThisLap: Float
    let networkPaused: UInt8
    let tyresWear: (UInt8, UInt8, UInt8, UInt8)
}

struct PacketCarStatusData {
    let header: PacketHeader
    let carStatusData: (CarStatusData, CarStatusData, CarStatusData, CarStatusData, CarStatusData, CarStatusData, CarStatusData, CarStatusData, CarStatusData, CarStatusData, CarStatusData, CarStatusData, CarStatusData, CarStatusData, CarStatusData, CarStatusData, CarStatusData, CarStatusData, CarStatusData, CarStatusData, CarStatusData, CarStatusData)
}

struct LapData {
    let lastLapTimeInMS: UInt32
    let currentLapTimeInMS: UInt32
    let sector1TimeInMS: UInt16
    let sector2TimeInMS: UInt16
    let lapDistance: Float
    let totalDistance: Float
    let safetyCarDelta: Float
    let carPosition: UInt8
    let currentLapNum: UInt8
    let pitStatus: UInt8
    let numPitStops: UInt8
    let sector: UInt8
    let currentLapInvalid: UInt8
    let penalties: UInt8
    let warnings: UInt8
    let numUnservedDriveThroughPens: UInt8
    let numUnservedStopGoPens: UInt8
    let gridPosition: UInt8
    let driverStatus: UInt8
    let resultStatus: UInt8
    let pitLaneTimerActive: UInt8
    let pitLaneTimeInLaneInMS: UInt16
    let pitStopTimerInMS: UInt16
    let pitStopShouldServePen: UInt8
    let bestLapTimeInMS: UInt32
    let bestLapNum: UInt8
    let bestLapSector1TimeInMS: UInt16
    let bestLapSector2TimeInMS: UInt16
    let bestLapSector3TimeInMS: UInt16
    let bestOverallSector1TimeInMS: UInt16
    let bestOverallSector1LapNum: UInt8
    let bestOverallSector2TimeInMS: UInt16
    let bestOverallSector2LapNum: UInt8
    let bestOverallSector3TimeInMS: UInt16
    let bestOverallSector3LapNum: UInt8
}

struct PacketLapData {
    let header: PacketHeader
    let lapData: (LapData, LapData, LapData, LapData, LapData, LapData, LapData, LapData, LapData, LapData, LapData, LapData, LapData, LapData, LapData, LapData, LapData, LapData, LapData, LapData, LapData, LapData)
    let timeTrialPBCarIdx: UInt8
    let timeTrialRivalCarIdx: UInt8
}

struct PacketSessionHistoryData {
    let header: PacketHeader
    let carIdx: UInt8
    let numLaps: UInt8
    let numTyreStints: UInt8
    let bestLapTimeLapNum: UInt8
    let bestSector1LapNum: UInt8
    let bestSector2LapNum: UInt8
    let bestSector3LapNum: UInt8
    let bestSector1TimeInMS: UInt32
    let bestSector2TimeInMS: UInt32
    let bestSector3TimeInMS: UInt32
    // ... other fields as needed
}

// MARK: - Driver Order Data (struct defined in ContentView.swift)
