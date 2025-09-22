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


    // Track map
    @Published var recentPositions: [CGPoint] = []
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
    private let minSpreadBeforePublish: Float = 5.0   // ignore degenerate grid extents
    @Published var carPoints: [CGPoint] = Array(repeating: .zero, count: 22) // all cars, normalized 0..1
    @Published var playerCarIndex: Int = 0
    @Published var trackName: String = ""    // e.g., "Silverstone"
    @Published var worldAspect: CGFloat = 1.0 // dx/dz aspect ratio for mapping

    // Driver order / participants
    @Published var driverNames: [String] = Array(repeating: "", count: 22)
    @Published var driverPositions: [Int] = Array(repeating: 0, count: 22)
    @Published var driverOrderItems: [DriverOrderItem] = []
	@Published var numActiveCars: Int = 20
	@Published var raceNumbers: [Int] = Array(repeating: 0, count: 22)
    private var carCurrentMSAll: [Int] = Array(repeating: 0, count: 22)
    private var lastDriverOrderPublishAt: CFTimeInterval = 0
    private var carLastLapMSAll: [Int] = Array(repeating: 0, count: 22)
    private var carBestLapMSAll: [Int] = Array(repeating: 0, count: 22)
    private var carCompletedSumMSAll: [Int] = Array(repeating: 0, count: 22)
    private var carCompletedLapCountAll: [Int] = Array(repeating: 0, count: 22)
    
    private var carLastLapUpdatedAt: [CFTimeInterval] = Array(repeating: 0, count: 22)

    private var conn: NWConnection?
    private var listener: NWListener?
    private let q = DispatchQueue(label: "f1.telemetry")
    private var damageFilter: [String: CGFloat] = [:]
    private var ersEMA: Double = 0

    // MARK: - Start/Stop
    func start(port: UInt16 = 20777) {
        stop()
        guard let p = NWEndpoint.Port(rawValue: port) else { return }

        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        do {
            let l = try NWListener(using: params, on: p)
            listener = l
            l.stateUpdateHandler = { state in
                print("UDP listener state:", state)
            }
            l.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                print("UDP new connection from:", connection.endpoint)
                connection.stateUpdateHandler = { st in
                    print("UDP conn state:", st)
                }
                self.conn = connection
                connection.start(queue: self.q)
                self.receive(on: connection)
            }
            print("UDP listening on port", port)
            l.start(queue: q)
        } catch {
            print("Failed to start UDP listener:", error)
        }
        }

    func stop() {
        listener?.cancel()
        listener = nil
            conn?.cancel()
            conn = nil
        }

        private func receiveLoop() { /* deprecated by receive(on:) */ }

    // MARK: - Demux
    private func handle(packet data: Data) {
        guard !data.isEmpty else { return }
        var i = 0
        func readU16() -> UInt16 {
            defer { i += 2 }
            guard i + 2 <= data.count else { return 0 }
            return UInt16(data[i]) | (UInt16(data[i+1]) << 8)
        }

        func readU8() -> UInt8 {
            defer { i += 1 }
            guard i + 1 <= data.count else { return 0 }
            return data[i]
        }

        func readF32() -> Float {
            defer { i += 4 }
            guard i + 4 <= data.count else { return 0 }
            let bits = UInt32(data[i])
                    | (UInt32(data[i+1]) << 8)
                    | (UInt32(data[i+2]) << 16)
                    | (UInt32(data[i+3]) << 24)
            return Float(bitPattern: bits)
        }

        guard data.count >= 29 else { return }
        _ = readU16()            // packetFormat
        _ = readU8()             // gameYear
        _ = readU8()             // gameMajor
        _ = readU8()             // gameMinor
        _ = readU8()             // packetVersion
        let packetId = readU8()
        _ = data.readU64LE(offset: i); i += 8  // sessionUID
        _ = readF32()                          // sessionTime
        _ = data.readU32LE(offset: i); i += 4  // frameIdentifier
        _ = data.readU32LE(offset: i); i += 4  // overallFrameIdentifier
        let playerIndex = Int(readU8())          // playerCarIndex
        DispatchQueue.main.async { self.playerCarIndex = playerIndex }
        _ = readU8()                              // secondaryPlayerIndex
        let headerSize = i

        switch packetId {
        case 2:  parseLapData(data, headerSize: headerSize, playerIndex: playerIndex)
        case 14: parseSessionHistory(data, headerSize: headerSize, playerIndex: playerIndex)
        case 0:  parseMotion(data, headerSize: headerSize, playerIndex: playerIndex)
        case 6:  parseCarTelemetry(data, headerSize: headerSize, playerIndex: playerIndex)
        case 10: parseCarDamage(data, headerSize: headerSize, playerIndex: playerIndex)
        case 7:  parseCarStatus(data, headerSize: headerSize, playerIndex: playerIndex) // ERS, flags, etc.
        case 1:  parseSession(data, headerSize: headerSize) // trackId, weather, etc.
        case 4:  parseParticipants(data, headerSize: headerSize) // driver names
        case 9:  parseLobbyInfo(data, headerSize: headerSize) // fallback names (some builds)
        case 12: parseLobbyInfo(data, headerSize: headerSize) // fallback names (other builds)
        default: break
        }
    }

    // MARK: - Parsers
    private func parseCarTelemetry(_ data: Data, headerSize: Int, playerIndex: Int) {
        let perCarSize = 60
        let carBase = headerSize + (playerIndex * perCarSize)
        guard carBase + perCarSize <= data.count else { return }

        let speed: UInt16   = data.readLE(offset: carBase + 0)
        let throttle: Float = data.readF32LE(offset: carBase + 2)
        let brake: Float    = data.readF32LE(offset: carBase + 10)
        let gearRaw: Int8   = data.readI8(offset: carBase + 15)
        let rpm: UInt16     = data.readLE(offset: carBase + 16)
        let drs: UInt8      = data.readU8(offset: carBase + 18)

        // after existing reads (speed/throttle/…)
        let tFL = Int(data.readU8(offset: carBase + 34))
        let tFR = Int(data.readU8(offset: carBase + 35))
        let tRL = Int(data.readU8(offset: carBase + 36))
        let tRR = Int(data.readU8(offset: carBase + 37))

        // brake temps are u16[4] starting at 22 (per-car block)
        let bFL = Int(data.readLE(offset: carBase + 22) as UInt16)
        let bFR = Int(data.readLE(offset: carBase + 24) as UInt16)
        let bRL = Int(data.readLE(offset: carBase + 26) as UInt16)
        let bRR = Int(data.readLE(offset: carBase + 28) as UInt16)

        DispatchQueue.main.async {
            // ...existing assignments...
            self.tyreInnerTemps = [tFL, tFR, tRL, tRR]
            self.brakeTemps = [bFL, bFR, bRL, bRR]    // NEW
        }



        DispatchQueue.main.async {
            self.packetCount += 1
            self.speedKmh = Double(speed)
            self.gear = (gearRaw == -1) ? 0 : Int(gearRaw)
            self.rpm = Double(rpm)
            self.rpmRedline = 12000
            self.throttle = throttle
            self.drsActive = (drs != 0)
            self.tyreInnerTemps = [tFL, tFR, tRL, tRR]
            self.brake = Double(brake) // normalize 0...1
            self.drsOpen  = (drs == 1)                // set true when DRS open
        }
    }

    private func parseCarDamage(_ data: Data, headerSize: Int, playerIndex: Int) {
        // Derive per-car size and parse according to common F1 formats (F1 22–24)
        let carCount = 22
        let bytesRemaining = max(0, data.count - headerSize)
        let perCarSize = max(16, bytesRemaining / carCount)
        let carBase = headerSize + (playerIndex * perCarSize)
        guard carBase + 32 <= data.count else { return }

        // Tyre wear: primary bytes at 16..19 (0..100); fallback to floats at 0,4,8,12
        func fToPctInt(_ f: Float) -> Int {
            if f.isNaN || !f.isFinite { return 0 }
            if f >= 0, f <= 1.01 { return Int(roundf(f * 100)) }
            if f >= 0, f <= 100.0 { return Int(roundf(f)) }
            return 0
        }
        // Spec order is usually RL, RR, FL, FR at 16..19; remap to FL, FR, RL, RR
        var wFL = Int(data.readU8(offset: carBase + 18))
        var wFR = Int(data.readU8(offset: carBase + 19))
        var wRL = Int(data.readU8(offset: carBase + 16))
        var wRR = Int(data.readU8(offset: carBase + 17))
        // Fallback: try floats if bytes look wrong
        if (wFL|wFR|wRL|wRR) == 0 {
            // If float fallback is used, assume float order is also RL, RR, FL, FR
            let fRL = fToPctInt(data.readF32LE(offset: carBase + 0))
            let fRR = fToPctInt(data.readF32LE(offset: carBase + 4))
            let fFL = fToPctInt(data.readF32LE(offset: carBase + 8))
            let fFR = fToPctInt(data.readF32LE(offset: carBase + 12))
            wFL = fFL; wFR = fFR; wRL = fRL; wRR = fRR
        }

        // Optional: wings and other aero damage (use common byte offsets per spec)
        var wingL: CGFloat = 0, wingR: CGFloat = 0, rearWing: CGFloat = 0
        var floorDmg: CGFloat = 0, sidepodDmg: CGFloat = 0, drsDmg: CGFloat = 0
        // Wing/front/rear damage are commonly bytes after brake damage
        // TyresDamage[4] at 16..19, BrakesDamage[4] at 20..23, Wings at 24..26, Floor 27, Diffuser 28, Sidepod 29, DRS fault 30
        wingL = CGFloat(min(100, Int(data.readU8(offset: carBase + 24)))) / 100.0
        wingR = CGFloat(min(100, Int(data.readU8(offset: carBase + 25)))) / 100.0
        rearWing = CGFloat(min(100, Int(data.readU8(offset: carBase + 26)))) / 100.0
        // Do NOT attempt speculative fallbacks for wings. Some builds place unrelated values
        // at nearby offsets (e.g., brake temps/flags) which caused spurious non-zero blips
        // and visible flicker when there is actually no damage.

        // Try nearby floats for floor and sidepod damage
        // Floor, sidepod and DRS per common spec bytes
        floorDmg = CGFloat(min(100, Int(data.readU8(offset: carBase + 27)))) / 100.0
        sidepodDmg = CGFloat(min(100, Int(data.readU8(offset: carBase + 29)))) / 100.0
        drsDmg = CGFloat(min(1, Int(data.readU8(offset: carBase + 30))))

        DispatchQueue.main.async {
            self.tyreWear = [wFL, wFR, wRL, wRR]
            let dRaw: [String: CGFloat] = [
                "fl_tyre": CGFloat(wFL) / 100.0,
                "fr_tyre": CGFloat(wFR) / 100.0,
                "rl_tyre": CGFloat(wRL) / 100.0,
                "rr_tyre": CGFloat(wRR) / 100.0,
                "front_wing_left": wingL,
                "front_wing_right": wingR,
                "rear_wing": rearWing,
                "underfloor": floorDmg,
                "underfloor_2": floorDmg,
                "sidepod_left": sidepodDmg,
                "sidepod_right": sidepodDmg,
                "drs": min(1, drsDmg)
            ]
            self.overlayDamage = self.stabilizeDamage(dRaw)
            // debug damage logs disabled to avoid UI stalls
        }
    }

    /// Smooth tiny fluctuations and snap near-zero values to 0 to avoid color flicker.
    private func stabilizeDamage(_ raw: [String: CGFloat]) -> [String: CGFloat] {
        // Hysteresis thresholds
        let snapDown: CGFloat = 0.08   // if value < 8% and previously small → 0
        let snapUpGuard: CGFloat = 0.16 // require >16% to "wake up" from zero state
        let alpha: CGFloat = 0.12      // slightly stronger smoothing

        var out: [String: CGFloat] = [:]
        for (key, rawValue) in raw {
            var v = max(0, min(1, rawValue))
            let prev = damageFilter[key] ?? 0

            // Hysteresis snap-to-zero
            if prev < snapUpGuard && v < snapDown { v = 0 }

            // Low-pass filter
            let smoothed = prev * (1 - alpha) + v * alpha

            // Quantize to 2% steps for extra stability on jittery fields
            let quantized = (smoothed * 50).rounded() / 50

            out[key] = quantized
            damageFilter[key] = quantized
        }
        return out
    }

    /// ERS and other per-car status
    private func parseCarStatus(_ data: Data, headerSize: Int, playerIndex: Int) {
        // Robust ERS detection: scan the entire packet payload for plausible fields.
        // Prefer a 0..1 percentage, else a Joules value (normalize to ~4e6 J capacity).
        let payloadStart = headerSize
        let payloadEnd = data.count
        guard payloadEnd - payloadStart >= 4 else { return }

        var bestPctFromPercent: Double = -1
        var bestPctFromJoules: Double = -1

        var i = payloadStart
        while i + 4 <= payloadEnd {
            let v = data.readF32LE(offset: i)
            if v.isFinite && v >= 0 {
                // Candidate as percent
                if v <= 100.5 {
                    let cand = Double(v) / 100.0
                    if cand >= 0 && cand <= 1 { bestPctFromPercent = max(bestPctFromPercent, cand) }
                }
                // Candidate as Joules (common max ~4e6)
                if v >= 1000 && v <= 5_000_000 {
                    let cand = Double(v) / 4_000_000.0
                    if cand >= 0 && cand <= 1 { bestPctFromJoules = max(bestPctFromJoules, cand) }
                }
            }
            i += 4
        }

        // Heuristic pick: if both found, favor the one closer to previous EMA to avoid snapping
        let prev = ersEMA
        var chosen: Double = -1
        if bestPctFromPercent >= 0 && bestPctFromJoules >= 0 {
            let dP = abs(bestPctFromPercent - prev)
            let dJ = abs(bestPctFromJoules - prev)
            chosen = (dP <= dJ) ? bestPctFromPercent : bestPctFromJoules
        } else {
            chosen = max(bestPctFromPercent, bestPctFromJoules)
        }

        if chosen < 0 { chosen = prev } // fallback to last known if nothing found

        // Smooth to avoid jitter; mildly inertial to reflect storage behavior
        let alpha = 0.25
        ersEMA = ersEMA * (1 - alpha) + chosen * alpha
        let clamped = max(0, min(1, ersEMA))
        DispatchQueue.main.async { self.ersPercent = clamped }
    }

    private func parseMotion(_ data: Data, headerSize: Int, playerIndex: Int) {
        let carCount = 22
        let perCarSize = 60
        var worldXs = [Float](repeating: 0, count: carCount)
        var worldZs = [Float](repeating: 0, count: carCount)

        // 1) Read world positions for all cars; expand global bounds (until frozen)
        for idx in 0..<carCount {
            let base = headerSize + (idx * perCarSize)
            guard base + 12 <= data.count else { continue }
            let wx: Float = data.readF32LE(offset: base + 0)
            let wz: Float = data.readF32LE(offset: base + 8)
            worldXs[idx] = wx
            worldZs[idx] = wz

            if !boundsFrozen {
            if wx < minX { minX = wx }; if wx > maxX { maxX = wx }
            if wz < minZ { minZ = wz }; if wz > maxZ { maxZ = wz }
            }
        }

        // After a brief warm-up, freeze bounds to keep the map static
        if !boundsFrozen {
            motionFramesObserved += 1
            let dxProbe = maxX - minX
            let dzProbe = maxZ - minZ
            if motionFramesObserved >= 60 && dxProbe > 1e-3 && dzProbe > 1e-3 { // ~3s at 20Hz
                // Add margin so later points stay within [0,1]
                let padX: Float = dxProbe * 0.12
                let padZ: Float = dzProbe * 0.12
                frozenMinX = minX - padX; frozenMaxX = maxX + padX
                frozenMinZ = minZ - padZ; frozenMaxZ = maxZ + padZ
                boundsFrozen = true
            }
        }

        // 2) Normalize into 0..1. Even during warm-up, publish provisional dots
        // using current dynamic bounds so the map is never empty.

        // Normalize using current or frozen bounds
        let useMinX = boundsFrozen ? frozenMinX : minX
        let useMaxX = boundsFrozen ? frozenMaxX : maxX
        let useMinZ = boundsFrozen ? frozenMinZ : minZ
        let useMaxZ = boundsFrozen ? frozenMaxZ : maxZ
        let dx = max(0.001, useMaxX - useMinX)
        let dz = max(0.001, useMaxZ - useMinZ)

        var points = [CGPoint]()
        points.reserveCapacity(carCount)
        for idx in 0..<carCount {
            var nx = (worldXs[idx] - useMinX) / dx
            var nz = (worldZs[idx] - useMinZ) / dz
            // Clamp to [0,1] to avoid off-screen mapping
            nx = max(0, min(1, nx))
            nz = max(0, min(1, nz))
            points.append(CGPoint(x: CGFloat(nx), y: CGFloat(nz)))
        }

        // 3) Publish
        DispatchQueue.main.async {
            self.carPoints = points
            self.worldAspect = CGFloat(dx / dz)
            // (Optional) keep your old recentPositions trail for the player:
            let p = points.indices.contains(playerIndex) ? points[playerIndex] : .zero
            self.recentPositions.append(p)
            if self.recentPositions.count > 800 {
                self.recentPositions.removeFirst(self.recentPositions.count - 800)
            }
        }
    }
}

