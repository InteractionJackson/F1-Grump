import SwiftUI

// MARK: - Reusable Card

struct Card<Content: View>: View {
    let title: String
    let height: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.secondaryEmphasised)
                .foregroundColor(.textPrimary)
            content()
                .foregroundColor(.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading) // fill column width
        .tile(height: height)                               // your existing style
    }
}

// Small helper that applies your “tile” look directly
private extension View {
    func cardChrome(width: CGFloat, height: CGFloat) -> some View {
        self
            .padding(16)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(Color.black.opacity(0.21))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.47), lineWidth: 1)
            )
            .cornerRadius(8)
    }
}

// MARK: - Main screen

struct ContentView: View {
    @StateObject private var rx = TelemetryReceiver()
    #if DEBUG
    private let designPreview: Bool = ProcessInfo.processInfo.environment["DESIGN_PREVIEW"] == "1"
    #endif
    @State private var showSettings = false

    // (kept for your reference)
    private let leftTopRatio: CGFloat = 0.70
    private let rightTopRatio: CGFloat = 0.30

    @State private var allTracks = TrackAssets.allNames()
    @State private var selectedTrack: String = ""
    @State private var outlineSegments: [[CGPoint]] = []

    @State private var demoDamage: [String: CGFloat] = [
        "front_wing_left": 0.2,
        "front_wing_right": 0.6,
        "rear_wing": 0.4,
        "fl_tyre": 0.1,
        "fr_tyre": 0.15,
        "rl_tyre": 0.3,
        "rr_tyre": 0.05
    ]

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(title: "Dashboard") {
                showSettings = true
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 12)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.headerBorder), alignment: .bottom)

            GeometryReader { geo in
                let spacing: CGFloat = 16
                let colW = (geo.size.width - spacing - 48) / 2   // 48 = .padding(24) * 2

                HStack(alignment: .top, spacing: spacing) {
                    leftColumn()            // no width parameter here
                        .frame(width: colW, alignment: .topLeading)

                    rightColumn()
                        .frame(width: colW, alignment: .topLeading)
                }
                .padding(24)
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.appBGStart, .appBGEnd]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
        )
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            rx.start()
            if outlineSegments.isEmpty {
                let name = allTracks.first ?? ""
                selectedTrack = name
                outlineSegments = loadGeoJSONOutline(named: name)
            }
            #if DEBUG
            if designPreview {
                // Force visual states so styles are obvious without live data
                rx.drsOpen = true
                // Overall best < personal best < shown (mix to demo colors)
                rx.overallBestSectorMS = [32000, 62000, 45000]
                rx.bestSectorMS        = [33000, 65000, 47000]
                rx.lastSectorMS        = [32000, 64000, 48000] // S1 fastest (purple), S2 PB (green), S3 over (gold)
            }
            print("DESIGN_PREVIEW=", designPreview)
            #endif
        }
        .onDisappear {
            rx.stop()
        }
        #if DEBUG
        .overlay(alignment: .top) {
            if designPreview {
                Text("Design Preview ON")
                    .font(.caption.weight(.semibold))
                    .padding(6)
                    .background(Color.red.opacity(0.8), in: Capsule())
                    .padding(.top, 8)
            }
        }
        #endif
    }

    // MARK: Left column

    @ViewBuilder
    private func leftColumn() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Card(title: "Car condition & damage", height: 480) {
                ZStack {
                    DamageSVGView(filename: "car_overlay", damage: demoDamage)
                        .padding(12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(contentMode: .fit)

                    // Sample overlay HUD – replace with live data when ready
                    let temps = rx.tyreInnerTemps.map { Int($0) }
                    let cond  = [98, 98, 98, 98]
                    TyreHUD(temps: rx.tyreInnerTemps, condition: rx.tyreWear)
                }
            }

            Card(title: "Speed, RPM, DRS & Gear", height: 272) {
                SpeedRpmTile(rx: rx, rpmRedline: 12000)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    // MARK: Right column
    @ViewBuilder
    private func rightColumn() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Card(title: "Player lap splits", height: 180) {
                LapSplitsView(rx: rx)
            }

            Card(title: "Track position (overhead)", height: 480) {
                TrackOutlineMap(
                    segments: outlineSegments,
                    carPoints: rx.carPoints,
                    playerIndex: rx.playerCarIndex
                )
            }
        }
    }
}

struct TrackPanel: View {
    let outline: [[CGPoint]]
    let others: [CGPoint]
    let player: CGPoint

    var body: some View {
        // Build the dots here, away from the @ViewBuilder that was confusing the types
        let otherCarDots: [TrackDot] = others.map {
            TrackDot(pos: $0, color: .white.opacity(0.65), size: 6)
        }
        let playerDot = TrackDot(pos: player, color: .white, size: 9)

        TrackOverviewView(
            outline: outline,
            dots: otherCarDots + [playerDot]
        )
    }
}

