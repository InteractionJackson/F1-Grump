import Foundation
import CoreGraphics

struct TrackPolyline: Codable {
    let trackName: String
    let points: [CGPointCodable]
}

struct TrackTransformCodable: Codable {
    let trackName: String
    let a: CGFloat
    let b: CGFloat
    let c: CGFloat
    let d: CGFloat
    let tx: CGFloat
    let ty: CGFloat
    init(trackName: String, t: CGAffineTransform) {
        self.trackName = trackName
        self.a = t.a; self.b = t.b; self.c = t.c; self.d = t.d; self.tx = t.tx; self.ty = t.ty
    }
    var transform: CGAffineTransform { .init(a: a, b: b, c: c, d: d, tx: tx, ty: ty) }
}

struct CGPointCodable: Codable {
    let x: CGFloat
    let y: CGFloat
    init(_ p: CGPoint) { self.x = p.x; self.y = p.y }
    var cg: CGPoint { CGPoint(x: x, y: y) }
}

final class TrackPolylineStore {
    static let shared = TrackPolylineStore()
    private init() {}

    private func url(for track: String) -> URL? {
        guard let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return base.appendingPathComponent("track_\(track.replacingOccurrences(of: " ", with: "_").lowercased()).json")
    }

    private func urlForTransform(for track: String) -> URL? {
        guard let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return base.appendingPathComponent("track_\(track.replacingOccurrences(of: " ", with: "_").lowercased())_transform.json")
    }

    func load(track: String) -> [CGPoint]? {
        guard let u = url(for: track), let data = try? Data(contentsOf: u) else { return nil }
        if let poly = try? JSONDecoder().decode(TrackPolyline.self, from: data) {
            return poly.points.map { $0.cg }
        }
        return nil
    }

    func save(track: String, points: [CGPoint]) {
        guard let u = url(for: track) else { return }
        let poly = TrackPolyline(trackName: track, points: points.map { CGPointCodable($0) })
        if let data = try? JSONEncoder().encode(poly) {
            try? data.write(to: u)
        }
    }

    func saveTransform(track: String, transform: CGAffineTransform) {
        guard let u = urlForTransform(for: track) else { return }
        let model = TrackTransformCodable(trackName: track, t: transform)
        if let data = try? JSONEncoder().encode(model) {
            try? data.write(to: u)
        }
    }

    func loadTransform(track: String) -> CGAffineTransform? {
        guard let u = urlForTransform(for: track), let data = try? Data(contentsOf: u) else { return nil }
        if let model = try? JSONDecoder().decode(TrackTransformCodable.self, from: data) {
            return model.transform
        }
        return nil
    }

    func deleteTransform(track: String) {
        guard let u = urlForTransform(for: track) else { return }
        try? FileManager.default.removeItem(at: u)
    }
}


