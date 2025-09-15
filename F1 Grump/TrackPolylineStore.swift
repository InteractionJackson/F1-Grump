import Foundation
import CoreGraphics

struct TrackPolyline: Codable {
    let trackName: String
    let points: [CGPointCodable]
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
}


