import XCTest
@testable import GhostStride

final class GPXTests: XCTestCase {
    let points = [GeoPoint(latitude: 39.9, longitude: 116.4), GeoPoint(latitude: 39.91, longitude: 116.41)]
    func testWaypointRoundTripAndEscaping() throws {
        let data = try GPXService.export(points: points, name: "A & <B> \"C\"", kmh: 8)
        let xml = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(xml.contains("version=\"1.1\"")); XCTAssertTrue(xml.contains("<wpt")); XCTAssertTrue(xml.contains("A &amp; &lt;B&gt; &quot;C&quot;"))
        XCTAssertEqual(try GPXService.parse(data), points)
    }
    func testTrackRoundTrip() throws { let data = try GPXService.export(points: points, name: "轨迹", kmh: 8, format: .track); XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("<trkpt")); XCTAssertEqual(try GPXService.parse(data), points) }
    func testTimestampsStrictlyIncreaseAndUseDistance() throws {
        let start = Date(timeIntervalSince1970: 0)
        let data = try GPXService.export(points: points, name: "test", kmh: 3.6, start: start)
        let xml = String(decoding: data, as: UTF8.self)
        let regex = try NSRegularExpression(pattern: "<time>(.*?)</time>")
        let matches = regex.matches(in: xml, range: NSRange(xml.startIndex..., in: xml))
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dates = matches.compactMap { Range($0.range(at: 1), in: xml).flatMap { f.date(from: String(xml[$0])) } }
        XCTAssertEqual(dates.count, 2); XCTAssertGreaterThan(dates[1], dates[0]); XCTAssertEqual(dates[1].timeIntervalSince(dates[0]), points[0].distance(to: points[1]), accuracy: 0.002)
    }
    func testTinySegmentsAndDuplicates() throws {
        let p = GeoPoint(latitude: 0, longitude: 0), q = GeoPoint(latitude: 0, longitude: 0.00000001)
        let data = try GPXService.export(points: [p,p,q], name: "tiny", kmh: 200, start: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("00:00:00.001Z")); XCTAssertEqual(try GPXService.parse(data).count, 2)
    }
    func testInvalidInputs() {
        for input in ["", "<gpx>", "<other/>", "<gpx><wpt lat='91' lon='0'/></gpx>", "<!DOCTYPE gpx [<!ENTITY x 'foo'>]><gpx/>", "<gpx/>"] { XCTAssertThrowsError(try GPXService.parse(Data(input.utf8))) }
        XCTAssertThrowsError(try GPXService.parse(Data(repeating: 32, count: GPXService.maxBytes+1)))
        XCTAssertThrowsError(try GPXService.export(points: [], name: "", kmh: 8))
        XCTAssertThrowsError(try GPXService.export(points: points, name: "", kmh: 0))
    }
    func testRouteImportAndTrackPriority() throws {
        let xml = "<gpx><wpt lat='1' lon='2'/><trk><trkseg><trkpt lat='3' lon='4'/></trkseg></trk></gpx>"
        XCTAssertEqual(try GPXService.parse(Data(xml.utf8)), [GeoPoint(latitude: 3, longitude: 4)])
        XCTAssertEqual(try GPXService.parse(Data("<gpx><rte><rtept lat='1' lon='2'/></rte></gpx>".utf8)).count, 1)
    }
}