struct SectorPill: View {
    let label: String
    let ms: Int
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Text(label).font(.caption).bold().foregroundColor(color)
            Text(ms > 0 ? fmtLap(ms) : "—:—.—").monospacedDigit().foregroundColor(color)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.progressTrack, in: Capsule())
    }
}

// MARK: - Subviews

struct LapSplitsView: View {
    @ObservedObject var rx: TelemetryReceiver

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current: ").foregroundColor(.textSecondary)
                Text(fmtLap(rx.currentLapMS)).monospacedDigit()
                Spacer()
                Text("Best: ").foregroundColor(.textSecondary)
                Text(fmtLap(rx.bestLapMS)).monospacedDigit()
            }
            HStack {
                Text("Last: ").foregroundColor(.textSecondary)
                Text(fmtLap(rx.lastLapMS)).monospacedDigit()
                Spacer()
                Text("Lap \(rx.lapNumber)").foregroundColor(.textSecondary)
            }
            HStack(spacing: 10) {
                let current = rx.sectorMS
                let last    = rx.lastSectorMS
                let best    = rx.bestSectorMS
                let overall = rx.overallBestSectorMS

                let s1Shown = last[0] > 0 ? last[0] : current[0]
                let s2Shown = last[1] > 0 ? last[1] : current[1]
                let s3Shown = last[2] > 0 ? last[2] : current[2]

                let s1Color: Color = (s1Shown > 0 && overall[0] > 0 && s1Shown <= overall[0]) ? .sectorFastest : ((best[0] > 0 && s1Shown <= best[0]) ? .sectorPersonal : (s1Shown > 0 ? .sectorOver : .textPrimary))
                let s2Color: Color = (s2Shown > 0 && overall[1] > 0 && s2Shown <= overall[1]) ? .sectorFastest : ((best[1] > 0 && s2Shown <= best[1]) ? .sectorPersonal : (s2Shown > 0 ? .sectorOver : .textPrimary))
                let s3Color: Color = (s3Shown > 0 && overall[2] > 0 && s3Shown <= overall[2]) ? .sectorFastest : ((best[2] > 0 && s3Shown <= best[2]) ? .sectorPersonal : (s3Shown > 0 ? .sectorOver : .textPrimary))

                SectorPill(label: "S1", ms: s1Shown, color: s1Color)
                SectorPill(label: "S2", ms: s2Shown, color: s2Color)
                SectorPill(label: "S3", ms: s3Shown, color: s3Color)
            }
        }
    }
}

// --- Track dot + map (unchanged from your version) ---

struct TrackDot: Identifiable {
    let id = UUID()
    let pos: CGPoint
    let color: Color
    let size: CGFloat
}

struct TrackOverviewView: View {
    let outline: [[CGPoint]]
    let dots: [TrackDot]

    var body: some View {
        GeometryReader { _ in
            Canvas { ctx, size in
                guard let bounds = outlineBounds(), bounds.width > 0, bounds.height > 0 else { return }
                let pad: CGFloat = 12
                let rect = CGRect(x: pad, y: pad, width: size.width - 2*pad, height: size.height - 2*pad)
                let t = fitTransform(src: bounds, dst: rect)

                var path = Path()
                for seg in outline where !seg.isEmpty {
                    path.addLines(seg.map { $0.applying(t) })
                }
                ctx.stroke(path, with: .color(Color.white.opacity(0.55)), lineWidth: 1)

                for dot in dots {
                    let p = dot.pos.applying(t)
                    let r = CGRect(x: p.x - dot.size/2, y: p.y - dot.size/2, width: dot.size, height: dot.size)
                    ctx.fill(Circle().path(in: r), with: .color(dot.color))
                    ctx.stroke(Circle().path(in: r), with: .color(Color.black.opacity(0.35)), lineWidth: 1)
                }
            }
        }
    }

    private func outlineBounds() -> CGRect? {
        var r = CGRect.null
        for seg in outline { for p in seg { r = r.union(CGRect(origin: p, size: .zero)) } }
        return r.isNull ? nil : r
    }

    private func fitTransform(src: CGRect, dst: CGRect) -> CGAffineTransform {
        let sx = dst.width / src.width, sy = dst.height / src.height
        let s = min(sx, sy)
        let tx = dst.midX - src.midX * s
        let ty = dst.midY - src.midY * s
        return CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: tx, ty: ty)
    }
}

// MARK: - Misc helpers

func fmtLap(_ ms: Int) -> String {
    guard ms > 0 else { return "—:—.—" }
    let m = ms / 60000
    let s = (ms % 60000) / 1000
    let x = ms % 1000
    return String(format: "%d:%02d.%03d", m, s, x)
}

private extension Array {
    subscript (safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}

// MARK: - Speed/RPM tile (unchanged except Inter font)

struct SpeedRpmTile: View {
    @ObservedObject var rx: TelemetryReceiver
    var rpmRedline: Double = 12000

