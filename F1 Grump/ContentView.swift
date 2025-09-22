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
    @State private var showSettings = false

    // Persisted settings
    @AppStorage("udpPort") private var udpPort: Int = 20777
    @AppStorage("showCarConditionTile") private var showCarConditionTile: Bool = true
    @AppStorage("showSpeedTile") private var showSpeedTile: Bool = true
    @AppStorage("showSplitsTile") private var showSplitsTile: Bool = true
    @AppStorage("showTrackTile") private var showTrackTile: Bool = true

    // (kept for your reference)
    private let leftTopRatio: CGFloat = 0.70
    private let rightTopRatio: CGFloat = 0.30

    @State private var allTracks = TrackAssets.allNames()
    @State private var selectedTrack: String = ""
    @State private var outlineSegments: [[CGPoint]] = []
    @StateObject private var circuitFetcher = CircuitImageFetcher()
    @State private var speedTileHeight: CGFloat = 0
    @State private var condTileHeight: CGFloat = 0
    @State private var screenPage: Int = 0   // 0: Left+Middle, 1: Middle+Right

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
            HeaderView(title: "") {
                showSettings = true
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 0)

            GeometryReader { geo in
                let spacing: CGFloat = 16
                let containerW = geo.size.width - 48 // account for outer padding
                let colW = (containerW - spacing) / 2 // two columns visible
                let pageShift = colW + spacing        // shift by one column

                VStack(spacing: 0) {
                    ZStack(alignment: .bottom) {
                        // Viewport showing two columns; inner HStack has 3 columns side-by-side
                        HStack(alignment: .top, spacing: spacing) {
                            leftColumn()
                                .frame(width: colW, alignment: .topLeading)
                            rightColumn()
                                .frame(width: colW, alignment: .topLeading)
                            orderColumn()
                                .frame(width: colW, alignment: .topLeading)
                        }
                        .frame(width: containerW, alignment: .topLeading)
                        .offset(x: -CGFloat(screenPage) * pageShift)
                        .animation(.easeInOut(duration: 0.25), value: screenPage)
                        .clipped()

                        // Page dots
                        HStack(spacing: 6) {
                            Circle().fill(screenPage == 0 ? Color.white.opacity(0.9) : Color.white.opacity(0.35)).frame(width: 6, height: 6)
                            Circle().fill(screenPage == 1 ? Color.white.opacity(0.9) : Color.white.opacity(0.35)).frame(width: 6, height: 6)
                        }
                        .padding(.bottom, 8)
                        .accessibilityLabel(Text("Pages"))
                        .accessibilityValue(Text(screenPage == 0 ? "Page 1 of 2" : "Page 2 of 2"))
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .local)
                            .onEnded { value in
                                let dx = value.translation.width
                                if dx < -40 && screenPage < 1 { screenPage += 1 }
                                if dx >  40 && screenPage > 0 { screenPage -= 1 }
                            }
                    )
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
            rx.start(port: UInt16(udpPort))
            if outlineSegments.isEmpty {
                selectedTrack = "Silverstone" // empty-state default
            }
            // Kick off fetching the F1.com circuit image for fallback display
            if let url = URL(string: "https://www.formula1.com/en/racing/2025/italy") {
                circuitFetcher.fetch(from: url)
            }
            
        }
        .onChange(of: udpPort) { _, newPort in
            rx.stop()
            rx.start(port: UInt16(newPort))
        }
        .onChange(of: rx.trackName) { _, newName in
            if !newName.isEmpty {
                selectedTrack = newName
            }
        }
        .onDisappear {
            rx.stop()
        }
        
    }

    // MARK: Left column

    @ViewBuilder
    private func leftColumn() -> some View {
        GeometryReader { colGeo in
            let spacing: CGFloat = 16
            let hAvailable = colGeo.size.height - spacing
            let condH = hAvailable * 0.60
            let speedH = hAvailable * 0.40
            VStack(alignment: .leading, spacing: spacing) {
                if showCarConditionTile {
                    Card(title: "Car condition & damage", height: condH) {
                        CarConditionGrid(temps: rx.tyreInnerTemps, wear: rx.tyreWear, brakes: rx.brakeTemps, damage: rx.overlayDamage)
                    }
                }

                if showSpeedTile {
                    Card(title: "Speed, RPM, DRS & Gear", height: speedH) {
                        VStack(alignment: .leading, spacing: 0) {
                            NewSpeedTile(rx: rx, rpmRedline: 12000)
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .background(
                                    GeometryReader { proxy in
                                        Color.clear
                                            .onAppear { speedTileHeight = proxy.size.height }
                                            .onChange(of: proxy.size.height) { _, new in speedTileHeight = new }
                                    }
                                )
                        }
                    }
                }
            }
        }
    }

    // MARK: Right column
    @ViewBuilder
    private func rightColumn() -> some View {
        GeometryReader { colGeo in
            let spacing: CGFloat = 16
            let hAvailable = colGeo.size.height - spacing
            let hTop = hAvailable * 0.40
            let hBottom = hAvailable * 0.60
            VStack(alignment: .leading, spacing: spacing) {
                if showSplitsTile {
                    Card(title: "Splits", height: hTop) {
                        LapSplitsView(rx: rx)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }

                if showTrackTile {
                    Card(title: "Circuit map", height: hBottom) {
                        GeometryReader { g in
                            let side = min(g.size.width, g.size.height) * 0.95
                            ZStack {
                                TrackSVGView(
                                    filename: selectedTrack.isEmpty ? "Silverstone" : selectedTrack,
                                    carPoints: rx.carPoints,
                                    playerIndex: rx.playerCarIndex
                                )
                                if let ui = circuitFetcher.image, outlineSegments.isEmpty {
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFit()
                                        .opacity(0.0)
                                }
                            }
                            .frame(width: side, height: side)
                            .position(x: g.size.width / 2, y: g.size.height / 2)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Order column (rightmost)
    @ViewBuilder
    private func orderColumn() -> some View {
        GeometryReader { colGeo in
            VStack(alignment: .leading, spacing: 16) {
                Card(title: "Driver order", height: colGeo.size.height) {
                    DriverOrderListView(items: rx.driverOrderItems)
                }
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
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Top row: current lap box (100%) containing sector splits inside
                    VStack(spacing: 0) {
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

                        CurrentLapBox(timeMS: rx.currentLapMS,
                                      s1: s1Shown, s2: s2Shown, s3: s3Shown,
                                      c1: s1Color, c2: s2Color, c3: s3Color)
                            .frame(maxWidth: .infinity)
                    }

                    // Bottom row: LAST and BEST side-by-side (50/50)
                    HStack(spacing: 16) {
                        SmallBoxedTime(titleBelow: "LAST", timeMS: rx.lastLapMS)
                            .frame(maxWidth: .infinity)
                        SmallBoxedTime(titleBelow: "BEST", timeMS: rx.bestLapMS)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Splits helpers

private struct BoxedTime: View {
    let titleBelow: String
    let timeMS: Int
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.tileBG)
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.tileBorder, lineWidth: 1)
            HStack(spacing: 8) {
                Text(titleBelow)
                    .font(.gaugeLabel)
                    .foregroundColor(.labelEmphasised)
                    .kerning(0.9)
                Spacer()
                Text(fmtLap(timeMS))
                    .font(.titleEmphasised)
                    .monospacedDigit()
                    .foregroundColor(.textPrimary)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 88)
    }
}

// Current lap box including inner sector splits row
private struct CurrentLapBox: View {
    let timeMS: Int
    let s1: Int
    let s2: Int
    let s3: Int
    let c1: Color
    let c2: Color
    let c3: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.headerButtonBorder.opacity(0.6), lineWidth: 1)
            VStack(alignment: .leading, spacing: 8) {   // 8px between rows
                HStack(spacing: 8) {
                    Text("CURRENT LAP")
                        .font(.gaugeLabel)
                        .foregroundColor(.labelEmphasised)
                        .kerning(0.9)
                    Spacer()
                    Text(fmtLap(timeMS))
                        .font(.titleEmphasised)
                        .monospacedDigit()
                        .foregroundColor(.textPrimary)
                }
                HStack(spacing: 8) {                      // 8px between sector boxes
                    SectorBox(titleBelow: "S1", timeMS: s1, color: c1)
                        .frame(maxWidth: .infinity)
                    SectorBox(titleBelow: "S2", timeMS: s2, color: c2)
                        .frame(maxWidth: .infinity)
                    SectorBox(titleBelow: "S3", timeMS: s3, color: c3)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(16)                                    // 16px inner border padding
        }
    }
}

private struct SmallBoxedTime: View {
    let titleBelow: String
    let timeMS: Int
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.tileBG)
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.tileBorder, lineWidth: 1)
            HStack(spacing: 8) {
                Text(titleBelow)
                    .font(.gaugeLabel)
                    .foregroundColor(.labelEmphasised)
                    .kerning(0.9)
                Spacer()
                Text(fmtLap(timeMS))
                    .font(.body18)
                    .kerning(1.62)
                    .monospacedDigit()
                    .foregroundColor(.textPrimary)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 32)
    }
}

private struct SectorBox: View {
    let titleBelow: String
    let timeMS: Int
    let color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.tileBG)
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.tileBorder, lineWidth: 1)
            HStack(spacing: 8) {
                Text(titleBelow)
                    .font(.gaugeLabel)
                    .foregroundColor(.labelEmphasised)
                    .kerning(0.9)
                Spacer()
                Text(timeMS > 0 ? fmtLap(timeMS) : "—:—.—")
                    .font(.body18)
                    .kerning(1.62)
                    .monospacedDigit()
                    .foregroundColor(color)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 32)
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

// MARK: - Driver Order Paged Grid (mock/demo)

struct DriverOrderItem: Identifiable, Hashable {
    let carIndex: Int
    var id: Int { carIndex }
    let position: Int
    let name: String
    let gap: String
    let color: Color

    static func mock60() -> [DriverOrderItem] {
        let teams: [Color] = [.red, .yellow, .green, .cyan, .blue, .purple, .orange, .pink, .teal, .mint]
        var items: [DriverOrderItem] = []
        for i in 1...60 {
            let gap = i == 1 ? "LEADER" : String(format: "+%d.%ds", i / 2, i % 10)
            items.append(DriverOrderItem(carIndex: i-1, position: i, name: "Hamilton", gap: gap, color: teams[i % teams.count]))
        }
        return items
    }
}

struct DriverOrderPagedGridView: View {
    let items: [DriverOrderItem]
    @Environment(\.sizeCategory) private var sizeCategory
    @FocusState private var focusedId: UUID?

    var body: some View {
        GeometryReader { geo in
            let columnsPerPage = 2
            let rows = max(1, Int((geo.size.height - 32) / 64))
            let perPage = max(1, rows * columnsPerPage)
            let pages = stride(from: 0, to: items.count, by: perPage).map { start -> ArraySlice<DriverOrderItem> in
                let end = min(start + perPage, items.count)
                return items[start..<end]
            }

            TabView {
                ForEach(Array(pages.enumerated()), id: \.offset) { _, pageItems in
                    DriverOrderGridPage(items: Array(pageItems), rows: rows)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
}

private struct DriverOrderGridPage: View {
    let items: [DriverOrderItem]
    let rows: Int

    var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(items) { item in
                    DriverOrderCell(item: item)
                }
            }
            .padding(16)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Driver order"))
    }
}

private struct DriverOrderCell: View {
    let item: DriverOrderItem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.tileBG)
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.tileBorder, lineWidth: 1)
            HStack(spacing: 10) {
                Text("\(item.position)")
                    .font(.gaugeLabel)
                    .foregroundColor(.labelEmphasised)
                    .kerning(0.9)
                    .frame(width: 26, alignment: .trailing)
                Circle().fill(item.color).frame(width: 10, height: 10)
                Text(item.name)
                    .font(.body18)
                    .kerning(1.62)
                Spacer()
                Text(item.gap)
                    .font(.body18)
                    .kerning(1.0)
                    .foregroundColor(.textPrimary)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
        }
        .frame(height: 32)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(item.position). \(item.name). Gap: \(item.gap)"))
    }
}

// Single-column stacked leaderboard
struct DriverOrderListView: View {
    let items: [DriverOrderItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                Text("Pos").font(.secondaryEmphasised).foregroundColor(.labelEmphasised).frame(width: 44, alignment: .leading)
                Text("Driver").font(.secondaryEmphasised).foregroundColor(.labelEmphasised)
                Spacer()
                Text("Split").font(.secondaryEmphasised).foregroundColor(.labelEmphasised)
            }
            Divider().background(Color.headerButtonBorder.opacity(0.6))

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.1.id) { idx, item in
                        ZStack {
                            (idx % 2 == 1 ? AnyView(Rectangle().fill(Color.white.opacity(0.05))) : AnyView(Rectangle().fill(Color.clear)))
                            DriverOrderListRow(item: item)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Driver order"))
    }
}

private struct DriverOrderListRow: View {
    let item: DriverOrderItem

    var body: some View {
        ZStack {
            Rectangle().fill(Color.clear)
            HStack(spacing: 12) {
                Text("\(item.position)")
                    .font(.body18)
                    .foregroundColor(.textPrimary)
                    .frame(width: 44, alignment: .leading)
                Text(item.name)
                    .font(.body18)
                    .foregroundColor(.textPrimary)
                Spacer()
                Text(item.position == 1 ? "--" : item.gap)
                    .font(.body18)
                    .foregroundColor(.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.08)))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.headerButtonBorder.opacity(0.6), lineWidth: 1))
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(item.position). Driver \(item.name). Split \(item.position == 1 ? "leader" : item.gap)"))
    }
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
                    // Inner tile style: bg 3% white, 1pt 8% white border, 8pt radius
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.tileBG)
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.tileBorder, lineWidth: 1)
                    HStack(spacing: 8) {
                        Text("MPH")
                            .font(.gaugeLabel)
                            .foregroundColor(.labelEmphasised)
                            .kerning(0.9)
                        Spacer()
                        Text("\(Int(rx.speedKmh))")
                            .font(.titleEmphasised)
                            .monospacedDigit()
                            .foregroundColor(.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
                .frame(height: 68)

                VStack(spacing: 4) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.tileBG)
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.tileBorder, lineWidth: 1)
                        HStack {
                            Text("Gear")
                                .font(.gaugeLabel)
                                .foregroundColor(.labelEmphasised)
                                .kerning(0.9)
                            Spacer()
                            Text(gearText)
                                .font(.body18)
                                .kerning(1.62)
                                .foregroundColor(.textPrimary)
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(height: 32)

                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(rx.drsOpen ? Color.drsOpenBG : Color.tileBG)
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.tileBorder, lineWidth: 1)
                        HStack {
                            Text("DRS")
                                .font(.gaugeLabel)
                                .foregroundColor(rx.drsOpen ? .drsOpenText : .labelEmphasised)
                                .kerning(0.9)
                            Spacer()
                            Text(rx.drsOpen ? "OPEN" : "CLOSED")
                                .font(.body18)
                                .kerning(1.62)
                                .foregroundColor(rx.drsOpen ? .drsOpenText : .textPrimary)
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(height: 32)
                }
                .frame(width: 220)
            }

            // RPM full-width row (spaced from the speed row)
            GaugeBar(label: "RPM",
                     value: min(max(rx.rpm / rpmRedline, 0), 1),
                     gradient: LinearGradient(colors: [Color.red, Color.yellow], startPoint: .leading, endPoint: .trailing))
            .padding(.top, 16)

            // ERS and Fuel 50/50 row
            HStack(spacing: 16) {
                GaugeBar(label: "ERS",
                         value: min(max(rx.ersPercent, 0), 1),
                         gradient: LinearGradient(colors: [Color.yellow], startPoint: .leading, endPoint: .trailing))
                    .frame(maxWidth: .infinity)
                GaugeBar(label: "FUEL",
                         value: min(max(rx.fuelPercent, 0), 1),
                         gradient: LinearGradient(colors: [Color.green], startPoint: .leading, endPoint: .trailing))
                    .frame(maxWidth: .infinity)
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

// MARK: - Car condition grid

struct CarConditionGrid: View {
    // Temps in °C, wear in % (0-100) per FL, FR, RL, RR
    let temps: [Int]
    let wear: [Int]
    let brakes: [Int]
    let damage: [String: CGFloat]

    var body: some View {
        GeometryReader { geo in
            let colSpacing: CGFloat = 24
            let carW: CGFloat = 80
            let sideW = max(0, (geo.size.width - carW - 2 * colSpacing) / 2)
            ZStack { // keep car centered across the whole tile
                // Centered car overlay
                GeometryReader { g in
                    DamageSVGView(filename: "car_overlay", damage: damage)
                        .frame(width: 80, height: 200)
                        .aspectRatio(contentMode: .fit)
                        .position(x: g.size.width / 2, y: g.size.height / 2)
                }
                // Side stacks with fixed equal widths
                HStack(alignment: .center, spacing: colSpacing) {
                    // Left column should show REAR LEFT above FRONT LEFT
                    VStack(spacing: 24) {
                        TyreStack(wear: wear[safe:2] ?? 0, temp: temps[safe:2] ?? 0, brake: brakes[safe:2] ?? 0) // RL
                        TyreStack(wear: wear[safe:0] ?? 0, temp: temps[safe:0] ?? 0, brake: brakes[safe:0] ?? 0) // FL
                    }
                    .frame(width: sideW)

                    Color.clear.frame(width: carW) // placeholder space for the car

                    // Right column should show REAR RIGHT above FRONT RIGHT
                    VStack(spacing: 24) {
                        TyreStack(wear: wear[safe:3] ?? 0, temp: temps[safe:3] ?? 0, brake: brakes[safe:3] ?? 0) // RR
                        TyreStack(wear: wear[safe:1] ?? 0, temp: temps[safe:1] ?? 0, brake: brakes[safe:1] ?? 0) // FR
                    }
                    .frame(width: sideW)
                }
            }
        }
    }
}

private struct TyreStack: View {
    let wear: Int
    let temp: Int
    let brake: Int
    var body: some View {
        VStack(spacing: 8) {
            TyreRow(label: "WEAR", value: "\(wear)%")
            TyreRow(label: "TEMP", value: "\(temp)°")
            TyreRow(label: "BRAKES", value: "\(brake)°")
        }
    }
}

private struct TyreRow: View {
    let label: String
    let value: String?
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.tileBG)
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.tileBorder, lineWidth: 1)
            HStack(spacing: 8) {
                if value != nil { // omit location label rows entirely
                    Text(label)
                        .font(.gaugeLabel)
                        .foregroundColor(.labelEmphasised)
                        .kerning(0.9)
                }
                Spacer()
                if let v = value {
                    Text(v)
                        .font(.body18)
                        .kerning(1.62)
                        .foregroundColor(.textPrimary)
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 32)
    }
}

