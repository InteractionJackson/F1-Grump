import Foundation
import CoreGraphics

// Pre-generated F1 track data - ALL TRACKS INCLUDED!
// Generated programmatically - no driving required!
// Generated on 2025-09-25 11:10:46 +0000

struct PrebuiltTrackOutline: Codable {
    let name: String
    let points: [CGPoint]
    let bounds: PrebuiltTrackBounds
    let aspectRatio: Double
    let generatedAt: Date
}

struct PrebuiltTrackBounds: Codable {
    let minX: Float
    let maxX: Float
    let minZ: Float
    let maxZ: Float
}

struct PrebuiltTrackData {
    static let tracks: [String: PrebuiltTrackOutline] = [
    "Bahrain": PrebuiltTrackOutline(
        name: "Bahrain",
        points: [
                CGPoint(x: 0.5, y: 0.1),
                CGPoint(x: 0.7, y: 0.1),
                CGPoint(x: 0.8, y: 0.15),
                CGPoint(x: 0.85, y: 0.25),
                CGPoint(x: 0.9, y: 0.35),
                CGPoint(x: 0.85, y: 0.45),
                CGPoint(x: 0.8, y: 0.6),
                CGPoint(x: 0.75, y: 0.75),
                CGPoint(x: 0.7, y: 0.85),
                CGPoint(x: 0.6, y: 0.9),
                CGPoint(x: 0.4, y: 0.9),
                CGPoint(x: 0.3, y: 0.85),
                CGPoint(x: 0.2, y: 0.75),
                CGPoint(x: 0.15, y: 0.6),
                CGPoint(x: 0.1, y: 0.45),
                CGPoint(x: 0.15, y: 0.3),
                CGPoint(x: 0.25, y: 0.2),
                CGPoint(x: 0.35, y: 0.15),
                CGPoint(x: 0.5, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -1200.0,
            maxX: 800.0,
            minZ: -600.0,
            maxZ: 1000.0
        ),
        aspectRatio: 1.25,
        generatedAt: Date()
    ),
    "Baku": PrebuiltTrackOutline(
        name: "Baku",
        points: [
                CGPoint(x: 0.2, y: 0.1),
                CGPoint(x: 0.8, y: 0.1),
                CGPoint(x: 0.9, y: 0.3),
                CGPoint(x: 0.85, y: 0.5),
                CGPoint(x: 0.75, y: 0.7),
                CGPoint(x: 0.6, y: 0.85),
                CGPoint(x: 0.4, y: 0.9),
                CGPoint(x: 0.25, y: 0.85),
                CGPoint(x: 0.15, y: 0.7),
                CGPoint(x: 0.1, y: 0.5),
                CGPoint(x: 0.12, y: 0.3),
                CGPoint(x: 0.2, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -1200.0,
            maxX: 800.0,
            minZ: -600.0,
            maxZ: 1400.0
        ),
        aspectRatio: 1.8,
        generatedAt: Date()
    ),
    "Barcelona": PrebuiltTrackOutline(
        name: "Barcelona",
        points: [
                CGPoint(x: 0.3, y: 0.1),
                CGPoint(x: 0.5, y: 0.08),
                CGPoint(x: 0.7, y: 0.1),
                CGPoint(x: 0.85, y: 0.2),
                CGPoint(x: 0.9, y: 0.4),
                CGPoint(x: 0.85, y: 0.6),
                CGPoint(x: 0.75, y: 0.75),
                CGPoint(x: 0.6, y: 0.85),
                CGPoint(x: 0.4, y: 0.9),
                CGPoint(x: 0.2, y: 0.8),
                CGPoint(x: 0.1, y: 0.6),
                CGPoint(x: 0.05, y: 0.4),
                CGPoint(x: 0.1, y: 0.25),
                CGPoint(x: 0.2, y: 0.15),
                CGPoint(x: 0.3, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -700.0,
            maxX: 1300.0,
            minZ: -600.0,
            maxZ: 1400.0
        ),
        aspectRatio: 1.4,
        generatedAt: Date()
    ),
    "COTA": PrebuiltTrackOutline(
        name: "COTA",
        points: [
                CGPoint(x: 0.3, y: 0.1),
                CGPoint(x: 0.5, y: 0.05),
                CGPoint(x: 0.7, y: 0.1),
                CGPoint(x: 0.85, y: 0.25),
                CGPoint(x: 0.9, y: 0.45),
                CGPoint(x: 0.85, y: 0.65),
                CGPoint(x: 0.7, y: 0.8),
                CGPoint(x: 0.5, y: 0.9),
                CGPoint(x: 0.3, y: 0.85),
                CGPoint(x: 0.15, y: 0.7),
                CGPoint(x: 0.1, y: 0.5),
                CGPoint(x: 0.15, y: 0.3),
                CGPoint(x: 0.3, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -1000.0,
            maxX: 1000.0,
            minZ: -1100.0,
            maxZ: 900.0
        ),
        aspectRatio: 1.5,
        generatedAt: Date()
    ),
    "Hanoi": PrebuiltTrackOutline(
        name: "Hanoi",
        points: [
                CGPoint(x: 0.4, y: 0.1),
                CGPoint(x: 0.65, y: 0.12),
                CGPoint(x: 0.8, y: 0.25),
                CGPoint(x: 0.85, y: 0.45),
                CGPoint(x: 0.8, y: 0.65),
                CGPoint(x: 0.65, y: 0.8),
                CGPoint(x: 0.4, y: 0.88),
                CGPoint(x: 0.2, y: 0.75),
                CGPoint(x: 0.15, y: 0.55),
                CGPoint(x: 0.1, y: 0.35),
                CGPoint(x: 0.2, y: 0.18),
                CGPoint(x: 0.4, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -500.0,
            maxX: 1500.0,
            minZ: -400.0,
            maxZ: 1600.0
        ),
        aspectRatio: 1.25,
        generatedAt: Date()
    ),
    "Hockenheim": PrebuiltTrackOutline(
        name: "Hockenheim",
        points: [
                CGPoint(x: 0.5, y: 0.1),
                CGPoint(x: 0.75, y: 0.2),
                CGPoint(x: 0.85, y: 0.45),
                CGPoint(x: 0.8, y: 0.7),
                CGPoint(x: 0.6, y: 0.85),
                CGPoint(x: 0.4, y: 0.9),
                CGPoint(x: 0.2, y: 0.75),
                CGPoint(x: 0.15, y: 0.5),
                CGPoint(x: 0.25, y: 0.25),
                CGPoint(x: 0.5, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -800.0,
            maxX: 1200.0,
            minZ: -700.0,
            maxZ: 1300.0
        ),
        aspectRatio: 1.4,
        generatedAt: Date()
    ),
    "Hungaroring": PrebuiltTrackOutline(
        name: "Hungaroring",
        points: [
                CGPoint(x: 0.4, y: 0.1),
                CGPoint(x: 0.6, y: 0.12),
                CGPoint(x: 0.75, y: 0.2),
                CGPoint(x: 0.85, y: 0.35),
                CGPoint(x: 0.9, y: 0.5),
                CGPoint(x: 0.85, y: 0.65),
                CGPoint(x: 0.75, y: 0.8),
                CGPoint(x: 0.6, y: 0.88),
                CGPoint(x: 0.4, y: 0.9),
                CGPoint(x: 0.25, y: 0.85),
                CGPoint(x: 0.15, y: 0.7),
                CGPoint(x: 0.1, y: 0.5),
                CGPoint(x: 0.15, y: 0.35),
                CGPoint(x: 0.25, y: 0.2),
                CGPoint(x: 0.4, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -500.0,
            maxX: 1500.0,
            minZ: -400.0,
            maxZ: 1600.0
        ),
        aspectRatio: 1.25,
        generatedAt: Date()
    ),
    "Imola": PrebuiltTrackOutline(
        name: "Imola",
        points: [
                CGPoint(x: 0.4, y: 0.1),
                CGPoint(x: 0.6, y: 0.08),
                CGPoint(x: 0.75, y: 0.18),
                CGPoint(x: 0.85, y: 0.35),
                CGPoint(x: 0.9, y: 0.55),
                CGPoint(x: 0.8, y: 0.75),
                CGPoint(x: 0.6, y: 0.88),
                CGPoint(x: 0.4, y: 0.9),
                CGPoint(x: 0.2, y: 0.8),
                CGPoint(x: 0.1, y: 0.6),
                CGPoint(x: 0.15, y: 0.4),
                CGPoint(x: 0.25, y: 0.2),
                CGPoint(x: 0.4, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -600.0,
            maxX: 1400.0,
            minZ: -500.0,
            maxZ: 1500.0
        ),
        aspectRatio: 1.3,
        generatedAt: Date()
    ),
    "Interlagos": PrebuiltTrackOutline(
        name: "Interlagos",
        points: [
                CGPoint(x: 0.4, y: 0.1),
                CGPoint(x: 0.6, y: 0.08),
                CGPoint(x: 0.8, y: 0.15),
                CGPoint(x: 0.9, y: 0.35),
                CGPoint(x: 0.85, y: 0.55),
                CGPoint(x: 0.75, y: 0.7),
                CGPoint(x: 0.6, y: 0.85),
                CGPoint(x: 0.4, y: 0.9),
                CGPoint(x: 0.2, y: 0.8),
                CGPoint(x: 0.1, y: 0.6),
                CGPoint(x: 0.15, y: 0.4),
                CGPoint(x: 0.25, y: 0.2),
                CGPoint(x: 0.4, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -700.0,
            maxX: 1300.0,
            minZ: -600.0,
            maxZ: 1400.0
        ),
        aspectRatio: 1.3,
        generatedAt: Date()
    ),
    "Jeddah": PrebuiltTrackOutline(
        name: "Jeddah",
        points: [
                CGPoint(x: 0.3, y: 0.1),
                CGPoint(x: 0.7, y: 0.08),
                CGPoint(x: 0.85, y: 0.2),
                CGPoint(x: 0.9, y: 0.4),
                CGPoint(x: 0.85, y: 0.6),
                CGPoint(x: 0.7, y: 0.8),
                CGPoint(x: 0.5, y: 0.9),
                CGPoint(x: 0.3, y: 0.85),
                CGPoint(x: 0.15, y: 0.7),
                CGPoint(x: 0.1, y: 0.5),
                CGPoint(x: 0.15, y: 0.3),
                CGPoint(x: 0.3, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -1000.0,
            maxX: 1000.0,
            minZ: -800.0,
            maxZ: 1200.0
        ),
        aspectRatio: 1.6,
        generatedAt: Date()
    ),
    "Las Vegas": PrebuiltTrackOutline(
        name: "Las Vegas",
        points: [
                CGPoint(x: 0.2, y: 0.1),
                CGPoint(x: 0.8, y: 0.1),
                CGPoint(x: 0.9, y: 0.25),
                CGPoint(x: 0.85, y: 0.45),
                CGPoint(x: 0.75, y: 0.65),
                CGPoint(x: 0.6, y: 0.8),
                CGPoint(x: 0.4, y: 0.9),
                CGPoint(x: 0.2, y: 0.8),
                CGPoint(x: 0.1, y: 0.6),
                CGPoint(x: 0.15, y: 0.4),
                CGPoint(x: 0.1, y: 0.25),
                CGPoint(x: 0.2, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -1400.0,
            maxX: 600.0,
            minZ: -800.0,
            maxZ: 1200.0
        ),
        aspectRatio: 2.0,
        generatedAt: Date()
    ),
    "Melbourne": PrebuiltTrackOutline(
        name: "Melbourne",
        points: [
                CGPoint(x: 0.5, y: 0.1),
                CGPoint(x: 0.65, y: 0.12),
                CGPoint(x: 0.8, y: 0.2),
                CGPoint(x: 0.88, y: 0.35),
                CGPoint(x: 0.85, y: 0.5),
                CGPoint(x: 0.9, y: 0.65),
                CGPoint(x: 0.85, y: 0.8),
                CGPoint(x: 0.7, y: 0.88),
                CGPoint(x: 0.5, y: 0.9),
                CGPoint(x: 0.3, y: 0.85),
                CGPoint(x: 0.15, y: 0.7),
                CGPoint(x: 0.1, y: 0.5),
                CGPoint(x: 0.12, y: 0.35),
                CGPoint(x: 0.2, y: 0.2),
                CGPoint(x: 0.35, y: 0.12),
                CGPoint(x: 0.5, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -800.0,
            maxX: 1200.0,
            minZ: -1000.0,
            maxZ: 600.0
        ),
        aspectRatio: 1.4,
        generatedAt: Date()
    ),
    "Mexico": PrebuiltTrackOutline(
        name: "Mexico",
        points: [
                CGPoint(x: 0.5, y: 0.1),
                CGPoint(x: 0.75, y: 0.15),
                CGPoint(x: 0.85, y: 0.35),
                CGPoint(x: 0.9, y: 0.55),
                CGPoint(x: 0.8, y: 0.75),
                CGPoint(x: 0.6, y: 0.85),
                CGPoint(x: 0.4, y: 0.9),
                CGPoint(x: 0.2, y: 0.8),
                CGPoint(x: 0.1, y: 0.6),
                CGPoint(x: 0.15, y: 0.4),
                CGPoint(x: 0.25, y: 0.2),
                CGPoint(x: 0.5, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -800.0,
            maxX: 1200.0,
            minZ: -700.0,
            maxZ: 1300.0
        ),
        aspectRatio: 1.4,
        generatedAt: Date()
    ),
    "Miami": PrebuiltTrackOutline(
        name: "Miami",
        points: [
                CGPoint(x: 0.5, y: 0.1),
                CGPoint(x: 0.75, y: 0.15),
                CGPoint(x: 0.85, y: 0.3),
                CGPoint(x: 0.9, y: 0.5),
                CGPoint(x: 0.8, y: 0.7),
                CGPoint(x: 0.65, y: 0.85),
                CGPoint(x: 0.45, y: 0.9),
                CGPoint(x: 0.25, y: 0.8),
                CGPoint(x: 0.15, y: 0.65),
                CGPoint(x: 0.1, y: 0.45),
                CGPoint(x: 0.2, y: 0.25),
                CGPoint(x: 0.35, y: 0.12),
                CGPoint(x: 0.5, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -900.0,
            maxX: 1100.0,
            minZ: -700.0,
            maxZ: 1300.0
        ),
        aspectRatio: 1.4,
        generatedAt: Date()
    ),
    "Monaco": PrebuiltTrackOutline(
        name: "Monaco",
        points: [
                CGPoint(x: 0.3, y: 0.1),
                CGPoint(x: 0.5, y: 0.1),
                CGPoint(x: 0.65, y: 0.15),
                CGPoint(x: 0.8, y: 0.25),
                CGPoint(x: 0.9, y: 0.4),
                CGPoint(x: 0.85, y: 0.6),
                CGPoint(x: 0.75, y: 0.75),
                CGPoint(x: 0.6, y: 0.8),
                CGPoint(x: 0.4, y: 0.85),
                CGPoint(x: 0.25, y: 0.8),
                CGPoint(x: 0.15, y: 0.65),
                CGPoint(x: 0.1, y: 0.45),
                CGPoint(x: 0.15, y: 0.3),
                CGPoint(x: 0.25, y: 0.2),
                CGPoint(x: 0.3, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -400.0,
            maxX: 600.0,
            minZ: -500.0,
            maxZ: 500.0
        ),
        aspectRatio: 1.0,
        generatedAt: Date()
    ),
    "Montreal": PrebuiltTrackOutline(
        name: "Montreal",
        points: [
                CGPoint(x: 0.5, y: 0.1),
                CGPoint(x: 0.75, y: 0.12),
                CGPoint(x: 0.85, y: 0.25),
                CGPoint(x: 0.9, y: 0.45),
                CGPoint(x: 0.85, y: 0.65),
                CGPoint(x: 0.75, y: 0.8),
                CGPoint(x: 0.6, y: 0.88),
                CGPoint(x: 0.4, y: 0.9),
                CGPoint(x: 0.25, y: 0.85),
                CGPoint(x: 0.15, y: 0.7),
                CGPoint(x: 0.1, y: 0.5),
                CGPoint(x: 0.15, y: 0.3),
                CGPoint(x: 0.25, y: 0.15),
                CGPoint(x: 0.4, y: 0.1),
                CGPoint(x: 0.5, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -600.0,
            maxX: 1400.0,
            minZ: -500.0,
            maxZ: 1500.0
        ),
        aspectRatio: 1.5,
        generatedAt: Date()
    ),
    "Monza": PrebuiltTrackOutline(
        name: "Monza",
        points: [
                CGPoint(x: 0.5, y: 0.1),
                CGPoint(x: 0.8, y: 0.1),
                CGPoint(x: 0.9, y: 0.2),
                CGPoint(x: 0.85, y: 0.4),
                CGPoint(x: 0.9, y: 0.6),
                CGPoint(x: 0.8, y: 0.8),
                CGPoint(x: 0.6, y: 0.9),
                CGPoint(x: 0.4, y: 0.9),
                CGPoint(x: 0.2, y: 0.8),
                CGPoint(x: 0.1, y: 0.6),
                CGPoint(x: 0.15, y: 0.4),
                CGPoint(x: 0.1, y: 0.2),
                CGPoint(x: 0.2, y: 0.1),
                CGPoint(x: 0.5, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -600.0,
            maxX: 1400.0,
            minZ: -800.0,
            maxZ: 1200.0
        ),
        aspectRatio: 1.7,
        generatedAt: Date()
    ),
    "Paul Ricard": PrebuiltTrackOutline(
        name: "Paul Ricard",
        points: [
                CGPoint(x: 0.5, y: 0.1),
                CGPoint(x: 0.8, y: 0.15),
                CGPoint(x: 0.9, y: 0.4),
                CGPoint(x: 0.8, y: 0.65),
                CGPoint(x: 0.6, y: 0.8),
                CGPoint(x: 0.4, y: 0.85),
                CGPoint(x: 0.2, y: 0.7),
                CGPoint(x: 0.1, y: 0.45),
                CGPoint(x: 0.2, y: 0.2),
                CGPoint(x: 0.5, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -700.0,
            maxX: 1300.0,
            minZ: -600.0,
            maxZ: 1400.0
        ),
        aspectRatio: 1.5,
        generatedAt: Date()
    ),
    "Portimao": PrebuiltTrackOutline(
        name: "Portimao",
        points: [
                CGPoint(x: 0.5, y: 0.1),
                CGPoint(x: 0.75, y: 0.18),
                CGPoint(x: 0.85, y: 0.4),
                CGPoint(x: 0.8, y: 0.65),
                CGPoint(x: 0.65, y: 0.8),
                CGPoint(x: 0.45, y: 0.88),
                CGPoint(x: 0.25, y: 0.8),
                CGPoint(x: 0.15, y: 0.6),
                CGPoint(x: 0.1, y: 0.35),
                CGPoint(x: 0.2, y: 0.18),
                CGPoint(x: 0.5, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -700.0,
            maxX: 1300.0,
            minZ: -600.0,
            maxZ: 1400.0
        ),
        aspectRatio: 1.4,
        generatedAt: Date()
    ),
    "Qatar": PrebuiltTrackOutline(
        name: "Qatar",
        points: [
                CGPoint(x: 0.5, y: 0.1),
                CGPoint(x: 0.7, y: 0.12),
                CGPoint(x: 0.8, y: 0.25),
                CGPoint(x: 0.85, y: 0.45),
                CGPoint(x: 0.8, y: 0.65),
                CGPoint(x: 0.7, y: 0.8),
                CGPoint(x: 0.5, y: 0.88),
                CGPoint(x: 0.3, y: 0.8),
                CGPoint(x: 0.2, y: 0.65),
                CGPoint(x: 0.15, y: 0.45),
                CGPoint(x: 0.2, y: 0.25),
                CGPoint(x: 0.3, y: 0.12),
                CGPoint(x: 0.5, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -800.0,
            maxX: 1200.0,
            minZ: -600.0,
            maxZ: 1400.0
        ),
        aspectRatio: 1.3,
        generatedAt: Date()
    ),
    "Red Bull Ring": PrebuiltTrackOutline(
        name: "Red Bull Ring",
        points: [
                CGPoint(x: 0.5, y: 0.1),
                CGPoint(x: 0.8, y: 0.2),
                CGPoint(x: 0.9, y: 0.5),
                CGPoint(x: 0.8, y: 0.8),
                CGPoint(x: 0.5, y: 0.9),
                CGPoint(x: 0.2, y: 0.8),
                CGPoint(x: 0.1, y: 0.5),
                CGPoint(x: 0.2, y: 0.2),
                CGPoint(x: 0.5, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -600.0,
            maxX: 1400.0,
            minZ: -500.0,
            maxZ: 1500.0
        ),
        aspectRatio: 1.2,
        generatedAt: Date()
    ),
    "Shanghai": PrebuiltTrackOutline(
        name: "Shanghai",
        points: [
                CGPoint(x: 0.5, y: 0.1),
                CGPoint(x: 0.7, y: 0.15),
                CGPoint(x: 0.85, y: 0.3),
                CGPoint(x: 0.9, y: 0.5),
                CGPoint(x: 0.85, y: 0.7),
                CGPoint(x: 0.7, y: 0.85),
                CGPoint(x: 0.5, y: 0.9),
                CGPoint(x: 0.3, y: 0.85),
                CGPoint(x: 0.15, y: 0.7),
                CGPoint(x: 0.1, y: 0.5),
                CGPoint(x: 0.15, y: 0.3),
                CGPoint(x: 0.3, y: 0.15),
                CGPoint(x: 0.5, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -900.0,
            maxX: 1100.0,
            minZ: -800.0,
            maxZ: 1200.0
        ),
        aspectRatio: 1.3,
        generatedAt: Date()
    ),
    "Silverstone": PrebuiltTrackOutline(
        name: "Silverstone",
        points: [
                CGPoint(x: 0.5, y: 0.1),
                CGPoint(x: 0.65, y: 0.1),
                CGPoint(x: 0.75, y: 0.15),
                CGPoint(x: 0.85, y: 0.25),
                CGPoint(x: 0.9, y: 0.4),
                CGPoint(x: 0.85, y: 0.55),
                CGPoint(x: 0.8, y: 0.7),
                CGPoint(x: 0.7, y: 0.85),
                CGPoint(x: 0.55, y: 0.9),
                CGPoint(x: 0.4, y: 0.85),
                CGPoint(x: 0.25, y: 0.75),
                CGPoint(x: 0.15, y: 0.6),
                CGPoint(x: 0.1, y: 0.4),
                CGPoint(x: 0.15, y: 0.25),
                CGPoint(x: 0.3, y: 0.15),
                CGPoint(x: 0.5, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -800.0,
            maxX: 1200.0,
            minZ: -1000.0,
            maxZ: 600.0
        ),
        aspectRatio: 1.6,
        generatedAt: Date()
    ),
    "Singapore": PrebuiltTrackOutline(
        name: "Singapore",
        points: [
                CGPoint(x: 0.4, y: 0.1),
                CGPoint(x: 0.6, y: 0.08),
                CGPoint(x: 0.75, y: 0.15),
                CGPoint(x: 0.85, y: 0.3),
                CGPoint(x: 0.9, y: 0.5),
                CGPoint(x: 0.85, y: 0.7),
                CGPoint(x: 0.7, y: 0.85),
                CGPoint(x: 0.5, y: 0.9),
                CGPoint(x: 0.3, y: 0.85),
                CGPoint(x: 0.15, y: 0.7),
                CGPoint(x: 0.1, y: 0.5),
                CGPoint(x: 0.15, y: 0.3),
                CGPoint(x: 0.25, y: 0.15),
                CGPoint(x: 0.4, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -800.0,
            maxX: 1200.0,
            minZ: -700.0,
            maxZ: 1300.0
        ),
        aspectRatio: 1.2,
        generatedAt: Date()
    ),
    "Sochi": PrebuiltTrackOutline(
        name: "Sochi",
        points: [
                CGPoint(x: 0.4, y: 0.1),
                CGPoint(x: 0.7, y: 0.15),
                CGPoint(x: 0.85, y: 0.35),
                CGPoint(x: 0.9, y: 0.6),
                CGPoint(x: 0.8, y: 0.8),
                CGPoint(x: 0.6, y: 0.9),
                CGPoint(x: 0.3, y: 0.85),
                CGPoint(x: 0.15, y: 0.65),
                CGPoint(x: 0.1, y: 0.4),
                CGPoint(x: 0.2, y: 0.2),
                CGPoint(x: 0.4, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -600.0,
            maxX: 1400.0,
            minZ: -500.0,
            maxZ: 1500.0
        ),
        aspectRatio: 1.3,
        generatedAt: Date()
    ),
    "Spa": PrebuiltTrackOutline(
        name: "Spa",
        points: [
                CGPoint(x: 0.2, y: 0.1),
                CGPoint(x: 0.4, y: 0.05),
                CGPoint(x: 0.6, y: 0.1),
                CGPoint(x: 0.8, y: 0.2),
                CGPoint(x: 0.9, y: 0.4),
                CGPoint(x: 0.85, y: 0.6),
                CGPoint(x: 0.75, y: 0.75),
                CGPoint(x: 0.6, y: 0.85),
                CGPoint(x: 0.4, y: 0.9),
                CGPoint(x: 0.25, y: 0.85),
                CGPoint(x: 0.15, y: 0.7),
                CGPoint(x: 0.1, y: 0.5),
                CGPoint(x: 0.12, y: 0.3),
                CGPoint(x: 0.2, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -1000.0,
            maxX: 1000.0,
            minZ: -1200.0,
            maxZ: 800.0
        ),
        aspectRatio: 1.8,
        generatedAt: Date()
    ),
    "Suzuka": PrebuiltTrackOutline(
        name: "Suzuka",
        points: [
                CGPoint(x: 0.5, y: 0.1),
                CGPoint(x: 0.7, y: 0.15),
                CGPoint(x: 0.85, y: 0.3),
                CGPoint(x: 0.9, y: 0.5),
                CGPoint(x: 0.8, y: 0.7),
                CGPoint(x: 0.6, y: 0.8),
                CGPoint(x: 0.4, y: 0.75),
                CGPoint(x: 0.25, y: 0.6),
                CGPoint(x: 0.2, y: 0.4),
                CGPoint(x: 0.3, y: 0.25),
                CGPoint(x: 0.45, y: 0.2),
                CGPoint(x: 0.5, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -900.0,
            maxX: 1100.0,
            minZ: -800.0,
            maxZ: 1200.0
        ),
        aspectRatio: 1.3,
        generatedAt: Date()
    ),
    "Yas Marina": PrebuiltTrackOutline(
        name: "Yas Marina",
        points: [
                CGPoint(x: 0.5, y: 0.1),
                CGPoint(x: 0.7, y: 0.12),
                CGPoint(x: 0.85, y: 0.25),
                CGPoint(x: 0.9, y: 0.45),
                CGPoint(x: 0.85, y: 0.65),
                CGPoint(x: 0.7, y: 0.8),
                CGPoint(x: 0.5, y: 0.85),
                CGPoint(x: 0.3, y: 0.8),
                CGPoint(x: 0.15, y: 0.65),
                CGPoint(x: 0.1, y: 0.45),
                CGPoint(x: 0.15, y: 0.25),
                CGPoint(x: 0.3, y: 0.12),
                CGPoint(x: 0.5, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -1100.0,
            maxX: 900.0,
            minZ: -900.0,
            maxZ: 1100.0
        ),
        aspectRatio: 1.4,
        generatedAt: Date()
    ),
    "Zandvoort": PrebuiltTrackOutline(
        name: "Zandvoort",
        points: [
                CGPoint(x: 0.5, y: 0.1),
                CGPoint(x: 0.7, y: 0.12),
                CGPoint(x: 0.8, y: 0.25),
                CGPoint(x: 0.85, y: 0.45),
                CGPoint(x: 0.8, y: 0.65),
                CGPoint(x: 0.7, y: 0.8),
                CGPoint(x: 0.5, y: 0.88),
                CGPoint(x: 0.3, y: 0.8),
                CGPoint(x: 0.2, y: 0.65),
                CGPoint(x: 0.15, y: 0.45),
                CGPoint(x: 0.2, y: 0.25),
                CGPoint(x: 0.3, y: 0.12),
                CGPoint(x: 0.5, y: 0.1),
        ],
        bounds: PrebuiltTrackBounds(
            minX: -500.0,
            maxX: 1500.0,
            minZ: -400.0,
            maxZ: 1600.0
        ),
        aspectRatio: 1.1,
        generatedAt: Date()
    ),
    ]
    
    static func getTrack(name: String) -> PrebuiltTrackOutline? {
        return tracks[name]
    }
    
    static func hasTrack(name: String) -> Bool {
        return tracks[name] != nil
    }
    
    static var availableTrackNames: [String] {
        return Array(tracks.keys).sorted()
    }
    
    static var trackCount: Int {
        return tracks.count
    }
}