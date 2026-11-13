import XCTest
import SwiftData
@testable import GhostStride

final class PersistenceTests: XCTestCase {
    @MainActor func testSaveAndRead() throws {
        let schema = Schema([SavedRoute.self, FavoritePlace.self, SimulationRecord.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let points = [GeoPoint(latitude: 0, longitude: 0), GeoPoint(latitude: 0, longitude: 0.01)]
        context.insert(try SavedRoute(name: "测试路线", points: points, kmh: 12, loops: true))
        context.insert(FavoritePlace(name: "起点", point: points[0]))
        context.insert(SimulationRecord(routeName: "测试路线", meters: 100, seconds: 30)); try context.save()
        let reader = ModelContext(container)
        let routes = try reader.fetch(FetchDescriptor<SavedRoute>())
        XCTAssertEqual(routes.count, 1); XCTAssertEqual(try routes[0].points(), points); XCTAssertEqual(routes[0].kmh, 12); XCTAssertTrue(routes[0].loops)
        XCTAssertEqual(try reader.fetch(FetchDescriptor<FavoritePlace>()).count, 1)
        XCTAssertTrue(try XCTUnwrap(reader.fetch(FetchDescriptor<SimulationRecord>()).first).isSimulation)
        reader.delete(routes[0]); try reader.save(); XCTAssertTrue(try reader.fetch(FetchDescriptor<SavedRoute>()).isEmpty)
    }
}
