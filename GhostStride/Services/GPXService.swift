import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

enum GPXError: LocalizedError {
    case empty, tooLarge, invalidXML, invalidCoordinate, invalidSpeed, tooManyPoints
    var errorDescription: String? { switch self {
    case .empty: "文件没有可用轨迹点。"
    case .tooLarge: "GPX 文件不能超过 5 MB。"
    case .invalidXML: "GPX XML 格式无效，或包含不支持的实体声明。"
    case .invalidCoordinate: "轨迹包含非法经纬度。"
    case .invalidSpeed: "速度必须是大于零的有限数值。"
    case .tooManyPoints: "轨迹点数不能超过 20000。"
    } }
}
enum GPXFormat: String, CaseIterable, Identifiable { case waypoints = "Xcode 定位（wpt）", track = "标准轨迹（trk）"; var id: String { rawValue } }
enum GPXService {
    static let maxBytes = 5 * 1024 * 1024
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&apos;")
    }
    static func export(points: [GeoPoint], name: String, kmh: Double, format: GPXFormat = .waypoints, start: Date = Date()) throws -> Data {
        guard !points.isEmpty else { throw GPXError.empty }
        guard points.count <= 20_000 else { throw GPXError.tooManyPoints }
        guard points.allSatisfy(\.isValid) else { throw GPXError.invalidCoordinate }
        guard kmh.isFinite, kmh > 0 else { throw GPXError.invalidSpeed }
        let geometry = RouteGeometry(points)
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<gpx version=\"1.1\" creator=\"GhostStride\" xmlns=\"http://www.topografix.com/GPX/1/1\">\n<metadata><name>\(escape(name))</name></metadata>\n"
        if format == .track { xml += "<trk><name>\(escape(name))</name><trkseg>\n" }
        var previous = -0.001
        for (i,p) in geometry.points.enumerated() {
            // Millisecond minimum guarantees serialized timestamps strictly increase, even for tiny segments.
            let seconds = max(previous+0.001, geometry.cumulative[i]/(kmh/3.6)); previous = seconds
            let tag = format == .waypoints ? "wpt" : "trkpt"
            let lat = String(format: "%.8f", locale: Locale(identifier: "en_US_POSIX"), p.latitude)
            let lon = String(format: "%.8f", locale: Locale(identifier: "en_US_POSIX"), p.longitude)
            xml += "<\(tag) lat=\"\(lat)\" lon=\"\(lon)\"><time>\(formatter.string(from: start.addingTimeInterval(seconds)))</time></\(tag)>\n"
        }
        if format == .track { xml += "</trkseg></trk>\n" }; xml += "</gpx>\n"
        let data = Data(xml.utf8); guard data.count <= maxBytes else { throw GPXError.tooLarge }; return data
    }
    static func parse(_ data: Data) throws -> [GeoPoint] {
        guard !data.isEmpty else { throw GPXError.empty }
        guard data.count <= maxBytes else { throw GPXError.tooLarge }
        // Reject DTD/entity input in both UTF-8 and UTF-16 before XMLParser handles it.
        let scan = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "\0", with: "").uppercased()
        guard !scan.contains("<!DOCTYPE"), !scan.contains("<!ENTITY") else { throw GPXError.invalidXML }
        let delegate = GPXParser(); let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true; parser.shouldResolveExternalEntities = false; parser.delegate = delegate
        let success = parser.parse()
        if let error = delegate.error { throw error }
        guard success, delegate.isGPX else { throw GPXError.invalidXML }
        let result = !delegate.track.isEmpty ? delegate.track : (!delegate.route.isEmpty ? delegate.route : delegate.waypoints)
        guard !result.isEmpty else { throw GPXError.empty }; return RouteGeometry(result).points
    }
    static func read(url: URL) throws -> [GeoPoint] {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let data = try handle.read(upToCount: maxBytes+1) ?? Data()
        return try parse(data)
    }
}
private final class GPXParser: NSObject, XMLParserDelegate {
    var waypoints: [GeoPoint] = [], track: [GeoPoint] = [], route: [GeoPoint] = []
    var error: GPXError?; var isGPX = false; var depth = 0
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String:String]) {
        depth += 1
        if depth == 1 { isGPX = name == "gpx" }
        guard ["wpt","trkpt","rtept"].contains(name) else { return }
        guard let lat = attributes["lat"].flatMap(Double.init), let lon = attributes["lon"].flatMap(Double.init), GeoPoint(latitude: lat, longitude: lon).isValid else { error = .invalidCoordinate; parser.abortParsing(); return }
        let p = GeoPoint(latitude: lat, longitude: lon)
        switch name { case "trkpt": track.append(p); case "rtept": route.append(p); default: waypoints.append(p) }
        if track.count + route.count + waypoints.count > 20_000 { error = .tooManyPoints; parser.abortParsing() }
    }
    func parser(_ parser: XMLParser, didEndElement: String, namespaceURI: String?, qualifiedName: String?) { depth -= 1 }
}
