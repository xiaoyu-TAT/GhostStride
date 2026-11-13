import Foundation
import SwiftData

@Model final class SavedRoute {
    var id: UUID
    var name: String
    var pointsData: Data
    var totalDistance: Double
    var createdAt: Date
    var kmh: Double
    var loops: Bool
    var previewRate: Double = 1
    init(name: String, points: [GeoPoint], kmh: Double = 8, loops: Bool = false, previewRate: Double = 1) throws {
        id = UUID(); self.name = name; pointsData = try JSONEncoder().encode(points)
        totalDistance = RouteGeometry(points).distance; createdAt = Date(); self.kmh = kmh; self.loops = loops; self.previewRate = previewRate
    }
    func points() throws -> [GeoPoint] { try JSONDecoder().decode([GeoPoint].self, from: pointsData) }
}
@Model final class FavoritePlace {
    var id: UUID; var name: String; var latitude: Double; var longitude: Double
    init(name: String, point: GeoPoint) { id = UUID(); self.name = name; latitude = point.latitude; longitude = point.longitude }
    var point: GeoPoint { GeoPoint(latitude: latitude, longitude: longitude) }
}
@Model final class SimulationRecord {
    var id: UUID; var createdAt: Date; var routeName: String; var meters: Double; var simulatedSeconds: Double; var isSimulation: Bool
    init(routeName: String, meters: Double, seconds: Double) { id = UUID(); createdAt = Date(); self.routeName = routeName; self.meters = meters; simulatedSeconds = seconds; isSimulation = true }
}
