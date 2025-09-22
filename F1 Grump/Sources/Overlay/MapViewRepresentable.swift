// README: MapViewRepresentable
// Minimal SwiftUI wrapper for MKMapView so we can add our TrackTileOverlay from SwiftUI.

import SwiftUI
import MapKit

public struct MapViewRepresentable: UIViewRepresentable {
    @Binding public var mapView: MKMapView

    public init(mapView: Binding<MKMapView>) {
        self._mapView = mapView
    }

    public func makeUIView(context: Context) -> MKMapView {
        mapView
    }

    public func updateUIView(_ uiView: MKMapView, context: Context) {}
}