// MARK: - Header + Settings

struct HeaderView: View {
    let title: String
    var onSettings: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                AppLogoView().frame(height: 48)
                if !title.isEmpty {
                    Text(title)
                        .font(.custom("Inter", size: 22).weight(.semibold))
                        .foregroundColor(.textPrimary)
                }
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
        .frame(height: 48)
    }
}

// MARK: - Gauge bar

struct GaugeBar: View {
    let label: String
    let value: Double   // 0..1
    let gradient: LinearGradient

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
            Text(label)
                .font(.gaugeLabel)
                .foregroundColor(.labelEmphasised)
                .kerning(0.9)
        }
    }
}

struct SettingsView: View {
    @AppStorage("udpPort") private var udpPort: Int = 20777
    @AppStorage("showCarConditionTile") private var showCarConditionTile: Bool = true
    @AppStorage("showSpeedTile") private var showSpeedTile: Bool = true
    @AppStorage("showSplitsTile") private var showSplitsTile: Bool = true
    @AppStorage("showTrackTile") private var showTrackTile: Bool = true
    @State private var portText: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("General")) {
                    Toggle("Design Preview", isOn: .constant(false))
                }
                Section(header: Text("Telemetry")) {
                    HStack {
                        Text("UDP Port")
                        Spacer()
                        TextField("20777", text: Binding(
                            get: { portText.isEmpty ? String(udpPort) : portText },
                            set: { portText = $0 }
                        ))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { applyPort() }
                        .onDisappear { applyPort() }
                        .frame(width: 100)
                    }
                }
                Section(header: Text("Visible Tiles")) {
                    Toggle("Car condition & damage", isOn: $showCarConditionTile)
                    Toggle("Speed, RPM, DRS & Gear", isOn: $showSpeedTile)
                    Toggle("Splits", isOn: $showSplitsTile)
                    Toggle("Circuit map / Driver order", isOn: $showTrackTile)
                }
            }
            .navigationTitle("Settings")
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private func applyPort() {
        if let p = Int(portText), p > 0 && p < 65536 { udpPort = p }
        portText = ""
    }
}

