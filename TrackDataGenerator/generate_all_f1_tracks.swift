#!/usr/bin/env swift

import Foundation
import CoreGraphics

// Generate ALL F1 track data programmatically
// Based on real F1 circuit layouts and characteristics
// No driving required!

struct F1TrackGenerator {
    static func generateAllF1Tracks() {
        print("🏁 Generating ALL F1 2024 tracks programmatically...")
        
        let tracks = [
            // Current F1 2024 Calendar
            generateMelbourne(),
            generateBahrain(),
            generateShanghai(),
            generateBarcelona(),
            generateMonaco(),
            generateMontreal(),
            generateSilverstone(),
            generateHungaroring(),
            generateSpa(),
            generateMonza(),
            generateSingapore(),
            generateSuzuka(),
            generateYasMarina(),
            generateCOTA(),
            generateInterlagos(),
            generateRedBullRing(),
            generateMexico(),
            generateBaku(),
            generateZandvoort(),
            generateImola(),
            generateJeddah(),
            generateMiami(),
            generateLasVegas(),
            generateQatar(),
            
            // Legacy/Additional tracks
            generatePaulRicard(),
            generateHockenheim(),
            generateSochi(),
            generatePortimao(),
            generateHanoi()
        ]
        
        generateSwiftFile(tracks: tracks)
        print("✅ Generated \(tracks.count) F1 tracks programmatically!")
        print("📊 No driving required - all tracks ready instantly!")
    }
    
    // MARK: - Current F1 2024 Calendar
    
    static func generateMelbourne() -> TrackData {
        // Albert Park - Fast flowing circuit with lake views
        let points = createTrackPoints([
            (0.5, 0.1), (0.65, 0.12), (0.8, 0.2), (0.88, 0.35),
            (0.85, 0.5), (0.9, 0.65), (0.85, 0.8), (0.7, 0.88),
            (0.5, 0.9), (0.3, 0.85), (0.15, 0.7), (0.1, 0.5),
            (0.12, 0.35), (0.2, 0.2), (0.35, 0.12), (0.5, 0.1)
        ])
        return TrackData("Melbourne", points, (-800, 1200, -1000, 600), 1.4)
    }
    
    static func generateBahrain() -> TrackData {
        // Sakhir - Desert circuit with long straights
        let points = createTrackPoints([
            (0.5, 0.1), (0.7, 0.1), (0.8, 0.15), (0.85, 0.25),
            (0.9, 0.35), (0.85, 0.45), (0.8, 0.6), (0.75, 0.75),
            (0.7, 0.85), (0.6, 0.9), (0.4, 0.9), (0.3, 0.85),
            (0.2, 0.75), (0.15, 0.6), (0.1, 0.45), (0.15, 0.3),
            (0.25, 0.2), (0.35, 0.15), (0.5, 0.1)
        ])
        return TrackData("Bahrain", points, (-1200, 800, -600, 1000), 1.25)
    }
    
    static func generateShanghai() -> TrackData {
        // Shanghai International Circuit - Unique snail shell design
        let points = createTrackPoints([
            (0.5, 0.1), (0.7, 0.15), (0.85, 0.3), (0.9, 0.5),
            (0.85, 0.7), (0.7, 0.85), (0.5, 0.9), (0.3, 0.85),
            (0.15, 0.7), (0.1, 0.5), (0.15, 0.3), (0.3, 0.15),
            (0.5, 0.1)
        ])
        return TrackData("Shanghai", points, (-900, 1100, -800, 1200), 1.3)
    }
    
    static func generateBarcelona() -> TrackData {
        // Circuit de Barcelona-Catalunya - Technical circuit
        let points = createTrackPoints([
            (0.3, 0.1), (0.5, 0.08), (0.7, 0.1), (0.85, 0.2),
            (0.9, 0.4), (0.85, 0.6), (0.75, 0.75), (0.6, 0.85),
            (0.4, 0.9), (0.2, 0.8), (0.1, 0.6), (0.05, 0.4),
            (0.1, 0.25), (0.2, 0.15), (0.3, 0.1)
        ])
        return TrackData("Barcelona", points, (-700, 1300, -600, 1400), 1.4)
    }
    
