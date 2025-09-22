import Foundation
import CoreGraphics

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

final class TrackAlignStore {
	static let shared = TrackAlignStore()
	private init() {}

	var currentTrackName: String = ""
	var T: Affine2 = .identity

    func setTrack(_ name: String) { currentTrackName = name; T = .identity }

    func save() { /* persistence removed with overlay cleanup */ }

	func apply(_ p: Vec2) -> Vec2 { T.apply(p) }

	func setRotation(deg: Double, around center: Vec2 = .init(x: 0.5, y: 0.5)) {
		let pre = Affine2.translation(Vec2(x: -center.x, y: -center.y))
		let rot = Affine2.rotation(deg: -deg) // CW positive visually
		let post = Affine2.translation(center)
		T = post.composed(with: rot).composed(with: pre).composed(with: T)
		logSample(prefix: "Set rotation \(deg) CW")
		save()
	}

	func setRotation90CW(around center: Vec2 = .init(x: 0.5, y: 0.5)) { setRotation(deg: 90, around: center) }

	func tryRotationsAndPickBest(rotations: [Double] = [0,90,180,270], sample: [Vec2]) -> Double {
		guard !sample.isEmpty else { return 0 }
		var bestDeg = 0.0
		var bestScore = Double.greatestFiniteMagnitude
		let ctr = Vec2(x: 0.5, y: 0.5)
		for deg in rotations {
			let pre = Affine2.translation(Vec2(x: -ctr.x, y: -ctr.y))
			let rot = Affine2.rotation(deg: -deg)
			let post = Affine2.translation(ctr)
			let M = post.composed(with: rot).composed(with: pre)
			var minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9
			for p in sample {
				let q = M.apply(p)
				if q.x < minX { minX = q.x }
				if q.x > maxX { maxX = q.x }
				if q.y < minY { minY = q.y }
				if q.y > maxY { maxY = q.y }
			}
			let area = (maxX - minX) * (maxY - minY)
			if area < bestScore { bestScore = area; bestDeg = deg }
		}
		return bestDeg
	}

	func autoSnap(sample01: [CGPoint]) {
		let vecs = sample01.map { Vec2(x: Double($0.x), y: Double($0.y)) }
		let deg = tryRotationsAndPickBest(sample: vecs)
		if deg != 0 { setRotation(deg: deg) }
	}

	private func logSample(prefix: String) {
		let pts: [Vec2] = [Vec2(x: 0.1, y: 0.1), Vec2(x: 0.9, y: 0.1), Vec2(x: 0.9, y: 0.9), Vec2(x: 0.1, y: 0.9)]
		let out = pts.prefix(5).map { p -> String in
			let q = T.apply(p)
			return String(format: "(%.3f,%.3f)", q.x, q.y)
		}
		print(prefix + ": " + out.joined(separator: ", "))
	}
}

