import Foundation

/// Maps F1 UDP trackId to a human-friendly track name that should fuzzy-match SVG filenames.
enum TrackMap {
    /// Return a name like "Silverstone", "Monza", etc. Empty if unknown.
    static func name(for id: Int) -> String {
        switch id {
        case 0:  return "Melbourne"         // Australia
        case 1:  return "Paul Ricard"       // France (legacy)
        case 2:  return "Shanghai"          // China
        case 3:  return "Bahrain"           // Sakhir
        case 4:  return "Barcelona"         // Spain Catalunya
        case 5:  return "Monaco"            // Monte Carlo
        case 6:  return "Montreal"          // Canada
        case 7:  return "Silverstone"       // Great Britain
        case 8:  return "Hockenheim"        // Germany (legacy)
        case 9:  return "Hungaroring"       // Hungary
        case 10: return "Spa"               // Belgium
        case 11: return "Monza"             // Italy
        case 12: return "Singapore"         // Marina Bay
        case 13: return "Suzuka"            // Japan
        case 14: return "Yas Marina"        // Abu Dhabi
        case 15: return "COTA"              // USA Austin
        case 16: return "Interlagos"        // Brazil
        case 17: return "Red Bull Ring"     // Austria
        case 18: return "Sochi"             // Russia (legacy)
        case 19: return "Mexico"            // Mexico City
        case 20: return "Baku"              // Azerbaijan
        case 21: return "Sakhir Short"      // Short variants (legacy)
        case 22: return "Silverstone Short"
        case 23: return "COTA Short"
        case 24: return "Suzuka Short"
        case 25: return "Monza Short"
        case 26: return "Hanoi"             // Vietnam (legacy)
        case 27: return "Zandvoort"         // Netherlands
        case 28: return "Imola"             // Emilia Romagna
        case 29: return "Portimao"          // Portugal
        case 30: return "Jeddah"            // Saudi Arabia
        case 31: return "Miami"             // USA Miami
        case 32: return "Las Vegas"         // USA Las Vegas
        case 33: return "Qatar"             // Lusail
        default: return ""
        }
    }
}


