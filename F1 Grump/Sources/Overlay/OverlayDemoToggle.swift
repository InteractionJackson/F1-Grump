// README: OverlayDemoToggle
// Small SwiftUI view that shows how to enable/disable the track tile overlay
// from within your app. It uses the overlay controller and MapViewRepresentable.

import SwiftUI
import MapKit

struct OverlayDemoToggle: View {
    @State private var showOverlay = false
    @State private var mapView = MKMapView()
    @State private var controller: TrackOverlayController?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("Track overlay", isOn: Binding(get: {
                    showOverlay
                }, set: { v in
                    showOverlay = v
                    controller?.isEnabled = v
                }))
                .toggleStyle(.switch)
            }
            .onAppear {
                let cfg = TrackOverlayConfig(
                    id: "silverstone",
                    assetName: "Silverstone",
                    bbox: .init(west: -1.028, south: 52.057, east: -0.984, north: 52.090)
                )
                let c = TrackOverlayController(mapView: mapView)
                c.setOverlay(config: cfg)
                c.isEnabled = showOverlay
                controller = c
            }

            MapViewRepresentable(mapView: $mapView)
                .frame(height: 220)
                .cornerRadius(8)
        }
    }
}


