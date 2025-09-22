//
//  DamageSVGView.swift
//  F1 Grump
//
//  Created by Matt Jackson on 12/09/2025.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import PocketSVG

/// Render an SVG and let you recolor individual paths/groups by their SVG `id`.
@available(iOS 13.0, *)
struct DamageSVGView: UIViewRepresentable {
    /// "car_overlay" (without .svg). File must be in bundle subdir `Overlays` or change below.
    let filename: String
    /// 0.0 ... 1.0 values per SVG id (e.g. ["front_wing_left": 0.3])
    let damage: [String: CGFloat]

    func makeUIView(context: Context) -> DamageSVGContainer {
        let v = DamageSVGContainer()
        v.backgroundColor = .clear
        v.loadSVG(named: filename)
        return v
    }

    func updateUIView(_ uiView: DamageSVGContainer, context: Context) {
        uiView.applyDamage(damage)
        uiView.setNeedsLayout()
    }
}

/// Backing UIView that holds CAShapeLayers mapped by SVG element id.
final class DamageSVGContainer: UIView {
    private var layersById: [String: CAShapeLayer] = [:]
    private var baseLayer = CALayer()
    private var currentName = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(baseLayer)
        isOpaque = false
        contentMode = .redraw
    }
    required init?(coder: NSCoder) { fatalError() }

    func loadSVG(named name: String) {
        guard name != currentName else { return }
        currentName = name
        layersById.removeAll()
        baseLayer.sublayers?.forEach { $0.removeFromSuperlayer() }

        let url = Bundle.main.url(forResource: name, withExtension: "svg", subdirectory: "Overlays")
              ?? Bundle.main.url(forResource: name, withExtension: "svg")
        guard let url else { print("⚠️ SVG not found: \(name).svg"); return }

        guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
            print("⚠️ Could not read SVG text"); return
        }

        let clean = sanitizeSVG(raw)
        let svgPaths = SVGBezierPath.paths(fromSVGString: clean)   // ← parse from string
        guard !svgPaths.isEmpty else { print("⚠️ SVG had no paths"); return }
        
        // Merge by id and build layers
        var pathsById: [String: UIBezierPath] = [:]
        for p in svgPaths {
            let id = (p.svgAttributes["id"] as? String) ?? "unnamed"
            let holder = pathsById[id] ?? UIBezierPath()
            holder.append(p)
            pathsById[id] = holder
        }

        for (id, bezier) in pathsById {
            let shape = CAShapeLayer()
            shape.path = bezier.cgPath
            shape.fillColor = UIColor.clear.cgColor
            shape.strokeColor = UIColor.label.cgColor
            shape.lineWidth = 2
            shape.lineJoin = .round
            shape.lineCap = .round
            baseLayer.addSublayer(shape)
            layersById[id] = shape
        }
        setNeedsLayout()
    }

    func applyDamage(_ damage: [String: CGFloat]) {
        // If there is effectively no damage anywhere for a sustained period, render a stable green tint.
        // We avoid per-frame toggling by keeping a sticky zero state until damage clears >2%.
        let maxDamage = damage.values.max() ?? 0
        struct Sticky { static var noDamageFrames = 0 }
        if maxDamage < 0.02 { Sticky.noDamageFrames += 1 } else { Sticky.noDamageFrames = 0 }
        if Sticky.noDamageFrames >= 5 {
            for layer in layersById.values {
                let ok = UIColor(red: 0.15, green: 0.85, blue: 0.27, alpha: 1) // #27D94D-ish
                layer.fillColor = ok.withAlphaComponent(0.14).cgColor
                layer.strokeColor = ok.cgColor
                layer.lineWidth = 0.83
            }
            return
        }
        // If the SVG has distinct ids, shade per-part. Otherwise, fall back to an overall tint.
        if layersById.count <= 1 {
            // Overall severity: prioritize wing damage if present, else tyres
            let wingKeys = ["front_wing_left", "front_wing_right", "rear_wing", "drs"]
            let tyreKeys = ["fl_tyre", "fr_tyre", "rl_tyre", "rr_tyre"]
            let wingMax = wingKeys.compactMap { damage[$0] }.max() ?? 0
            let tyreMax = tyreKeys.compactMap { damage[$0] }.max() ?? 0
            let pct = max(wingMax, tyreMax)
            let color = damageColor(CGFloat(pct))
            for layer in layersById.values {
                layer.fillColor = color.withAlphaComponent(0.28).cgColor
                layer.strokeColor = color.cgColor
                layer.lineWidth = 2.0
            }
            #if DEBUG
            if let onlyId = layersById.keys.first { print("DamageSVG: single id '" + onlyId + "' — using overall damage =", pct) }
            #endif
            return
        }

        for (id, layer) in layersById {
            let pct = max(0, min(1, damage[id] ?? 0))
            let color = damageColor(pct)
            layer.fillColor = color.withAlphaComponent(pct > 0 ? 0.35 : 0.08).cgColor
            layer.strokeColor = color.cgColor
            layer.lineWidth = pct > 0.01 ? 2.5 : 2.0
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        baseLayer.frame = bounds
        let union = layersById.values.reduce(CGRect.null) { $0.union($1.path?.boundingBoxOfPath ?? .null) }
        guard union.width > 0, union.height > 0 else { return }
        let t = aspectFitTransform(for: union, in: bounds)
        for layer in layersById.values { layer.setAffineTransform(t) }
    }
}