    private var gearText: String {
        switch rx.gear {
        case -1: return "R"
        case 0:  return "N"
        default: return String(rx.gear)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top row: Speed box, Gear box, DRS toggle
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.headerButtonBorder.opacity(0.6), lineWidth: 1)
                    HStack {
                        Text("\(Int(rx.speedKmh))")
                            .font(.titleEmphasised)
                            .monospacedDigit()
                            .foregroundColor(.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 96)

                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.headerButtonBorder.opacity(0.6), lineWidth: 1)
                        Text(gearText)
                            .font(.titleEmphasised)
                            .foregroundColor(.textPrimary)
                    }
                    .frame(height: 48)

                    Text("DRS")
                        .font(.buttonContent)
                        .foregroundColor(rx.drsOpen ? .drsOpenText : .textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background((rx.drsOpen ? Color.drsOpenBG : Color.buttonBGDefault), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.headerButtonBorder.opacity(0.6), lineWidth: 1))
                }
                .frame(width: 220)
            }

            // MPH full-width gradient gauge
            GaugeBar(label: "MPH",
                     value: min(max(rx.speedKmh * 0.621371 / 240.0, 0), 1),
                     gradient: LinearGradient(colors: [Color.cyan, Color.green, Color.red], startPoint: .leading, endPoint: .trailing))
            .padding(.top, 24)

            // Bottom row: RPM (left), ERS and Fuel (right)
            HStack(spacing: 16) {
                GaugeBar(label: "RPM",
                         value: min(max(rx.rpm / rpmRedline, 0), 1),
                         gradient: LinearGradient(colors: [Color.red, Color.yellow], startPoint: .leading, endPoint: .trailing))
                    .layoutPriority(1)

                VStack(spacing: 16) {
                    GaugeBar(label: "ERS",
                             value: min(max(rx.ersPercent, 0), 1),
                             gradient: LinearGradient(colors: [Color.red, Color.yellow], startPoint: .leading, endPoint: .trailing))
                    GaugeBar(label: "FUEL",
                             value: min(max(rx.fuelPercent, 0), 1),
                             gradient: LinearGradient(colors: [Color.red, Color.green], startPoint: .leading, endPoint: .trailing))
                }
                .frame(width: 320)
            }
        }
        .foregroundColor(.white)
    }
}

// MARK: - Tyre HUD

struct TyreHUD: View {
    /// FL, FR, RL, RR
    let temps: [Int]
    let condition: [Int]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Group {
                tyreLabel(cond: condition[safe:0], temp: temps[safe:0]) // FL
                    .position(x: w * 0.18, y: h * 0.25)
                tyreLabel(cond: condition[safe:1], temp: temps[safe:1]) // FR
                    .position(x: w * 0.82, y: h * 0.25)
                tyreLabel(cond: condition[safe:2], temp: temps[safe:2]) // RL
                    .position(x: w * 0.18, y: h * 0.75)
                tyreLabel(cond: condition[safe:3], temp: temps[safe:3]) // RR
                    .position(x: w * 0.82, y: h * 0.75)
            }
        }
    }

    private func tyreLabel(cond: Int?, temp: Int?) -> some View {
        VStack(spacing: 4) {
            Text("\(cond ?? 0)%")
                .font(.custom("Inter", size: 34).weight(.heavy))
                .kerning(0.5)
            Text("\(temp ?? 0)°")
                .font(.custom("Inter", size: 18).weight(.semibold))
                .monospacedDigit()
                .opacity(0.85)
        }
        .foregroundColor(.white)
    }
}

// MARK: - Header + Settings

struct HeaderView: View {
    let title: String
    var onSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                if UIImage(named: "AppLogo") != nil { Image("AppLogo").resizable().scaledToFit().frame(height: 24) }
                Text(title)
                    .font(.custom("Inter", size: 22).weight(.semibold))
                    .foregroundColor(.textPrimary)
            }
            Spacer()
            Button(action: onSettings) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .imageScale(.medium)
                        .foregroundColor(.headerIcon)
                    Text("Settings")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textPrimary)
                }
                .frame(width: 124, height: 32)
                .background(Color.white.opacity(0.06))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.headerButtonBorder, lineWidth: 1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Gauge bar

struct GaugeBar: View {
    let label: String
    let value: Double   // 0..1
    let gradient: LinearGradient

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.secondaryEmphasised)
                .foregroundColor(.textSecondary)
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.headerButtonBorder.opacity(0.6), lineWidth: 1))
                GeometryReader { geo in
                    let w = max(0, min(1, value)) * geo.size.width
                    RoundedRectangle(cornerRadius: 12)
                        .fill(gradient)
                        .frame(width: max(4, w))
                        .animation(.easeInOut(duration: 0.2), value: value)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)
                }
            }
            .frame(height: 20)
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("General")) {
                    Toggle("Design Preview", isOn: .constant(false))
                    Text("Settings go here")
                }
            }
            .navigationTitle("Settings")
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

