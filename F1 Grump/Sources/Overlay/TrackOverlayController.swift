// README: TrackOverlayController
// Convenience object for creating/removing a TrackTileOverlay on an MKMapView.
// Includes SwiftUI-friendly toggle functions.

import MapKit
import SwiftUI

public final class TrackOverlayController: ObservableObject {
    public private(set) var overlay: TrackTileOverlay?
    public private(set) weak var mapView: MKMapView?
    @Published public var isEnabled: Bool = false {
        didSet { updateOverlayVisibility() }
    }

    public init(mapView: MKMapView?) {
        self.mapView = mapView
    }

    public func setOverlay(config: TrackOverlayConfig) {
        removeOverlay()
        let ov = TrackTileOverlay(config: config)
        overlay = ov
        if isEnabled { addOverlay() }
    }

    private func addOverlay() {
        guard let mv = mapView, let ov = overlay else { return }
        mv.addOverlay(ov, level: .aboveLabels)
    }

    private func removeOverlay() {
        guard let mv = mapView, let ov = overlay else { return }
        mv.removeOverlay(ov)
    }

    private func updateOverlayVisibility() {
        guard let mv = mapView, let ov = overlay else { return }
        if isEnabled {
            if !mv.overlays.contains(where: { $0 === ov }) { mv.addOverlay(ov, level: .aboveLabels) }
        } else {
            if mv.overlays.contains(where: { $0 === ov }) { mv.removeOverlay(ov) }
        }
    }
}

// SwiftUI integration snippet (usage example):
// struct MapOverlayToggleView: View {
//     @State private var showOverlay = false
//     @State private var mapView = MKMapView()
//     private var controller: TrackOverlayController
//
//     init() {
//         controller = TrackOverlayController(mapView: mapView)
//         let cfg = TrackOverlayConfig(
//             id: "silverstone",
//             assetName: "Silverstone",
//             bbox: .init(west: -1.028, south: 52.057, east: -0.984, north: 52.090)
//         )
//         controller.setOverlay(config: cfg)
//     }
//
//     var body: some View {
//         VStack {
//             Toggle("Track overlay", isOn: Binding(get: { showOverlay }, set: { v in
//                 showOverlay = v
//                 controller.isEnabled = v
//             }))
//             MapViewRepresentable(mapView: $mapView)
//         }
//     }
// }