/// Prints all element IDs found in an SVG in your bundle (for sanity-checking).
func debugPrintSVGIDs(named file: String, subdir: String = "Overlays") {
    let url = Bundle.main.url(forResource: file, withExtension: "svg", subdirectory: subdir)
          ?? Bundle.main.url(forResource: file, withExtension: "svg")
    guard let url else { print("⚠️ SVG not found"); return }
    let paths = SVGBezierPath.pathsFromSVG(at: url)
    let ids = paths.compactMap { $0.svgAttributes["id"] as? String }
    print("✅ \(file).svg IDs (\(ids.count)):", ids)
}

// 0…1 → green → yellow → red
private func damageColor(_ x: CGFloat) -> UIColor {
    let t = max(0, min(1, x))
    // linear blend: green (0,1,0) → yellow (1,1,0) → red (1,0,0)
    let r = t <= 0.5 ? t * 2 : 1
    let g = t <= 0.5 ? 1 : 1 - (t - 0.5) * 2
    return UIColor(red: r, green: g, blue: 0, alpha: 1)
}

// Aspect-fit transform that centers `src` inside `dst`
private func aspectFitTransform(for src: CGRect, in dst: CGRect) -> CGAffineTransform {
    guard src.width > 0, src.height > 0, dst.width > 0, dst.height > 0 else { return .identity }
    let sx = dst.width / src.width
    let sy = dst.height / src.height
    let s = min(sx, sy)
    let tx = dst.midX - src.midX * s
    let ty = dst.midY - src.midY * s
    return CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: tx, ty: ty)
}

import Foundation

/// Strip gradients/patterns and non-hex colors so PocketSVG won't crash.
private func sanitizeSVG(_ s: String) -> String {
    var r = s

    // 1) Remove inline style="" blocks completely.
    r = regexReplace(r, pattern: "style=\"[^\"]*\"", replacement: "")

    // 2) Replace gradient/pattern paints url(#...) on stroke/fill.
    r = regexReplace(r, pattern: "stroke=\"url\\([^)]+\\)\"", replacement: "stroke=\"#222\"")
    r = regexReplace(r, pattern: "fill=\"url\\([^)]+\\)\"",   replacement: "fill=\"none\"")

    // 3) Any remaining non-hex strokes/fills -> safe defaults.
    r = regexReplace(r, pattern: "stroke=\"(?!#)[^\"]*\"",   replacement: "stroke=\"#222\"")
    r = regexReplace(r, pattern: "fill=\"(?!#|none)[^\"]*\"", replacement: "fill=\"none\"")

    // 4) Remove defs/gradients blocks entirely (extra safety).
    r = regexReplace(r, pattern: "<defs>[\\s\\S]*?</defs>",                 replacement: "")
    r = regexReplace(r, pattern: "<linearGradient[\\s\\S]*?</linearGradient>", replacement: "")
    r = regexReplace(r, pattern: "<radialGradient[\\s\\S]*?</radialGradient>", replacement: "")

    return r
}

/// Small helper to keep the calls tidy.
private func regexReplace(_ input: String, pattern: String, replacement: String) -> String {
    guard let rx = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return input }
    let ns = input as NSString
    let range = NSRange(location: 0, length: ns.length)
    return rx.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: replacement)
}

#if !canImport(UIKit)
// Fallback stub for platforms without UIKit (e.g., macOS build of non-UI target)
struct DamageSVGView: View {
    let filename: String
    let damage: [String: CGFloat]
    var body: some View { Color.clear }
}
#endif

