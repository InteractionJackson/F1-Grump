//
//  TrackGeoJSONLoader.swift
//  F1 Grump
//
//  Created by Matt Jackson on 11/09/2025.
//

import Foundation
import CoreGraphics

enum TrackAssets {
    static let subdir = "Circuits" // the folder you added to the app bundle

    static func allNames() -> [String] {
        let urls = Bundle.main.urls(forResourcesWithExtension: "geojson", subdirectory: subdir) ?? []
        return urls
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            .map { $0.deletingPathExtension().lastPathComponent }
    }
}

func loadGeoJSONOutline(named name: String) -> [[CGPoint]] {
    guard let url = Bundle.main.url(forResource: name, withExtension: "geojson", subdirectory: TrackAssets.subdir),
          let data = try? Data(contentsOf: url),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else { return [] }

    var rawSegments: [[CGPoint]] = []

    func pts(_ arr: [[Any]]) -> [CGPoint] {
        arr.compactMap { pair in
            guard let lon = (pair.first as? NSNumber)?.doubleValue,
                  let lat = (pair.dropFirst().first as? NSNumber)?.doubleValue else { return nil }
            return CGPoint(x: lon, y: lat)
        }
    }
    func handleGeometry(_ g: [String: Any]) {
        guard let type = g["type"] as? String else { return }
        let c = g["coordinates"]
        switch type {
        case "LineString":
            if let a = c as? [[Any]] { rawSegments.append(pts(a)) }
        case "MultiLineString":
            if let a = c as? [[[Any]]] { a.forEach { rawSegments.append(pts($0)) } }
        case "Polygon":
            if let rings = c as? [[[Any]]], let outer = rings.first { rawSegments.append(pts(outer)) }
        default: break
        }
    }

    if let type = root["type"] as? String, type == "FeatureCollection",
       let feats = root["features"] as? [[String: Any]] {
        feats.forEach { if let g = $0["geometry"] as? [String: Any] { handleGeometry(g) } }
    } else if let type = root["type"] as? String, type == "Feature",
              let g = root["geometry"] as? [String: Any] {
        handleGeometry(g)
    } else {
        handleGeometry(root)
    }

    // Normalize to 0..1 and preserve aspect; flip Y so north is up on screen
    let all = rawSegments.flatMap { $0 }
    guard let minX = all.map(\.x).min(),
          let maxX = all.map(\.x).max(),
          let minY = all.map(\.y).min(),
          let maxY = all.map(\.y).max(),
          maxX > minX, maxY > minY else { return [] }

    func norm(_ p: CGPoint) -> CGPoint {
        CGPoint(x: CGFloat((p.x - minX) / (maxX - minX)),
                y: CGFloat((p.y - minY) / (maxY - minY)))
    }

    let aspect = (maxX - minX) / (maxY - minY) // w/h
    let scaleX: CGFloat, scaleY: CGFloat, offX: CGFloat, offY: CGFloat
    if aspect > 1 { // wide → pillarbox
        scaleX = 1; scaleY = CGFloat(1 / aspect); offX = 0; offY = (1 - scaleY) / 2
    } else {        // tall → letterbox
        scaleX = CGFloat(aspect); scaleY = 1; offX = (1 - scaleX) / 2; offY = 0
    }

    func fitSquare(_ p: CGPoint) -> CGPoint {
        CGPoint(x: offX + p.x * scaleX,
                y: offY + (1 - p.y) * scaleY) // flip Y for top-down
    }

    return rawSegments
        .map { $0.map(norm).map(fitSquare) }
        .filter { $0.count >= 2 }
}

import SwiftUI

struct TrackOutlineMap: View {
    let segments: [[CGPoint]]     // normalized outline polylines (0..1)
    let carPoints: [CGPoint]      // all cars, normalized (0..1)
    let playerIndex: Int          // which one to highlight (0-based)

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                // 1) Outline
                for seg in segments where seg.count > 1 {
                    var path = Path()
                    path.move(to: scale(seg[0], size))
                    for p in seg.dropFirst() { path.addLine(to: scale(p, size)) }
                    ctx.stroke(path, with: .color(.secondary.opacity(0.7)), lineWidth: 3)
                }

                // 2) All car dots
                for (i, p) in carPoints.enumerated() {
                    let pt = scale(p, size)
                    let r: CGFloat = (i == playerIndex) ? 5 : 3
                    let color: Color = (i == playerIndex) ? .blue : .primary.opacity(0.7)
                    let rect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
                    ctx.fill(Circle().path(in: rect), with: .color(color))
                }
            }
        }
    }

    private func scale(_ p: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: p.x * size.width, y: p.y * size.height)
    }
}
