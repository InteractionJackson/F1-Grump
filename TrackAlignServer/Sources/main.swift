import Foundation
import NIO
import NIOHTTP1

// MARK: - 2D Math layer
struct Vec2 { var x: Double; var y: Double }

struct Affine2 {
    var a: Double, b: Double, c: Double, d: Double, tx: Double, ty: Double
    static let identity = Affine2(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    func apply(_ p: Vec2) -> Vec2 {
        Vec2(x: a * p.x + c * p.y + tx, y: b * p.x + d * p.y + ty)
    }

    static func translation(_ t: Vec2) -> Affine2 { .init(a: 1, b: 0, c: 0, d: 1, tx: t.x, ty: t.y) }
    static func scale(_ sx: Double, _ sy: Double) -> Affine2 { .init(a: sx, b: 0, c: 0, d: sy, tx: 0, ty: 0) }
    static func rotation(deg: Double) -> Affine2 {
        let r = deg * .pi / 180
        let cosr = cos(r), sinr = sin(r)
        return .init(a: cosr, b: sinr, c: -sinr, d: cosr, tx: 0, ty: 0)
    }
    static func flipY() -> Affine2 { .scale(1, -1) }

    // self • o (apply o first, then self)
    func composed(with o: Affine2) -> Affine2 {
        Affine2(
            a: a * o.a + c * o.b,
            b: b * o.a + d * o.b,
            c: a * o.c + c * o.d,
            d: b * o.c + d * o.d,
            tx: a * o.tx + c * o.ty + tx,
            ty: b * o.tx + d * o.ty + ty
        )
    }
}

// MARK: - Track alignment store
struct TrackAlign {
    var T: Affine2 = .identity

    mutating func setRotation90CW(around center: Vec2 = .init(x: 0.5, y: 0.5)) {
        let pre = Affine2.translation(Vec2(x: -center.x, y: -center.y))
        let rot = Affine2.rotation(deg: -90)
        let post = Affine2.translation(center)
        T = post.composed(with: rot).composed(with: pre).composed(with: T)
    }
}
var trackAlign = TrackAlign()

// MARK: - Demo TrackProjector and data model shims
struct TrackProjector {
    // These would be learned bounds; for demo, keep defaults
    static var minX: Double = -100
    static var maxX: Double =  100
    static var minZ: Double = -100
    static var maxZ: Double =  100

