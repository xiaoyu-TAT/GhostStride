@preconcurrency import MapKit

extension GeoPoint {
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    init(_ c: CLLocationCoordinate2D) { latitude = c.latitude; longitude = c.longitude }
}
@MainActor enum MapServices {
    static func search(_ query: String) async throws -> [MKMapItem] {
        let request = MKLocalSearch.Request(); request.naturalLanguageQuery = query
        return try await MKLocalSearch(request: request).start().mapItems
    }
    static func walking(stops: [GeoPoint], alternative: Bool) async throws -> [GeoPoint] {
        guard stops.count >= 2 else { return stops }
        var result: [GeoPoint] = []
        for i in 1..<stops.count {
            try Task.checkCancellation()
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: stops[i-1].coordinate))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: stops[i].coordinate))
            request.transportType = .walking; request.requestsAlternateRoutes = true
            let directions = MKDirections(request: request)
            let response = try await withTaskCancellationHandler { try await directions.calculate() } onCancel: { directions.cancel() }
            let routes = response.routes.sorted { $0.distance < $1.distance }
            guard let route = alternative ? routes.last : routes.first else { throw CocoaError(.fileReadUnknown) }
            var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: route.polyline.pointCount)
            route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: coords.count))
            for c in coords { let p = GeoPoint(c); if result.last.map({ $0.distance(to: p) > 0.05 }) ?? true { result.append(p) } }
        }
        return result
    }
}