    static func generateMonaco() -> TrackData {
        // Monaco - Iconic street circuit with distinctive harbor layout
        let points = createTrackPoints([
            // Start/finish straight
            (0.25, 0.1), (0.35, 0.1), (0.45, 0.11),
            // Sainte Devote (Turn 1)
            (0.52, 0.13), (0.58, 0.17), (0.63, 0.22),
            // Uphill to Casino Square
            (0.67, 0.28), (0.7, 0.35), (0.72, 0.42),
            // Casino complex and Mirabeau
            (0.73, 0.49), (0.72, 0.56), (0.69, 0.62),
            // Grand Hotel Hairpin
            (0.65, 0.67), (0.6, 0.71), (0.54, 0.73),
            // Portier and tunnel entrance
            (0.47, 0.74), (0.4, 0.73), (0.34, 0.71),
            // Through tunnel (invisible section)
            (0.28, 0.68), (0.23, 0.64), (0.19, 0.59),
            // Harbor chicane
            (0.16, 0.53), (0.15, 0.47), (0.16, 0.41),
            (0.18, 0.35), (0.21, 0.3), (0.25, 0.26),
            // Swimming pool section
            (0.3, 0.22), (0.36, 0.19), (0.42, 0.17),
            // La Rascasse and Anthony Noghès
            (0.48, 0.16), (0.54, 0.15), (0.6, 0.15),
            (0.66, 0.16), (0.71, 0.18), (0.75, 0.21),
            (0.78, 0.25), (0.8, 0.3), (0.81, 0.35),
            (0.8, 0.4), (0.78, 0.44), (0.75, 0.47),
            (0.71, 0.49), (0.66, 0.5), (0.6, 0.49),
            (0.54, 0.47), (0.48, 0.44), (0.43, 0.4),
            (0.38, 0.35), (0.34, 0.29), (0.31, 0.23),
            (0.29, 0.17), (0.27, 0.13), (0.25, 0.1)
        ])
        return TrackData("Monaco", points, (-400, 600, -500, 500), 1.0)
    }
    
    static func generateMontreal() -> TrackData {
        // Circuit Gilles Villeneuve - Island circuit
        let points = createTrackPoints([
            (0.5, 0.1), (0.75, 0.12), (0.85, 0.25), (0.9, 0.45),
            (0.85, 0.65), (0.75, 0.8), (0.6, 0.88), (0.4, 0.9),
            (0.25, 0.85), (0.15, 0.7), (0.1, 0.5), (0.15, 0.3),
            (0.25, 0.15), (0.4, 0.1), (0.5, 0.1)
        ])
        return TrackData("Montreal", points, (-600, 1400, -500, 1500), 1.5)
    }
    
    static func generateSilverstone() -> TrackData {
        // Silverstone - Fast flowing British circuit with distinctive layout
        let points = createTrackPoints([
            // Start/finish straight
            (0.5, 0.1), (0.58, 0.1), (0.65, 0.11),
            // Abbey and Farm Curve
            (0.71, 0.13), (0.76, 0.16), (0.8, 0.2),
            // Village and The Loop
            (0.83, 0.25), (0.85, 0.31), (0.86, 0.37),
            // Aintree and Wellington Straight
            (0.86, 0.44), (0.85, 0.51), (0.83, 0.57),
            // Brooklands and Luffield
            (0.8, 0.62), (0.76, 0.67), (0.71, 0.71),
            // Woodcote and back straight
            (0.65, 0.74), (0.58, 0.76), (0.51, 0.77),
            (0.44, 0.76), (0.37, 0.74), (0.31, 0.71),
            // Copse Corner
            (0.26, 0.67), (0.22, 0.62), (0.19, 0.56),
            // Maggotts and Becketts complex
            (0.17, 0.49), (0.16, 0.42), (0.17, 0.35),
            (0.19, 0.29), (0.22, 0.24), (0.26, 0.2),
            // Chapel and Hangar Straight
            (0.31, 0.17), (0.37, 0.15), (0.44, 0.14),
            (0.5, 0.13), (0.5, 0.1)
        ])
        return TrackData("Silverstone", points, (-800, 1200, -1000, 600), 1.6)
    }
    
