import Foundation
import CoreLocation
import Observation

struct LocationSample {
    var point: GeoPoint; var speed: Double?; var timestamp: Date
}
@MainActor protocol LocationProviding: AnyObject {
    var sample: LocationSample? { get }
    var sourceName: String { get }
    func start()
    func stop()
}
@MainActor @Observable final class MockLocationProvider: LocationProviding {
    private(set) var sample: LocationSample?
    let sourceName = "模拟定位 · 仅本应用"
    private(set) var isActive = false
    func start() { isActive = true }
    func stop() { isActive = false; if let s = sample { sample = LocationSample(point: s.point, speed: 0, timestamp: Date()) } }
    func update(_ point: GeoPoint, speed: Double) { sample = LocationSample(point: point, speed: speed, timestamp: Date()) }
}
@MainActor @Observable final class RealLocationProvider: NSObject, LocationProviding, @preconcurrency CLLocationManagerDelegate {
    private(set) var sample: LocationSample?
    private(set) var message: String?
    private(set) var systemSimulated = false
    var sourceName: String { systemSimulated ? "Core Location · 系统报告为模拟" : "真实定位 · Core Location" }
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var active = false
    override init() { super.init(); manager.delegate = self; manager.desiredAccuracy = kCLLocationAccuracyBest }
    func start() { active = true; manager.requestWhenInUseAuthorization(); updateAuthorization() }
    func stop() { active = false; manager.stopUpdatingLocation() }
    private func updateAuthorization() {
        guard active else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: message = nil; manager.startUpdatingLocation()
        case .denied, .restricted: message = "定位权限不可用，仍可手动选点和模拟。"
        default: break
        }
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { updateAuthorization() }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last, last.horizontalAccuracy >= 0 else { return }
        sample = LocationSample(point: GeoPoint(latitude: last.coordinate.latitude, longitude: last.coordinate.longitude), speed: last.speed >= 0 ? last.speed : nil, timestamp: last.timestamp)
        systemSimulated = last.sourceInformation?.isSimulatedBySoftware ?? false
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { message = error.localizedDescription }
}