// MARK: - Data helpers
private extension Data {
    // Little-endian integer from raw bytes (no withUnsafeBytes)
    func readLE<T: FixedWidthInteger>(offset: Int) -> T {
        let n = MemoryLayout<T>.size
        guard offset + n <= count else { return 0 }
        var value: T = 0
        for k in 0..<n {
            let byte = T(self[offset + k])
            value |= (byte << (T(k) * 8))
        }
        return value
    }

    func readU32LE(offset: Int) -> UInt32 { readLE(offset: offset) as UInt32 }
    func readU64LE(offset: Int) -> UInt64 { readLE(offset: offset) as UInt64 }

    func readU8(offset: Int) -> UInt8 {
        guard offset < count else { return 0 }
        return self[offset]
    }

    func readI8(offset: Int) -> Int8 {
        // avoid withUnsafeBytes; convert from UInt8
        return Int8(bitPattern: readU8(offset: offset))
    }

    func readF32LE(offset: Int) -> Float {
        guard offset + 4 <= count else { return 0 }
        let bits = UInt32(self[offset])
                | (UInt32(self[offset + 1]) << 8)
                | (UInt32(self[offset + 2]) << 16)
                | (UInt32(self[offset + 3]) << 24)
        return Float(bitPattern: bits)
    }
}