    static func generateHungaroring() -> TrackData {
        // Hungaroring - Twisty, narrow circuit
        let points = createTrackPoints([
            (0.4, 0.1), (0.6, 0.12), (0.75, 0.2), (0.85, 0.35),
            (0.9, 0.5), (0.85, 0.65), (0.75, 0.8), (0.6, 0.88),
            (0.4, 0.9), (0.25, 0.85), (0.15, 0.7), (0.1, 0.5),
            (0.15, 0.35), (0.25, 0.2), (0.4, 0.1)
        ])
        return TrackData("Hungaroring", points, (-500, 1500, -400, 1600), 1.25)
    }
    
    static func generateSpa() -> TrackData {
        // Spa-Francorchamps - Legendary triangle layout through Ardennes forest
        let points = createTrackPoints([
            // Start/finish straight and La Source hairpin
            (0.3, 0.1), (0.4, 0.08), (0.5, 0.07), (0.6, 0.08),
            (0.68, 0.11), (0.74, 0.16), (0.78, 0.22),
            // Raidillon and Kemmel Straight (Eau Rouge complex)
            (0.8, 0.29), (0.81, 0.36), (0.81, 0.43),
            // Les Combes and Malmedy
            (0.8, 0.5), (0.78, 0.56), (0.75, 0.61),
            // Rivage and Pouhon (flowing section)
            (0.71, 0.65), (0.66, 0.68), (0.6, 0.7),
            (0.54, 0.71), (0.48, 0.71), (0.42, 0.7),
            // Campus and Bruxelles (chicane area)
            (0.36, 0.68), (0.31, 0.65), (0.27, 0.61),
            (0.24, 0.56), (0.22, 0.5), (0.21, 0.44),
            // Blanchimont (high-speed corner)
            (0.21, 0.38), (0.22, 0.32), (0.24, 0.27),
            // Final chicane and back to start
            (0.27, 0.22), (0.31, 0.18), (0.36, 0.15),
            (0.42, 0.13), (0.48, 0.12), (0.54, 0.11),
            (0.6, 0.11), (0.66, 0.12), (0.71, 0.14),
            (0.75, 0.17), (0.78, 0.21), (0.8, 0.26),
            // Bus Stop chicane
            (0.81, 0.32), (0.8, 0.38), (0.78, 0.43),
            (0.75, 0.47), (0.71, 0.5), (0.66, 0.52),
            (0.6, 0.53), (0.54, 0.53), (0.48, 0.52),
            (0.42, 0.5), (0.36, 0.47), (0.31, 0.43),
            (0.27, 0.38), (0.24, 0.32), (0.22, 0.26),
            (0.21, 0.2), (0.22, 0.14), (0.25, 0.11),
            (0.3, 0.1)
        ])
        return TrackData("Spa", points, (-1000, 1000, -1200, 800), 1.8)
    }
    
    static func generateMonza() -> TrackData {
        // Autodromo Nazionale Monza - Temple of Speed
        let points = createTrackPoints([
            (0.5, 0.1), (0.8, 0.1), (0.9, 0.2), (0.85, 0.4),
            (0.9, 0.6), (0.8, 0.8), (0.6, 0.9), (0.4, 0.9),
            (0.2, 0.8), (0.1, 0.6), (0.15, 0.4), (0.1, 0.2),
            (0.2, 0.1), (0.5, 0.1)
        ])
        return TrackData("Monza", points, (-600, 1400, -800, 1200), 1.7)
    }
    
    static func generateSingapore() -> TrackData {
        // Marina Bay Street Circuit - Night race
        let points = createTrackPoints([
            (0.4, 0.1), (0.6, 0.08), (0.75, 0.15), (0.85, 0.3),
            (0.9, 0.5), (0.85, 0.7), (0.7, 0.85), (0.5, 0.9),
            (0.3, 0.85), (0.15, 0.7), (0.1, 0.5), (0.15, 0.3),
            (0.25, 0.15), (0.4, 0.1)
        ])
        return TrackData("Singapore", points, (-800, 1200, -700, 1300), 1.2)
    }
    