// MARK: - App Logo provider

struct AppLogoView: View {
    var body: some View {
        if let ui = AppLogoProvider.loadLogoImage() {
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
        }
    }
}

enum AppLogoProvider {
    static func loadLogoImage() -> UIImage? {
        // 1) Prefer an asset named "AppLogo"
        if let fromAssets = UIImage(named: "AppLogo") { return fromAssets }
        // 1b) Prefer bundled PNG named AppLogo (in assets/ or root)
        if let url = Bundle.main.url(forResource: "AppLogo", withExtension: "png", subdirectory: "assets")
              ?? Bundle.main.url(forResource: "AppLogo", withExtension: "png") {
            if let data = try? Data(contentsOf: url), let img = UIImage(data: data) { return img }
        }
        // 2) Try common filenames in bundle subdirectory "assets" (project has PNGs there)
        let candidates = [
            "logo", "Logo", "app_logo",
            "Icon-Light-1024x1024", "Icon-Dark-1024x1024", "Icon-Tinted-1024x1024"
        ]
        for name in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "assets"),
               let data = try? Data(contentsOf: url),
               let img = UIImage(data: data) {
                return img
            }
        }
        // 3) Fallback to any PNG named "splash" in assets
        if let url = Bundle.main.url(forResource: "splash", withExtension: "png", subdirectory: "assets"),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            return img
        }
        return nil
    }

    static func hasSVG() -> Bool { false }
}

