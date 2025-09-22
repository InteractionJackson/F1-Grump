//
//  TrackGeoJSONLoader.swift
//  F1 Grump
//
//  Created by Matt Jackson on 11/09/2025.
//

import Foundation
import CoreGraphics

enum TrackAssets {
    // Accept multiple common locations/casing in the app bundle
    static let candidateSubdirs: [String] = [
        "Circuits",
        "circuits",
        "assets/Circuits",
        "assets/circuits"
    ]

    static func allNames() -> [String] {
        // Debug-friendly lookup: support multiple bundle subdirs and app Documents
        var urls: [URL] = []
        for sub in candidateSubdirs {
            if let found = Bundle.main.urls(forResourcesWithExtension: "geojson", subdirectory: sub) {
                urls.append(contentsOf: found)
            }
        }
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            if let fileURLs = try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil) {
                urls.append(contentsOf: fileURLs.filter { $0.pathExtension.lowercased() == "geojson" })
            }
        }
        return urls
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            .map { $0.deletingPathExtension().lastPathComponent }
    }
}

func bestGeoJSONName(for hint: String) -> String? {
    let names = TrackAssets.allNames()
    guard !names.isEmpty else { return nil }
    let normHint = normalizeName(hint)
    var best: (score: Int, name: String)? = nil
    for n in names {
        let score = fuzzyScore(a: normHint, b: normalizeName(n))
        if score > (best?.score ?? -1) { best = (score, n) }
    }
    return best?.name
}

private func normalizeName(_ s: String) -> String {
    let lowered = s.lowercased()
    let aliases: [(String,String)] = [
        ("bahrain", "sakhir"),
        ("cota", "austin"),
        ("interlagos", "brazil"),
        ("yasmarina", "abudhabi"),
        ("gp", "grandprix")
    ]
    var out = lowered.replacingOccurrences(of: " ", with: "")
    for (a,b) in aliases {
        if out.contains(a) { out = out.replacingOccurrences(of: a, with: b) }
    }
    let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789")
    out.removeAll { !allowed.contains($0) }
    return out
}

private func fuzzyScore(a: String, b: String) -> Int {
    if a == b { return 1000 }
    if a.contains(b) || b.contains(a) { return 800 }
    return Set(a).intersection(Set(b)).count
}

func loadGeoJSONOutline(named name: String) -> [[CGPoint]] {
    // Try bundle subdirectories, then Documents (for local drops)
    var url: URL? = nil
    for sub in TrackAssets.candidateSubdirs {
        if let u = Bundle.main.url(forResource: name, withExtension: "geojson", subdirectory: sub) { url = u; break }
    }
    if url == nil, let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let candidate = docs.appendingPathComponent("\(name).geojson")
        if FileManager.default.fileExists(atPath: candidate.path) { url = candidate }
    }
    guard let u = url,
          let data = try? Data(contentsOf: u),
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
import CoreGraphics

// Entire TrackOutlineMap removed per request
