// README: TrackOverlayConfig
// A tiny model describing one track overlay:
// - id: stable identifier you choose (e.g., "silverstone")
// - assetName: the SVG asset name inside Assets.xcassets/track outlines/
// - bbox: geographic bounding box of the overlay in lon/lat (Web Mercator)
// - minZoom/maxZoom: tile zoom clamp; overlay will render only within this range

import CoreLocation

public struct TrackOverlayConfig: Sendable, Hashable {
    public struct BBox: Sendable, Hashable {
        public var west: Double   // lon min
        public var south: Double  // lat min
        public var east: Double   // lon max
        public var north: Double  // lat max
        public init(west: Double, south: Double, east: Double, north: Double) {
            self.west = west; self.south = south; self.east = east; self.north = north
        }
    }

    public let id: String
    public let assetName: String
    public let bbox: BBox
    public let minZoom: Int
    public let maxZoom: Int

    public init(id: String, assetName: String, bbox: BBox, minZoom: Int = 14, maxZoom: Int = 20) {
        self.id = id
        self.assetName = assetName
        self.bbox = bbox
        self.minZoom = minZoom
        self.maxZoom = maxZoom
    }
}


