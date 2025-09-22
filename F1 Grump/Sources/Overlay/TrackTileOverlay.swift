// README: TrackTileOverlay
// MKTileOverlay subclass that renders SVG track outlines (from bundle assets)
// into transparent raster Web Mercator tiles on-device. Visible only in zoom 14–20.

import MapKit
import CoreGraphics

public final class TrackTileOverlay: MKTileOverlay {
    public let config: TrackOverlayConfig

    public init(config: TrackOverlayConfig) {
        self.config = config
        super.init(urlTemplate: nil)
        canReplaceMapContent = false
        tileSize = CGSize(width: WebMercator.tileSize, height: WebMercator.tileSize)
    }

    public override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        // Clamp visibility
        if path.z < config.minZoom || path.z > config.maxZoom {
            result(Data(), nil) // empty transparent
            return
        }

        // Load/calc paths once per bbox/id
        guard let svg = SVGPathLoader.shared.load(assetName: config.assetName, bbox: config.bbox) else {
            result(Data(), nil)
            return
        }

        // Tile mercator bounds
        let tb = WebMercator.tileBounds(tx: path.x, ty: path.y, zoom: path.z)
        let tileRectMerc = CGRect(x: tb.minx, y: tb.miny, width: tb.maxx - tb.minx, height: tb.maxy - tb.miny)

        // If the svg mercator bounds do not intersect tile, return transparent
        if !svg.mercatorBounds.intersects(tileRectMerc) {
            result(Data(), nil)
            return
        }

        // Render at 1x (MapKit will handle @2x requests by doubling path.z tileSize == 256)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: WebMercator.tileSize, height: WebMercator.tileSize), format: format)
        let data = renderer.pngData { ctx in
            let cg = ctx.cgContext
            cg.setFillColor(UIColor.clear.cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: WebMercator.tileSize, height: WebMercator.tileSize))

            // Build mercator->tile pixel transform
            let sx = CGFloat(WebMercator.tileSize) / CGFloat(tileRectMerc.width)
            let sy = CGFloat(WebMercator.tileSize) / CGFloat(tileRectMerc.height)
            var T = CGAffineTransform.identity
            // 1) translate mercator -> tile origin
            T = T.translatedBy(x: -CGFloat(tileRectMerc.minX), y: -CGFloat(tileRectMerc.minY))
            // 2) scale to pixels
            T = T.scaledBy(x: sx, y: sy)
            // 3) y-flip into raster coordinate (y down)
            T = T.concatenating(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(WebMercator.tileSize)))

            if let path = svg.mercatorPath.copy(using: &T) {
                cg.setStrokeColor(UIColor(red: 0.604, green: 0.902, blue: 1.0, alpha: 0.70).cgColor) // #9AE6FF @70%
                cg.setLineWidth(2)
                cg.setLineJoin(.round)
                cg.setLineCap(.round)
                cg.addPath(path)
                cg.strokePath()
            }
        }
        result(data, nil)
    }
}