// SVG fallback removed; using PNG or asset image instead


// MARK: - New Speed Tile with Dual Rings

struct NewSpeedTile: View {
    @ObservedObject var rx: TelemetryReceiver
    var rpmRedline: Double = 12000

    private var mphText: String {
        let mph = rx.speedKmh * 0.621371
        return String(Int(mph.rounded()))
    }

    private var gearText: String {
        switch rx.gear {
        case -1: return "R"
        case 0:  return "N"
        default: return String(rx.gear)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                // Left: Speed
                VStack(spacing: 4) {
                    Text(mphText)
                        .font(.title40)
                        .foregroundColor(.textPrimary)
                        .monospacedDigit()
                    Text("MPH")
                        .font(.gaugeLabel)
                        .foregroundColor(.labelEmphasised)
                        .kerning(0.9)
                }
                .frame(width: 120, alignment: .center)

                // Center: Rings
                TelemetryRings(
                    rpm: CGFloat(max(0, min(1, rx.rpm / max(1, rpmRedline)))) ,
                    ers: CGFloat(max(0, min(1, rx.ersPercent)))
                )
                .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 200)

                // Right: Gear
                VStack(spacing: 4) {
                    Text(gearText)
                        .font(.title40)
                        .foregroundColor(.textPrimary)
                    Text("GEAR")
                        .font(.gaugeLabel)
                        .foregroundColor(.labelEmphasised)
                        .kerning(0.9)
                }
                .frame(width: 120, alignment: .center)
            }

