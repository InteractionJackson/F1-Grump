// README: WebMercator helpers
// Pure helpers for lon/lat <-> Spherical Mercator meters <-> tile XY <-> pixel coords.
// Unit-test friendly and side-effect free.

import CoreGraphics

public enum WebMercator {
    public static let tileSize: Int = 256
    public static let earthRadius: Double = 6378137.0
    public static let originShift: Double = 2.0 * .pi * earthRadius / 2.0 // 20037508.342789244

    // lon/lat (deg) -> mercator meters (x,y)
    public static func lonLatToMeters(lon: Double, lat: Double) -> (x: Double, y: Double) {
        let x = lon * originShift / 180.0
        let clampedLat = min(85.05112878, max(-85.05112878, lat))
        let y = log(tan((90.0 + clampedLat) * .pi / 360.0)) / (.pi / 180.0)
        let ym = y * originShift / 180.0
        return (x, ym)
    }

    // mercator meters -> lon/lat
    public static func metersToLonLat(x: Double, y: Double) -> (lon: Double, lat: Double) {
        let lon = (x / originShift) * 180.0
        let lat = (y / originShift) * 180.0
        let latRad = lat * .pi / 180.0
        let latDeg = 180.0 / .pi * (2.0 * atan(exp(latRad)) - .pi / 2.0)
        return (lon, latDeg)
    }

    // resolution (meters/pixel) for zoom
    public static func resolution(zoom: Int) -> Double {
        let initialRes = 2.0 * .pi * earthRadius / Double(tileSize)
        return initialRes / pow(2.0, Double(zoom))
    }

    // mercator meters -> tile XY at zoom
    public static func metersToTile(x: Double, y: Double, zoom: Int) -> (tx: Int, ty: Int) {
        let res = resolution(zoom: zoom)
        let px = (x + originShift) / res
        let py = (y + originShift) / res
        let tx = Int(px) / tileSize
        let ty = Int(py) / tileSize
        return (tx, ty)
    }

    // tile XY -> mercator meters bounding box
    public static func tileBounds(tx: Int, ty: Int, zoom: Int) -> (minx: Double, miny: Double, maxx: Double, maxy: Double) {
        let res = resolution(zoom: zoom)
        let minx = Double(tx * tileSize) * res - originShift
        let miny = Double(ty * tileSize) * res - originShift
        let maxx = Double((tx + 1) * tileSize) * res - originShift
        let maxy = Double((ty + 1) * tileSize) * res - originShift
        return (minx, miny, maxx, maxy)
    }

    // lon/lat -> tile XY
    public static func lonLatToTile(lon: Double, lat: Double, zoom: Int) -> (tx: Int, ty: Int) {
        let m = lonLatToMeters(lon: lon, lat: lat)
        return metersToTile(x: m.x, y: m.y, zoom: zoom)
    }

    // lon/lat -> pixel location in given tile
    public static func lonLatToPixelInTile(lon: Double, lat: Double, tx: Int, ty: Int, zoom: Int) -> CGPoint {
        let res = resolution(zoom: zoom)
        let m = lonLatToMeters(lon: lon, lat: lat)
        let px = (m.x + originShift) / res - Double(tx * tileSize)
        let py = (m.y + originShift) / res - Double(ty * tileSize)
        return CGPoint(x: px, y: Double(tileSize) - py) // y down
    }
}