// MARK: - Lap timing parsers
extension TelemetryReceiver {

    /// Live per-car lap data (current/last + running sector times)
    func parseLapData(_ data: Data, headerSize: Int, playerIndex: Int) {
        // Derive per-car block size for this packet to avoid hardcoding
        let carCount = 22
        let bytesRemaining = max(0, data.count - headerSize)
        let perCar = max(16, bytesRemaining / carCount)

        var globalBest = [Int.max, Int.max, Int.max]

        // Sweep all cars to compute overall best sectors and capture per-car position + current time
        var newPositions: [Int] = Array(repeating: 0, count: carCount)
        for idx in 0..<carCount {
            let base = headerSize + idx * perCar
            guard base + 24 <= data.count else { continue }
            // Try MS format first
            var current  = Int(data.readLE(offset: base + 4)  as UInt32)
            var s1       = Int(data.readLE(offset: base + 8)  as UInt16)
            var s2       = Int(data.readLE(offset: base + 10) as UInt16)
            // Validate ranges; if out of range, try seconds floats and convert
            if current <= 0 || current > 600_000 {
                _ = data.readF32LE(offset: base + 0) // lastF (unused)
                let currF: Float = data.readF32LE(offset: base + 4)
                current = Int(currF * 1000)
                // Sector positions may shift in some builds; try alternative (+12/+14)
                var s1u: Int = Int(data.readLE(offset: base + 8)  as UInt16)
                var s2u: Int = Int(data.readLE(offset: base + 10) as UInt16)
                if s1u <= 0 || s1u > 120_000 || s2u <= 0 || s2u > 120_000 {
                    s1u = Int(data.readLE(offset: base + 12) as UInt16)
                    s2u = Int(data.readLE(offset: base + 14) as UInt16)
                }
                s1 = s1u; s2 = s2u
                // If everything still looks bogus, skip this car
                if current <= 0 || current > 600_000 { continue }
            }
            let s3Guess  = max(0, current - s1 - s2)
            if s1 > 0 && s1 < globalBest[0] { globalBest[0] = s1 }
            if s2 > 0 && s2 < globalBest[1] { globalBest[1] = s2 }
            if s3Guess > 0 && s3Guess < globalBest[2] { globalBest[2] = s3Guess }

            // Save current lap ms per car
            if idx >= 0 && idx < 22, current > 0 {
                carCurrentMSAll[idx] = current
            }
            // Update car positions if available (common offsets)
            var pos = Int(data.readU8(offset: base + 20))
            if !(1...22).contains(pos) { pos = Int(data.readU8(offset: base + 21)) }
            if !(1...22).contains(pos) { pos = Int(data.readU8(offset: base + 19)) }
            if !(1...22).contains(pos) { pos = Int(data.readU8(offset: base + 22)) }
            if !(1...22).contains(pos) { pos = Int(data.readU8(offset: base + 18)) }
            if (1...22).contains(pos) { if idx < newPositions.count { newPositions[idx] = pos } }
        }
        let overall = globalBest.map { $0 == Int.max ? 0 : $0 }

        // Now read the player's values (also capture last-lap ms for gaps if needed)
        let pBase = headerSize + playerIndex * perCar
        guard pBase + 16 <= data.count else { return }
        // Prefer MS layout
        var lastLap  = Int(data.readLE(offset: pBase + 0)  as UInt32)
        var current  = Int(data.readLE(offset: pBase + 4)  as UInt32)
        var s1       = Int(data.readLE(offset: pBase + 8)  as UInt16)
        var s2       = Int(data.readLE(offset: pBase + 10) as UInt16)
        // Fallback to seconds floats if MS looks invalid
        if (lastLap <= 0 || lastLap > 600_000) || (current < 0 || current > 600_000) {
            let lastF: Float = data.readF32LE(offset: pBase + 0)
            let currF: Float = data.readF32LE(offset: pBase + 4)
            lastLap = Int(max(0, lastF) * 1000)
            current = Int(max(0, currF) * 1000)
            var s1u: Int = Int(data.readLE(offset: pBase + 8)  as UInt16)
            var s2u: Int = Int(data.readLE(offset: pBase + 10) as UInt16)
            if s1u <= 0 || s1u > 120_000 || s2u <= 0 || s2u > 120_000 {
                s1u = Int(data.readLE(offset: pBase + 12) as UInt16)
                s2u = Int(data.readLE(offset: pBase + 14) as UInt16)
            }
            s1 = s1u; s2 = s2u
        }
        // s3 live split: use current - s1 - s2, but if current is 0 early in first lap, prefer last known running time
        let s3Guess  = max(0, current - s1 - s2)
        var lapNum   = Int(data.readU8(offset: pBase + min(20, perCar - 1)))
        if lapNum == 0 && pBase + 21 < data.count { lapNum = Int(data.readU8(offset: pBase + 21)) }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Publish driver positions on main thread
            if newPositions.contains(where: { $0 > 0 }) {
                self.driverPositions = newPositions
            }
            self.lapNumber     = lapNum
            self.currentLapMS  = current
            self.lastLapMS     = lastLap
            self.sectorMS      = [s1, s2, s3Guess]
            self.overallBestSectorMS = overall
            // Track player's last-lap time for potential UI usage; also keep per-car (player) reference
            if playerIndex >= 0 && playerIndex < self.carLastLapMSAll.count {
                self.carLastLapMSAll[playerIndex] = lastLap
            }
            // periodic lap debug log disabled
        }
    }

    /// Authoritative lap/sector times after each lap completes
    func parseSessionHistory(_ data: Data, headerSize: Int, playerIndex: Int) {
        // header: carIdx(u8), numLaps(u8), bestLapNumber(u8), ... (we just use these)
        guard headerSize + 8 <= data.count else { return }
        let carIdx    = Int(data.readU8(offset: headerSize + 0))
        let numLaps   = Int(data.readU8(offset: headerSize + 1))
        let bestLapNo = Int(data.readU8(offset: headerSize + 2))

        // Size of one LapHistoryData entry (adjust 11→12 if needed for your build)
        let lapEntry = 11
        let lapsBase = headerSize + 8
        guard carIdx == playerIndex,
              numLaps > 0,
              lapsBase + numLaps * lapEntry <= data.count
        else { return }

        // Latest completed lap (index numLaps - 1)
        let lastBase = lapsBase + (numLaps - 1) * lapEntry
        let lastLap  = Int(data.readLE(offset: lastBase + 0) as UInt32)   // lapTimeInMS
        let lS1      = Int(data.readLE(offset: lastBase + 4) as UInt16)   // sector1TimeInMS
        let lS2      = Int(data.readLE(offset: lastBase + 6) as UInt16)   // sector2TimeInMS
        let lS3      = Int(data.readLE(offset: lastBase + 8) as UInt16)   // sector3TimeInMS

        // Best lap time (if bestLapNo > 0)
        var bestLap = self.bestLapMS
        if bestLapNo > 0 {
            let bestBase = lapsBase + (bestLapNo - 1) * lapEntry
            if bestBase + 4 <= data.count {
                bestLap = Int(data.readLE(offset: bestBase + 0) as UInt32)
            }
        }

        // Compute personal-best sector times across all completed laps we have
        var bestS1 = Int.max, bestS2 = Int.max, bestS3 = Int.max
        var completedSum = 0
        for idx in 0..<numLaps {
            let base = lapsBase + idx * lapEntry
            guard base + 9 <= data.count else { continue }
            let lms = Int(data.readLE(offset: base + 0) as UInt32)
            if lms > 0 { completedSum += lms }
            let s1 = Int(data.readLE(offset: base + 4) as UInt16)
            let s2 = Int(data.readLE(offset: base + 6) as UInt16)
            let s3 = Int(data.readLE(offset: base + 8) as UInt16)
            if s1 > 0 && s1 < bestS1 { bestS1 = s1 }
            if s2 > 0 && s2 < bestS2 { bestS2 = s2 }
            if s3 > 0 && s3 < bestS3 { bestS3 = s3 }
        }
        let bestSectors: [Int] = [bestS1, bestS2, bestS3].map { $0 == Int.max ? 0 : $0 }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lastLapMS    = lastLap
            if bestLap > 0 {
                self.bestLapMS = bestLap
            }
            self.lastSectorMS = [lS1, lS2, lS3]
            self.bestSectorMS = bestSectors
            let now = CACurrentMediaTime()
            if carIdx >= 0 && carIdx < self.carLastLapMSAll.count {
                self.carLastLapMSAll[carIdx] = lastLap
                self.carLastLapUpdatedAt[carIdx] = now
            }
            if carIdx >= 0 && carIdx < self.carBestLapMSAll.count {
                if bestLap > 0 {
                    if self.carBestLapMSAll[carIdx] == 0 || bestLap < self.carBestLapMSAll[carIdx] {
                        self.carBestLapMSAll[carIdx] = bestLap
                    }
                }
            }
            if carIdx >= 0 && carIdx < self.carCompletedSumMSAll.count {
                self.carCompletedSumMSAll[carIdx] = completedSum
                self.carCompletedLapCountAll[carIdx] = numLaps
            }
            // periodic session history log disabled
        }
    }

    /// Session packet (trackId, etc.)
    private func parseSession(_ data: Data, headerSize: Int) {
        // Heuristic offsets compatible with recent F1 formats:
        // After header: weather(u8), trackTemp(i8), airTemp(i8), totalLaps(u8), trackLength(u16), sessionType(u8), trackId(i8), ...
        // Try a couple of nearby offsets for robustness.
        let candidates: [Int] = [7, 8, 9, 10]
        var id: Int8 = -127
        for off in candidates {
            let v = Int8(bitPattern: data.readU8(offset: headerSize + off))
            if v >= -1 && v <= 127 { id = v; break }
        }
        let name = TrackMap.name(for: Int(id))
        if !name.isEmpty {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.trackName != name {
                    print("Session: trackId=\(id) → \(name)")
                    self.trackName = name
                    self.resetTrackBounds()
                }
            }
        }
    }

    // MARK: - Participants (driver names)
    private func parseParticipants(_ data: Data, headerSize: Int) {
        // F1 24: fixed 22 entries; parse names and raceNumbers conservatively
        let maxDrivers = 22
        let bytes = data.count
        guard bytes > headerSize + 1 else { return }
        let numActive = Int(data.readU8(offset: headerSize))

        var names: [String] = Array(repeating: "", count: maxDrivers)
        var numbers: [Int] = Array(repeating: 0, count: maxDrivers)

        let per = 56
        let base = headerSize + 1
        for carIdx in 0..<maxDrivers {
            let start = base + carIdx * per
            guard start + 55 <= bytes else { break }
            numbers[carIdx] = Int(data.readU8(offset: start + 4))
            let nameBytes: [UInt8] = Array(data[(start + 6)..<(start + 54)])
            let trimmed = Array(nameBytes.prefix { $0 != 0 })
            let decoded = String(bytes: trimmed, encoding: .utf8)
                ?? String(bytes: trimmed, encoding: .ascii)
                ?? ""
            names[carIdx] = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var merged = self.driverNames
            for i in 0..<maxDrivers {
                let cand = names[i]
                if !cand.isEmpty { merged[i] = cand }
            }
            self.driverNames = merged
            if self.raceNumbers.count != maxDrivers { self.raceNumbers = Array(repeating: 0, count: maxDrivers) }
            self.raceNumbers = numbers
            if numActive > 0 && numActive <= maxDrivers { self.numActiveCars = numActive }
            self.publishDriverOrder()
        }
    }

    // MARK: - LobbyInfo (fallback names)
    private func parseLobbyInfo(_ data: Data, headerSize: Int) {
        // F1 24 LobbyInfo: after header, m_numPlayers(u8), then 22 entries (~53-60 bytes). We'll scan len conservatively.
        let maxEntries = 22
        let bytes = data.count
        guard bytes > headerSize + 1 else { return }
        let _ = Int(data.readU8(offset: headerSize))
        let per = max(24, (bytes - (headerSize + 1)) / maxEntries)
        let base = headerSize + 1

        var names: [String] = Array(repeating: "", count: maxEntries)
        var numbers: [Int] = Array(repeating: 0, count: maxEntries)

        for idx in 0..<maxEntries {
            let start = base + idx * per
            guard start < bytes else { break }
            // Try to find raceNumber at a few likely small offsets (4, 5, 6)
            var rn = 0
            for off in [4, 5, 6] {
                if start + off < bytes {
                    let v = Int(data.readU8(offset: start + off))
                    if v >= 1 && v <= 99 { rn = v; break }
                }
            }
            numbers[idx] = rn
            // Name: try 48 or 32 bytes slices at common offsets (6, 8, 12)
            var best = ""
            for off in [6, 8, 12] {
                let end48 = min(bytes, start + off + 48)
                if end48 - (start + off) >= 12 {
                    let slice = Array(data[(start + off)..<end48])
                    let trimmed = Array(slice.prefix { $0 != 0 })
                    let decoded = String(bytes: trimmed, encoding: .utf8)
                        ?? String(bytes: trimmed, encoding: .ascii)
                        ?? ""
                    if decoded.count > best.count { best = decoded }
                }
            }
            names[idx] = best.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var mergedNames = self.driverNames
            for i in 0..<maxEntries {
                let cand = names[i]
                if !cand.isEmpty { mergedNames[i] = cand }
            }
            self.driverNames = mergedNames
            if self.raceNumbers.count != maxEntries { self.raceNumbers = Array(repeating: 0, count: maxEntries) }
            for i in 0..<maxEntries {
                if self.raceNumbers[i] == 0 && numbers[i] > 0 { self.raceNumbers[i] = numbers[i] }
            }
            self.publishDriverOrder()
        }
    }

    private func publishDriverOrder() {
        // Recompute-based ordering like the sample: fixed 1..N rows, gaps from cumulative times
        let maxDrivers = min(22, driverNames.count)

        // Build tuples for sorting
        struct Row { let carIdx: Int; let pos: Int; let laps: Int; let cumulative: Int? }
        var rows: [Row] = []
        rows.reserveCapacity(maxDrivers)
        for carIdx in 0..<maxDrivers {
            let pos  = (carIdx < driverPositions.count) ? driverPositions[carIdx] : 99
            let laps = (carIdx < carCompletedLapCountAll.count) ? carCompletedLapCountAll[carIdx] : 0
            let completedSum = (carIdx < carCompletedSumMSAll.count) ? carCompletedSumMSAll[carIdx] : 0
            let live = (carIdx < carCurrentMSAll.count) ? carCurrentMSAll[carIdx] : 0
            let cumulative = (completedSum > 0 || live > 0) ? (completedSum + live) : nil
            rows.append(Row(carIdx: carIdx, pos: (pos == 0 ? 99 : pos), laps: laps, cumulative: cumulative))
        }
        // Sort: position asc → laps desc → cumulative asc
        rows.sort { a, b in
            if a.pos != b.pos { return a.pos < b.pos }
            if a.laps != b.laps { return a.laps > b.laps }
            let ca = a.cumulative ?? Int.max
            let cb = b.cumulative ?? Int.max
            if ca != cb { return ca < cb }
            let ra = (a.carIdx < raceNumbers.count ? raceNumbers[a.carIdx] : 0)
            let rb = (b.carIdx < raceNumbers.count ? raceNumbers[b.carIdx] : 0)
            let rna = (ra == 0 ? Int.max : ra)
            let rnb = (rb == 0 ? Int.max : rb)
            return rna < rnb
        }

        // Map to fixed rows 1..N
        var items: [DriverOrderItem] = []
        items.reserveCapacity(maxDrivers)
        _ = rows.first?.cumulative
        for (i, r) in rows.enumerated() where i < maxDrivers {
            let p = i + 1
            let nameRaw = (r.carIdx < driverNames.count) ? driverNames[r.carIdx] : ""
            let name = nameRaw.isEmpty ? "Driver \(r.carIdx+1)" : nameRaw
            items.append(DriverOrderItem(carIndex: r.carIdx, position: p, name: name, gap: "--", color: .white))
        }

        // Throttle publishes to reduce flicker (max ~5 Hz)
        let now = CACurrentMediaTime()
        if now - lastDriverOrderPublishAt < 0.2 { return }
        lastDriverOrderPublishAt = now
        self.driverOrderItems = items
    }

    // removed old parsePositionsFromLapData

    private func resetTrackBounds() {
        minX = .greatestFiniteMagnitude
        maxX = -.greatestFiniteMagnitude
        minZ = .greatestFiniteMagnitude
        maxZ = -.greatestFiniteMagnitude
        boundsFrozen = false
        frozenMinX = 0; frozenMaxX = 1
        frozenMinZ = 0; frozenMaxZ = 1
        motionFramesObserved = 0
        // Debug reset log disabled
    }
    
    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            if let d = data {
                // Avoid per-packet logging to prevent console I/O latency stalling UI updates
                self?.handle(packet: d)
            } else if let error {
                print("UDP error:", error)
            }
            if error == nil { self?.receive(on: connection) } else { connection.cancel() }
        }
    }

}

private extension Int {
    func nonZeroOr(_ fallback: Int) -> Int { self == 0 ? fallback : self }
}