    static func toUnit(_ wx: Double, _ wz: Double) -> (Float?, Float?) {
        let dx = max(1e-6, maxX - minX)
        let dz = max(1e-6, maxZ - minZ)
        let u = (wx - minX) / dx
        let v = (wz - minZ) / dz
        guard u.isFinite, v.isFinite else { return (nil, nil) }
        return (Float(u), Float(v))
    }
}

// Simulated unit points for auto-rotation scoring (should be trackBuilder.unitPoints)
var unitOutline: [Vec2] = [
    Vec2(x: 0.1, y: 0.1), Vec2(x: 0.9, y: 0.1), Vec2(x: 0.9, y: 0.9), Vec2(x: 0.1, y: 0.9)
]

// MARK: - Mapping helper (world -> unit -> UI -> affine)
func mapToUI(u: Float?, v: Float?) -> (Float?, Float?) {
    guard let rawU = u, let rawV = v else { return (nil, nil) }
    let uiU = Double(rawU)
    let uiV = Double(rawV) // caller can pre-flip if needed
    let p = Vec2(x: uiU, y: uiV)
    let tp = trackAlign.T.apply(p)
    // Clamp for rendering safety, but do not lose the underlying values
    let cx = min(2.0, max(-1.0, tp.x))
    let cy = min(2.0, max(-1.0, tp.y))
    return (Float(cx), Float(cy))
}

// MARK: - Auto-snap rotations
func tryRotationsAndPickBest(rotations: [Double] = [0, 90, 180, 270], sample: [Vec2]) -> Double {
    guard !sample.isEmpty else { return 0 }
    var bestDeg = 0.0
    var bestScore = Double.greatestFiniteMagnitude
    let ctr = Vec2(x: 0.5, y: 0.5)
    for deg in rotations {
        let T = Affine2.translation(ctr)
            .composed(with: .rotation(deg: -deg))
            .composed(with: .translation(Vec2(x: -ctr.x, y: -ctr.y)))
        var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9
        for p in sample {
            let q = T.apply(p)
            if q.x < minX { minX = q.x }
            if q.x > maxX { maxX = q.x }
            if q.y < minY { minY = q.y }
            if q.y > maxY { maxY = q.y }
        }
        let area = (maxX - minX) * (maxY - minY)
        if area < bestScore {
            bestScore = area
            bestDeg = deg
        }
    }
    return bestDeg
}

// Log first 5 transformed points after rotation changes
func logTransformedSample(prefix: String) {
    let sample = unitOutline.prefix(5)
    let pts = sample.map { p -> String in
        let q = trackAlign.T.apply(p)
        return String(format: "(%.3f, %.3f)", q.x, q.y)
    }
    print("\(prefix):", pts.joined(separator: ", "))
}

// MARK: - Server
final class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)
        switch reqPart {
        case .head(let head):
            if head.uri.hasPrefix("/calib") {
                handleCalib(head: head, context: context)
            } else {
                simpleOK(context: context, body: "{\"ok\":true}")
            }
        case .body: break
        case .end: break
        }
    }

    private func simpleOK(context: ChannelHandlerContext, body: String) {
        var headers = HTTPHeaders()
        headers.add(name: "content-type", value: "application/json")
        headers.add(name: "content-length", value: String(body.utf8.count))
        context.write(self.wrapOutboundOut(.head(HTTPResponseHead(version: .http1_1, status: .ok, headers: headers))), promise: nil)
        var buf = context.channel.allocator.buffer(capacity: body.utf8.count)
        buf.writeString(body)
        context.write(self.wrapOutboundOut(.body(.byteBuffer(buf))), promise: nil)
        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
    }

    private func handleCalib(head: HTTPRequestHead, context: ChannelHandlerContext) {
        // Parse query params
        let url = URL(string: head.uri) ?? URL(string: "http://x/")!
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var params: [String: String] = [:]
        comps?.queryItems?.forEach { params[$0.name] = $0.value }

        let center = Vec2(x: 0.5, y: 0.5)
        var changed = false

        if params["reset"] == "true" { trackAlign.T = .identity; changed = true }

        if let rotStr = params["rotate"], let deg = Double(rotStr), [0.0,90.0,180.0,270.0].contains(deg) {
            let pre = Affine2.translation(Vec2(x: -center.x, y: -center.y))
            let rot = Affine2.rotation(deg: -deg)
            let post = Affine2.translation(center)
            trackAlign.T = post.composed(with: rot).composed(with: pre).composed(with: trackAlign.T)
            changed = true
        }
        if params["flipY"] == "true" {
            let pre = Affine2.translation(Vec2(x: -center.x, y: -center.y))
            let flip = Affine2.flipY()
            let post = Affine2.translation(center)
            trackAlign.T = post.composed(with: flip).composed(with: pre).composed(with: trackAlign.T)
            changed = true
        }
        if let sStr = params["scale"], let s = Double(sStr), s.isFinite, s > 0 {
            let pre = Affine2.translation(Vec2(x: -center.x, y: -center.y))
            let sc = Affine2.scale(s, s)
            let post = Affine2.translation(center)
            trackAlign.T = post.composed(with: sc).composed(with: pre).composed(with: trackAlign.T)
            changed = true
        }
        var tx: Double = 0, ty: Double = 0
        if let txStr = params["tx"], let v = Double(txStr) { tx = v }
        if let tyStr = params["ty"], let v = Double(tyStr) { ty = v }
        if tx != 0 || ty != 0 {
            trackAlign.T = Affine2.translation(Vec2(x: tx, y: ty)).composed(with: trackAlign.T)
            changed = true
        }

        if params["auto"] == "true" {
            let deg = tryRotationsAndPickBest(sample: unitOutline)
            let pre = Affine2.translation(Vec2(x: -center.x, y: -center.y))
            let rot = Affine2.rotation(deg: -deg)
            let post = Affine2.translation(center)
            trackAlign.T = post.composed(with: rot).composed(with: pre).composed(with: trackAlign.T)
            changed = true
        }

        if changed { logTransformedSample(prefix: "Rotated sample") }

        // Diagnostics (unclamped bounds)
        var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9
        var out = 0
        for p in unitOutline {
            let q = trackAlign.T.apply(p)
            if q.x < minX { minX = q.x }
            if q.x > maxX { maxX = q.x }
            if q.y < minY { minY = q.y }
            if q.y > maxY { maxY = q.y }
            if q.x < 0 || q.x > 1 || q.y < 0 || q.y > 1 { out += 1 }
        }
        let json: [String: Any] = [
            "matrix": ["a": trackAlign.T.a, "b": trackAlign.T.b, "c": trackAlign.T.c, "d": trackAlign.T.d, "tx": trackAlign.T.tx, "ty": trackAlign.T.ty],
            "bounds": ["minX": minX, "maxX": maxX, "minY": minY, "maxY": maxY],
            "outOfBounds": out
        ]
        let body = (try? JSONSerialization.data(withJSONObject: json)) ?? Data("{}".utf8)
        var headers = HTTPHeaders()
        headers.add(name: "content-type", value: "application/json")
        headers.add(name: "content-length", value: String(body.count))
        context.write(self.wrapOutboundOut(.head(HTTPResponseHead(version: .http1_1, status: .ok, headers: headers))), promise: nil)
        var buf = context.channel.allocator.buffer(capacity: body.count)
        buf.writeBytes(body)
        context.write(self.wrapOutboundOut(.body(.byteBuffer(buf))), promise: nil)
        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
    }
}

// MARK: - Inline tests
func runTests() {
    func approx(_ a: Double, _ b: Double, eps: Double = 1e-9) -> Bool { abs(a - b) < eps }
    // Square around unit square, 90 CW around center should map (0,0)->(1,0)
    var align = TrackAlign()
    align.setRotation90CW(around: Vec2(x: 0.5, y: 0.5))
    let p00 = align.T.apply(Vec2(x: 0, y: 0))
    let p10 = align.T.apply(Vec2(x: 1, y: 0))
    let p11 = align.T.apply(Vec2(x: 1, y: 1))
    let p01 = align.T.apply(Vec2(x: 0, y: 1))
    assert(approx(p00.x, 1) && approx(p00.y, 0))
    assert(approx(p10.x, 1) && approx(p10.y, 1))
    assert(approx(p11.x, 0) && approx(p11.y, 1))
    assert(approx(p01.x, 0) && approx(p01.y, 0))
}

// MARK: - Bootstrap
runTests()

let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
let bootstrap = ServerBootstrap(group: group)
    .serverChannelOption(ChannelOptions.backlog, value: 256)
    .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
    .childChannelInitializer { channel in
        channel.pipeline.configureHTTPServerPipeline().flatMap {
            channel.pipeline.addHandler(HTTPHandler())
        }
    }
    .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
    .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
    .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

let channel = try! bootstrap.bind(host: "127.0.0.1", port: 8080).wait()
print("Server running on http://127.0.0.1:8080")
try! channel.closeFuture.wait()
try! group.syncShutdownGracefully()

