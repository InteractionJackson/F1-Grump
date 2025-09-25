#!/usr/bin/env swift

import Foundation
import CoreGraphics

// Quick script to generate sample track data for testing
// This creates a few sample tracks so we can test the prebuilt system

struct SampleTrackGenerator {
    static func generateSampleTracks() {
        let tracks = [
            generateBahrainTrack(),
            generateSilverstoneTrack(),
            generateMonacoTrack()
        ]
        
        // Generate the PrebuiltTrackData.swift file
        var swiftCode = """
        import Foundation
        import CoreGraphics

        // Pre-generated F1 track data
        // Sample data for testing - replace with real data from TrackDataGenerator

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
        """
        
        for track in tracks {
            swiftCode += """
            
                "\(track.name)": PrebuiltTrackOutline(
                    name: "\(track.name)",
                    points: [
            """
            
            for point in track.points {
                swiftCode += "\n                CGPoint(x: \(point.x), y: \(point.y)),"
            }
            
            swiftCode += """
            
                    ],
                    bounds: PrebuiltTrackBounds(
                        minX: \(track.bounds.minX),
                        maxX: \(track.bounds.maxX),
                        minZ: \(track.bounds.minZ),
                        maxZ: \(track.bounds.maxZ)
                    ),
                    aspectRatio: \(track.aspectRatio),
                    generatedAt: Date()
                ),
            """
        }
        
        swiftCode += """
        
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
        """
        
        // Write to the F1 Grump project
        let outputPath = "../F1 Grump/Sources/PrebuiltTrackData.swift"
        
        do {
            try swiftCode.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print("✅ Generated sample track data: \(outputPath)")
            print("📊 Created \(tracks.count) sample tracks:")
            for track in tracks {
                print("   - \(track.name): \(track.points.count) points")
            }
        } catch {
            print("❌ Failed to write file: \(error)")
        }
    }
    
    static func generateBahrainTrack() -> TrackData {
        // Create a realistic Bahrain-shaped track (roughly rectangular with curves)
        let points: [CGPoint] = [
            // Start/finish straight
            CGPoint(x: 0.5, y: 0.1),
            CGPoint(x: 0.7, y: 0.1),
            CGPoint(x: 0.8, y: 0.15),
            
            // Turn 1-3 complex
            CGPoint(x: 0.85, y: 0.25),
            CGPoint(x: 0.9, y: 0.35),
            CGPoint(x: 0.85, y: 0.45),
            
            // Back straight
            CGPoint(x: 0.8, y: 0.6),
            CGPoint(x: 0.75, y: 0.75),
            CGPoint(x: 0.7, y: 0.85),
            
            // Final sector
            CGPoint(x: 0.6, y: 0.9),
            CGPoint(x: 0.4, y: 0.9),
            CGPoint(x: 0.3, y: 0.85),
            CGPoint(x: 0.2, y: 0.75),
            CGPoint(x: 0.15, y: 0.6),
            CGPoint(x: 0.1, y: 0.45),
            CGPoint(x: 0.15, y: 0.3),
            CGPoint(x: 0.25, y: 0.2),
            CGPoint(x: 0.35, y: 0.15),
            CGPoint(x: 0.5, y: 0.1) // Close loop
        ]
        
        return TrackData(
            name: "Bahrain",
            points: points,
            bounds: TrackBounds(minX: -1200, maxX: 800, minZ: -600, maxZ: 1000),
            aspectRatio: 1.25
        )
    }
    
    static func generateSilverstoneTrack() -> TrackData {
        // Create Silverstone's distinctive shape
        let points: [CGPoint] = [
            // Start/finish
            CGPoint(x: 0.5, y: 0.1),
            CGPoint(x: 0.65, y: 0.1),
            
            // Copse, Maggotts, Becketts complex
            CGPoint(x: 0.75, y: 0.15),
            CGPoint(x: 0.85, y: 0.25),
            CGPoint(x: 0.9, y: 0.4),
            CGPoint(x: 0.85, y: 0.55),
            
            // Hangar Straight area
            CGPoint(x: 0.8, y: 0.7),
            CGPoint(x: 0.7, y: 0.85),
            CGPoint(x: 0.55, y: 0.9),
            
            // Club corner area
            CGPoint(x: 0.4, y: 0.85),
            CGPoint(x: 0.25, y: 0.75),
            CGPoint(x: 0.15, y: 0.6),
            CGPoint(x: 0.1, y: 0.4),
            CGPoint(x: 0.15, y: 0.25),
            CGPoint(x: 0.3, y: 0.15),
            CGPoint(x: 0.5, y: 0.1) // Close
        ]
        
        return TrackData(
            name: "Silverstone",
            points: points,
            bounds: TrackBounds(minX: -800, maxX: 1200, minZ: -1000, maxZ: 600),
            aspectRatio: 1.6
        )
    }
    
    static func generateMonacoTrack() -> TrackData {
        // Monaco's unique street circuit shape
        let points: [CGPoint] = [
            // Start/finish
            CGPoint(x: 0.3, y: 0.1),
            CGPoint(x: 0.5, y: 0.1),
            
            // Casino complex
            CGPoint(x: 0.65, y: 0.15),
            CGPoint(x: 0.8, y: 0.25),
            CGPoint(x: 0.9, y: 0.4),
            
            // Swimming pool section
            CGPoint(x: 0.85, y: 0.6),
            CGPoint(x: 0.75, y: 0.75),
            CGPoint(x: 0.6, y: 0.8),
            
            // Rascasse
            CGPoint(x: 0.4, y: 0.85),
            CGPoint(x: 0.25, y: 0.8),
            CGPoint(x: 0.15, y: 0.65),
            
            // Tunnel and harbor
            CGPoint(x: 0.1, y: 0.45),
            CGPoint(x: 0.15, y: 0.3),
            CGPoint(x: 0.25, y: 0.2),
            CGPoint(x: 0.3, y: 0.1) // Close
        ]
        
        return TrackData(
            name: "Monaco",
            points: points,
            bounds: TrackBounds(minX: -400, maxX: 600, minZ: -500, maxZ: 500),
            aspectRatio: 1.0
        )
    }
}

struct TrackData {
    let name: String
    let points: [CGPoint]
    let bounds: TrackBounds
    let aspectRatio: Double
}

struct TrackBounds {
    let minX: Float
    let maxX: Float
    let minZ: Float
    let maxZ: Float
}

// Run the generator
SampleTrackGenerator.generateSampleTracks()