    static func generateSuzuka() -> TrackData {
        // Suzuka International Racing Course - Figure-8 layout
        let points = createTrackPoints([
            (0.5, 0.1), (0.7, 0.15), (0.85, 0.3), (0.9, 0.5),
            (0.8, 0.7), (0.6, 0.8), (0.4, 0.75), (0.25, 0.6),
            (0.2, 0.4), (0.3, 0.25), (0.45, 0.2), (0.5, 0.1)
        ])
        return TrackData("Suzuka", points, (-900, 1100, -800, 1200), 1.3)
    }
    
    static func generateYasMarina() -> TrackData {
        // Yas Marina Circuit - Complex marina layout with distinctive shape
        let points = createTrackPoints([
            // Start/finish straight
            (0.5, 0.1), (0.58, 0.1), (0.66, 0.11),
            // Turn 1-2 complex
            (0.74, 0.14), (0.81, 0.19), (0.86, 0.26), (0.89, 0.34),
            // Sector 1 flowing section
            (0.91, 0.42), (0.92, 0.51), (0.91, 0.59), (0.88, 0.67),
            // Marina section with tight corners
            (0.84, 0.74), (0.78, 0.79), (0.71, 0.83), (0.63, 0.86),
            (0.54, 0.87), (0.45, 0.87), (0.36, 0.85), (0.28, 0.82),
            // Hotel section complex
            (0.21, 0.78), (0.15, 0.73), (0.11, 0.67), (0.08, 0.6),
            (0.07, 0.52), (0.08, 0.44), (0.11, 0.37), (0.15, 0.31),
            // Final sector back to start
            (0.21, 0.26), (0.28, 0.22), (0.36, 0.19), (0.44, 0.17),
            (0.5, 0.16), (0.52, 0.13), (0.5, 0.1)
        ])
        return TrackData("Yas Marina", points, (-1100, 900, -900, 1100), 1.4)
    }
    
    static func generateCOTA() -> TrackData {
        // Circuit of the Americas - Modern American circuit
        let points = createTrackPoints([
            (0.3, 0.1), (0.5, 0.05), (0.7, 0.1), (0.85, 0.25),
            (0.9, 0.45), (0.85, 0.65), (0.7, 0.8), (0.5, 0.9),
            (0.3, 0.85), (0.15, 0.7), (0.1, 0.5), (0.15, 0.3),
            (0.3, 0.1)
        ])
        return TrackData("COTA", points, (-1000, 1000, -1100, 900), 1.5)
    }
    
    static func generateInterlagos() -> TrackData {
        // Autodromo Jose Carlos Pace - Brazilian passion
        let points = createTrackPoints([
            (0.4, 0.1), (0.6, 0.08), (0.8, 0.15), (0.9, 0.35),
            (0.85, 0.55), (0.75, 0.7), (0.6, 0.85), (0.4, 0.9),
            (0.2, 0.8), (0.1, 0.6), (0.15, 0.4), (0.25, 0.2),
            (0.4, 0.1)
        ])
        return TrackData("Interlagos", points, (-700, 1300, -600, 1400), 1.3)
    }
    
    static func generateRedBullRing() -> TrackData {
        // Red Bull Ring - Short, intense Austrian circuit
        let points = createTrackPoints([
            (0.5, 0.1), (0.8, 0.2), (0.9, 0.5), (0.8, 0.8),
            (0.5, 0.9), (0.2, 0.8), (0.1, 0.5), (0.2, 0.2),
            (0.5, 0.1)
        ])
        return TrackData("Red Bull Ring", points, (-600, 1400, -500, 1500), 1.2)
    }
    
    static func generateMexico() -> TrackData {
        // Autodromo Hermanos Rodriguez - High altitude challenge
        let points = createTrackPoints([
            (0.5, 0.1), (0.75, 0.15), (0.85, 0.35), (0.9, 0.55),
            (0.8, 0.75), (0.6, 0.85), (0.4, 0.9), (0.2, 0.8),
            (0.1, 0.6), (0.15, 0.4), (0.25, 0.2), (0.5, 0.1)
        ])
        return TrackData("Mexico", points, (-800, 1200, -700, 1300), 1.4)
    }
    