            // Bottom bars + DRS pill
            HStack(alignment: .center, spacing: 16) {
                CapsuleBar(
                    label: "Brake",
                    track: Color(.sRGB, red: 0.25, green: 0.12, blue: 0.16, opacity: 0.6),
                    fill: Color(.sRGB, red: 1.00, green: 0.30, blue: 0.40, opacity: 1.0),
                    value: max(0, min(1, rx.brake)),
                    showDot: true,
                    reversed: true
                )
                .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 22)

                DRSChip()

                CapsuleBar(
                    label: "Throttle",
                    track: Color(.sRGB, red: 0.18, green: 0.18, blue: 0.18, opacity: 0.7),
                    fill: Color(.sRGB, red: 0.72, green: 1.00, blue: 0.30, opacity: 1.0),
                    value: Double(max(0, min(1, rx.throttle))),
                    showDot: false
                )
                .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 22)
            }
        }
    }
}

private struct DRSChip: View {
    var body: some View {
        Text("DRS")
            .font(.gaugeLabel)
            .foregroundColor(.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06), in: Capsule())
            .overlay(
                Capsule().stroke(Color.headerButtonBorder.opacity(0.6), lineWidth: 1)
            )
    }
}

private struct CapsuleBar: View {
    let label: String
    let track: Color
    let fill: Color
    let value: Double   // 0..1
    let showDot: Bool
    var reversed: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Capsule()
                    .fill(track)
                GeometryReader { geo in
                    let w = max(0, min(1, value)) * geo.size.width
                    if reversed {
                        // Fill from right to left
                        ZStack(alignment: .leading) {
                            Spacer(minLength: 0)
                            Capsule()
                                .fill(fill)
                                .frame(width: max(6, w))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .scaleEffect(x: -1, y: 1, anchor: .center)
                                .scaleEffect(x: -1, y: 1, anchor: .center)
                            if showDot {
                                Circle()
                                    .fill(fill)
                                    .frame(width: 10, height: 10)
                                    .offset(x: 3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: value)
                    } else {
                        ZStack(alignment: .trailing) {
                            Capsule()
                                .fill(fill)
                                .frame(width: max(6, w))
                            if showDot {
                                Circle()
                                    .fill(fill)
                                    .frame(width: 10, height: 10)
                                    .offset(x: -3)
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: value)
                    }
                }
            }
            .frame(height: 12)

            Text(label)
                .font(.gaugeLabel)
                .foregroundColor(.labelEmphasised)
                .kerning(0.9)
        }
    }
}

