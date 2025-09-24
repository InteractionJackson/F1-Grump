// README: TeamColors
// F1 team color mappings based on team IDs from telemetry data.
// Provides authentic team colors for car dot visualization.

import SwiftUI

struct TeamColors {
    // F1 2024 Team ID mappings with official team colors
    static func colorForTeam(_ teamId: UInt8) -> Color {
        switch teamId {
        case 0:  return Color(hex: "#27F4D2")        // Mercedes
        case 1:  return Color(hex: "#E80002")        // Ferrari
        case 2:  return Color(hex: "#FF8000")        // McLaren
        case 3:  return Color(hex: "#0093CC")        // Alpine
        case 4:  return Color(hex: "#229971")        // Aston Martin
        case 5:  return Color(hex: "#3671C6")        // Red Bull
        case 6:  return Color(hex: "#6692FF")        // Racing Bulls (AlphaTauri)
        case 7:  return Color(hex: "#B6BABD")        // Haas
        case 8:  return Color(hex: "#64C4FF")        // Williams
        case 9:  return Color(hex: "#52E252")        // Kick Sauber (Alfa Romeo)
        case 10: return Color(hex: "#FF8000")        // McLaren Alt
        default: return Color.white.opacity(0.8)     // Default/Unknown
        }
    }
    
    // Get team name for display (optional)
    static func nameForTeam(_ teamId: UInt8) -> String {
        switch teamId {
        case 0:  return "Mercedes"
        case 1:  return "Ferrari" 
        case 2:  return "McLaren"
        case 3:  return "Alpine"
        case 4:  return "Aston Martin"
        case 5:  return "Red Bull"
        case 6:  return "Racing Bulls"
        case 7:  return "Haas"
        case 8:  return "Williams"
        case 9:  return "Kick Sauber"
        case 10: return "McLaren"
        default: return "Unknown"
        }
    }
    
    // Brighter version for player car highlighting
    static func brightColorForTeam(_ teamId: UInt8) -> Color {
        let base = colorForTeam(teamId)
        // Increase brightness/saturation for player car
        return base.opacity(1.0)
    }
}