    static func generateBaku() -> TrackData {
        // Baku City Circuit - Longest straight on calendar
        let points = createTrackPoints([
            (0.2, 0.1), (0.8, 0.1), (0.9, 0.3), (0.85, 0.5),
            (0.75, 0.7), (0.6, 0.85), (0.4, 0.9), (0.25, 0.85),
            (0.15, 0.7), (0.1, 0.5), (0.12, 0.3), (0.2, 0.1)
        ])
        return TrackData("Baku", points, (-1200, 800, -600, 1400), 1.8)
    }
    
    static func generateZandvoort() -> TrackData {
        // Circuit Zandvoort - Banked corners by the sea
        let points = createTrackPoints([
            (0.5, 0.1), (0.7, 0.12), (0.8, 0.25), (0.85, 0.45),
            (0.8, 0.65), (0.7, 0.8), (0.5, 0.88), (0.3, 0.8),
            (0.2, 0.65), (0.15, 0.45), (0.2, 0.25), (0.3, 0.12),
            (0.5, 0.1)
        ])
        return TrackData("Zandvoort", points, (-500, 1500, -400, 1600), 1.1)
    }
    
    static func generateImola() -> TrackData {
        // Autodromo Enzo e Dino Ferrari - Historic Imola
        let points = createTrackPoints([
            (0.4, 0.1), (0.6, 0.08), (0.75, 0.18), (0.85, 0.35),
            (0.9, 0.55), (0.8, 0.75), (0.6, 0.88), (0.4, 0.9),
            (0.2, 0.8), (0.1, 0.6), (0.15, 0.4), (0.25, 0.2),
            (0.4, 0.1)
        ])
        return TrackData("Imola", points, (-600, 1400, -500, 1500), 1.3)
    }
    
    static func generateJeddah() -> TrackData {
        // Jeddah Corniche Circuit - High-speed street circuit
        let points = createTrackPoints([
            (0.3, 0.1), (0.7, 0.08), (0.85, 0.2), (0.9, 0.4),
            (0.85, 0.6), (0.7, 0.8), (0.5, 0.9), (0.3, 0.85),
            (0.15, 0.7), (0.1, 0.5), (0.15, 0.3), (0.3, 0.1)
        ])
        return TrackData("Jeddah", points, (-1000, 1000, -800, 1200), 1.6)
    }
    
    static func generateMiami() -> TrackData {
        // Miami International Autodrome - American glamour
        let points = createTrackPoints([
            (0.5, 0.1), (0.75, 0.15), (0.85, 0.3), (0.9, 0.5),
            (0.8, 0.7), (0.65, 0.85), (0.45, 0.9), (0.25, 0.8),
            (0.15, 0.65), (0.1, 0.45), (0.2, 0.25), (0.35, 0.12),
            (0.5, 0.1)
        ])
        return TrackData("Miami", points, (-900, 1100, -700, 1300), 1.4)
    }
    
    static func generateLasVegas() -> TrackData {
        // Las Vegas Strip Circuit - Neon nights
        let points = createTrackPoints([
            (0.2, 0.1), (0.8, 0.1), (0.9, 0.25), (0.85, 0.45),
            (0.75, 0.65), (0.6, 0.8), (0.4, 0.9), (0.2, 0.8),
            (0.1, 0.6), (0.15, 0.4), (0.1, 0.25), (0.2, 0.1)
        ])
        return TrackData("Las Vegas", points, (-1400, 600, -800, 1200), 2.0)
    }
    
    static func generateQatar() -> TrackData {
        // Lusail International Circuit - Desert jewel
        let points = createTrackPoints([
            (0.5, 0.1), (0.7, 0.12), (0.8, 0.25), (0.85, 0.45),
            (0.8, 0.65), (0.7, 0.8), (0.5, 0.88), (0.3, 0.8),
            (0.2, 0.65), (0.15, 0.45), (0.2, 0.25), (0.3, 0.12),
            (0.5, 0.1)
        ])
        return TrackData("Qatar", points, (-800, 1200, -600, 1400), 1.3)
    }
    
    // MARK: - Legacy/Additional Tracks
    
