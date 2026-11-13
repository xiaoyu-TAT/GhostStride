import XCTest
@testable import GhostStride

final class CoreTests: XCTestCase {
    let a = GeoPoint(latitude: 0, longitude: 0)
    let b = GeoPoint(latitude: 0, longitude: 0.001)
    let c = GeoPoint(latitude: 0, longitude: 0.01)
    func testCoordinateValidation() {
        XCTAssertTrue(GeoPoint(latitude: -90, longitude: 180).isValid)
        XCTAssertFalse(GeoPoint(latitude: 91, longitude: 0).isValid)
        XCTAssertFalse(GeoPoint(latitude: 0, longitude: .nan).isValid)
        XCTAssertFalse(GeoPoint(latitude: .infinity, longitude: 0).isValid)
    }
    func testHaversine() { XCTAssertEqual(a.distance(to: GeoPoint(latitude: 0, longitude: 1)), 111194.9266, accuracy: 0.01); XCTAssertEqual(a.distance(to: a), 0) }
    func testCumulativeDistanceAndUnevenInterpolation() {
        let route = RouteGeometry([a,b,b,c])
        XCTAssertEqual(route.points.count, 3)
        XCTAssertEqual(route.distance, a.distance(to: c), accuracy: 0.001)
        XCTAssertEqual(route.position(at: route.distance/2)!.longitude, 0.005, accuracy: 1e-8)
        XCTAssertEqual(route.position(at: -100), a)
        XCTAssertEqual(route.position(at: .greatestFiniteMagnitude), c)
    }
    func testDateLineInterpolation() { let p = GeoPoint(latitude: 0, longitude: 179).interpolated(to: GeoPoint(latitude: 0, longitude: -179), fraction: 0.5); XCTAssertEqual(abs(p.longitude), 180, accuracy: 1e-6) }
    func testSpeedPaceConversion() { XCTAssertEqual(MotionUnits.pace(kmh: 12), 5); XCTAssertEqual(MotionUnits.speed(pace: 5), 12); XCTAssertEqual(MotionUnits.pace(kmh: 0), 0) }
    func testPauseResumeAccumulation() {
        var e = SimulationEngine(); e.load([a,c]); e.kmh = 3.6; e.start(now: 100); e.pause(now: 110)
        e.advance(now: 200); XCTAssertEqual(e.elapsed, 10); XCTAssertEqual(e.traveled, 10)
        e.resume(now: 300); e.advance(now: 305); XCTAssertEqual(e.elapsed, 15); XCTAssertEqual(e.traveled, 15)
    }
    func testCompletionClampsDistanceAndTime() {
        var e = SimulationEngine(); e.load([a,b]); e.kmh = 3.6; e.start(now: 0); e.advance(now: 1000)
        XCTAssertEqual(e.state, .finished); XCTAssertEqual(e.traveled, e.geometry.distance); XCTAssertEqual(e.elapsed, e.geometry.distance, accuracy: 1e-8)
        XCTAssertEqual(e.position, b); e.advance(now: 2000); XCTAssertEqual(e.remaining, 0)
    }
    func testEmptyAndSinglePoint() {
        var e = SimulationEngine(); e.start(now: 0); XCTAssertEqual(e.state, .idle); XCTAssertNil(e.position)
        e.load([a]); e.start(now: 0); XCTAssertEqual(e.state, .finished); XCTAssertEqual(e.position, a); XCTAssertEqual(e.traveled, 0)
    }
    func testLoopPreviewAndReset() {
        var e = SimulationEngine(); e.load([a,b]); e.kmh = 3.6; e.loops = true; e.previewRate = 5; e.start(now: 0); e.advance(now: 100)
        XCTAssertEqual(e.traveled, 500); XCTAssertEqual(e.elapsed, 500); XCTAssertLessThan(e.lapDistance, e.geometry.distance)
        e.stop(now: 100); e.reset(); XCTAssertEqual(e.elapsed, 0); XCTAssertEqual(e.state, .idle)
    }
    func testInvalidClockAndSpeed() {
        var e = SimulationEngine(); e.load([a,b]); e.start(now: 20); e.advance(now: 10); e.advance(now: .nan); XCTAssertEqual(e.traveled, 0)
        e.kmh = .nan; e.advance(now: 30); XCTAssertEqual(e.traveled, 0)
    }
    func testRealisticMotionAcceleratesAndReportsBoundedOffset() {
        var e = SimulationEngine(); e.load([a,c]); e.kmh = 3.6; e.realisticMotion = true; e.start(now: 0)
        e.advance(now: 1)
        XCTAssertGreaterThan(e.currentSpeed, 0)
        XCTAssertLessThan(e.currentSpeed, 1)
        XCTAssertNotNil(e.simulatedPosition)
        XCTAssertLessThanOrEqual(e.position!.distance(to: e.simulatedPosition!), 2)
    }
    func testSharpTurnReducesTargetMovementSpeed() {
        let turn = GeoPoint(latitude: 0, longitude: 0.001)
        var e = SimulationEngine(); e.load([a, turn, GeoPoint(latitude: 0.001, longitude: 0.001)])
        e.kmh = 10; e.realisticMotion = true; e.start(now: 0); e.advance(now: 1)
        XCTAssertLessThan(e.currentSpeed, 10 / 3.6)
    }
}