// MARK: - Telemetry Rings (RPM segmented + ERS continuous)
struct TelemetryRings: View {
    var rpm: CGFloat  // 0..1
    var ers: CGFloat  // 0..1

    private let startAngle: Angle = .degrees(-210)
    private let endAngle: Angle   = .degrees(30)
    private let sweep: CGFloat = 240

    private let rpmWidth: CGFloat = 18
    private let ersWidth: CGFloat = 18
    private let ringGap: CGFloat  = 12

    private let t1: CGFloat = 0.60
    private let t2: CGFloat = 0.80
    private let t3: CGFloat = 1.00

    var body: some View {
        GeometryReader { geo in
            let minSide = min(geo.size.width, geo.size.height)
            let outerR  = minSide / 2
            let ersR    = outerR - rpmWidth - ringGap
            // Desired physical gap between RPM segments in points
            let gapPx: CGFloat = 2
            // Convert to fraction of the total sweep
            let gapDeg = (gapPx / outerR) * 180 / .pi
            let gapFrac = gapDeg / sweep
            let halfGap = gapFrac / 2

            ZStack {
                // Track ring (subtle background under RPM)
                Arc(start: startAngle, end: endAngle)
                    .stroke(Color(hex: "#BCEBFF").opacity(0.2), style: StrokeStyle(lineWidth: rpmWidth, lineCap: .round))
                    .frame(width: outerR*2, height: outerR*2)

                // Inner ERS track ring so two arcs are visible even at 0%
                Arc(start: startAngle, end: endAngle)
                    .stroke(Color(hex: "#EF9D00").opacity(0.2), style: StrokeStyle(lineWidth: ersWidth, lineCap: .round))
                    .frame(width: ersR*2, height: ersR*2)

                // RPM segments with 2pt gaps between them
                // First segment: linear gradient #0098EF → #BCEBFF @ 40°
                let gp = gradientPoints(degrees: 40)
                rpmSegment(start: 0.0, end: max(0, t1 - halfGap), value: rpm, radius: outerR, capRadius: 4, drawStartDot: true, drawEndDot: false)
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "#0098EF"), Color(hex: "#BCEBFF")], startPoint: gp.start, endPoint: gp.end))
                rpmSegment(start: min(1, t1 + halfGap), end: max(0, t2 - halfGap), value: rpm, radius: outerR, capRadius: 4, drawStartDot: false, drawEndDot: false)
                    .foregroundColor(Color(hex: "#F6C737"))
                rpmSegment(start: min(1, t2 + halfGap), end: t3, value: rpm, radius: outerR, capRadius: 4, drawStartDot: false, drawEndDot: true)
                    .foregroundColor(Color(hex: "#FF3B58"))

                // ERS ring
                // ERS with custom small end-caps
                ZStack {
                    Arc(start: startAngle, end: angle(for: ers))
                        .stroke(LinearGradient(colors: [Color(hex: "#EF9D00"), Color(hex: "#FFEE32")], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: ersWidth, lineCap: .butt))
                        .frame(width: ersR*2, height: ersR*2)
                    // Cap dots (8pt diameter for 4pt radius)
                    CapDots(radius: ersR, start: startAngle, end: angle(for: ers), diameter: 8)
                        .foregroundStyle(LinearGradient(colors: [Color(hex: "#EF9D00"), Color(hex: "#FFEE32")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: ersR*2, height: ersR*2)
                }
                .shadow(color: Color(hex: "#EF9D00").opacity(0.25), radius: 8, x: 0, y: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.2), value: rpm)
            .animation(.easeInOut(duration: 0.2), value: ers)
        }
    }

    @ViewBuilder
    private func rpmSegment(start segStart: CGFloat, end segEnd: CGFloat, value: CGFloat, radius: CGFloat, capRadius: CGFloat, drawStartDot: Bool = true, drawEndDot: Bool = true) -> some View {
        let filledEnd = min(max(0, value), segEnd)
        if filledEnd > segStart {
            ZStack {
                Arc(start: angle(for: segStart), end: angle(for: filledEnd))
                    .stroke(style: StrokeStyle(lineWidth: rpmWidth, lineCap: .butt))
                    .frame(width: radius*2, height: radius*2)
                CapDots(radius: radius, start: angle(for: segStart), end: angle(for: filledEnd), diameter: capRadius * 2, drawStart: drawStartDot, drawEnd: drawEndDot)
                    .frame(width: radius*2, height: radius*2)
            }
        }
    }

    private func angle(for progress: CGFloat) -> Angle {
        let clamped = max(0, min(1, progress))
        let degrees = -210 + sweep * clamped
        return .degrees(degrees)
    }
}