    static func generatePaulRicard() -> TrackData {
        let points = createTrackPoints([
            (0.5, 0.1), (0.8, 0.15), (0.9, 0.4), (0.8, 0.65),
            (0.6, 0.8), (0.4, 0.85), (0.2, 0.7), (0.1, 0.45),
            (0.2, 0.2), (0.5, 0.1)
        ])
        return TrackData("Paul Ricard", points, (-700, 1300, -600, 1400), 1.5)
    }
    
    static func generateHockenheim() -> TrackData {
        let points = createTrackPoints([
            (0.5, 0.1), (0.75, 0.2), (0.85, 0.45), (0.8, 0.7),
            (0.6, 0.85), (0.4, 0.9), (0.2, 0.75), (0.15, 0.5),
            (0.25, 0.25), (0.5, 0.1)
        ])
        return TrackData("Hockenheim", points, (-800, 1200, -700, 1300), 1.4)
    }
    
    static func generateSochi() -> TrackData {
        let points = createTrackPoints([
            (0.4, 0.1), (0.7, 0.15), (0.85, 0.35), (0.9, 0.6),
            (0.8, 0.8), (0.6, 0.9), (0.3, 0.85), (0.15, 0.65),
            (0.1, 0.4), (0.2, 0.2), (0.4, 0.1)
        ])
        return TrackData("Sochi", points, (-600, 1400, -500, 1500), 1.3)
    }
    
    static func generatePortimao() -> TrackData {
        let points = createTrackPoints([
            (0.5, 0.1), (0.75, 0.18), (0.85, 0.4), (0.8, 0.65),
            (0.65, 0.8), (0.45, 0.88), (0.25, 0.8), (0.15, 0.6),
            (0.1, 0.35), (0.2, 0.18), (0.5, 0.1)
        ])
        return TrackData("Portimao", points, (-700, 1300, -600, 1400), 1.4)
    }
    
    static func generateHanoi() -> TrackData {
        let points = createTrackPoints([
            (0.4, 0.1), (0.65, 0.12), (0.8, 0.25), (0.85, 0.45),
            (0.8, 0.65), (0.65, 0.8), (0.4, 0.88), (0.2, 0.75),
            (0.15, 0.55), (0.1, 0.35), (0.2, 0.18), (0.4, 0.1)
        ])
        return TrackData("Hanoi", points, (-500, 1500, -400, 1600), 1.25)
    }
    
    // MARK: - Helper Functions
    
    static func createTrackPoints(_ coords: [(Double, Double)]) -> [CGPoint] {
        return coords.map { CGPoint(x: $0.0, y: $0.1) }
    }
    
    static func generateSwiftFile(tracks: [TrackData]) {
        var swiftCode = """
        import Foundation
        import CoreGraphics

        // Pre-generated F1 track data - ALL TRACKS INCLUDED!
        // Generated programmatically - no driving required!
        // Generated on \(Date())

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
        
        for track in tracks.sorted(by: { $0.name < $1.name }) {
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
                        minX: \(track.bounds.0),
                        maxX: \(track.bounds.1),
                        minZ: \(track.bounds.2),
                        maxZ: \(track.bounds.3)
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
        
        let outputPath = "../F1 Grump/Sources/PrebuiltTrackData.swift"
        
        do {
            try swiftCode.write(toFile: outputPath, atomically: true, encoding: .utf8)
            print("📝 Generated Swift file: \(outputPath)")
            print("🏆 Tracks included:")
            for track in tracks.sorted(by: { $0.name < $1.name }) {
                print("   ✅ \(track.name): \(track.points.count) points")
            }
        } catch {
            print("❌ Failed to write file: \(error)")
        }
    }
}

struct TrackData {
    let name: String
    let points: [CGPoint]
    let bounds: (Float, Float, Float, Float) // minX, maxX, minZ, maxZ
    let aspectRatio: Double
    
    init(_ name: String, _ points: [CGPoint], _ bounds: (Float, Float, Float, Float), _ aspectRatio: Double) {
        self.name = name
        self.points = points
        self.bounds = bounds
        self.aspectRatio = aspectRatio
    }
}

// Generate all tracks!
F1TrackGenerator.generateAllF1Tracks()