// Basic arc shape for ring segments
struct Arc: Shape {
    var start: Angle
    var end: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var p = Path()
        p.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        return p
    }
}

private func gradientPoints(degrees: Double) -> (start: UnitPoint, end: UnitPoint) {
    let norm = fmod((degrees < 0 ? degrees + 360 : degrees), 360)
    switch norm {
    case 22.5..<67.5: return (.topLeading, .bottomTrailing)
    case 67.5..<112.5: return (.top, .bottom)
    case 112.5..<157.5: return (.topTrailing, .bottomLeading)
    case 157.5..<202.5: return (.trailing, .leading)
    case 202.5..<247.5: return (.bottomTrailing, .topLeading)
    case 247.5..<292.5: return (.bottom, .top)
    case 292.5..<337.5: return (.bottomLeading, .topTrailing)
    default: return (.leading, .trailing)
    }
}

// Hex color helper
private struct CapDots: View {
    let radius: CGFloat
    let start: Angle
    let end: Angle
    let diameter: CGFloat
    var drawStart: Bool = true
    var drawEnd: Bool = true

    private func point(on radius: CGFloat, angle: Angle, in rect: CGRect) -> CGPoint {
        let rads = CGFloat(angle.radians)
        let cx = rect.midX
        let cy = rect.midY
        return CGPoint(x: cx + radius * cos(rads), y: cy + radius * sin(rads))
    }

    var body: some View {
        GeometryReader { geo in
            let rect = geo.frame(in: .local)
            let p0 = point(on: min(rect.width, rect.height) / 2, angle: start, in: rect)
            let p1 = point(on: min(rect.width, rect.height) / 2, angle: end, in: rect)
            ZStack {
                if drawStart {
                    Circle().frame(width: diameter, height: diameter).position(p0)
                }
                if drawEnd {
                    Circle().frame(width: diameter, height: diameter).position(p1)
                }
            }
        }
    }
}

// Hex color helper
extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var i: UInt64 = 0
        Scanner(string: s).scanHexInt64(&i)
        let r = Double((i >> 16) & 0xFF) / 255
        let g = Double((i >> 8) & 0xFF) / 255
        let b = Double(i & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

