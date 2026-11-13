import SwiftUI
import Observation
import SwiftData

@MainActor @Observable final class AppModel {
    var points: [GeoPoint] = []
    var routeName = "我的路线"
    var selected: GeoPoint?
    var useMock = true
    var error: String?
    var engine = SimulationEngine()
    let mock = MockLocationProvider()
    let real = RealLocationProvider()
    var kmh: Double = UserDefaults.standard.object(forKey: "defaultSpeed") as? Double ?? 8
    var previewRate = 1.0
    var loops = false
    var sessionSaved = false
    @ObservationIgnored private var ticker: Task<Void, Never>?
    deinit { ticker?.cancel() }
    var sample: LocationSample? { useMock ? mock.sample : real.sample }
    var sourceName: String { useMock ? mock.sourceName : real.sourceName }
    var currentPoint: GeoPoint? { sample?.point }
    var geometry: RouteGeometry { engine.geometry }
    func switchSource() { if useMock { real.stop(); mock.start() } else { real.start(); mock.stop() } }
    func select(_ p: GeoPoint) { selected = p; if useMock && engine.state != .running { mock.update(p, speed: 0) } }
    func setRoute(_ new: [GeoPoint], name: String? = nil) {
        cancelTicker(); points = RouteGeometry(new).points; engine.load(points); sessionSaved = false
        if let name { routeName = name }; if let p = points.first { select(p) }
    }
    private func configure() { engine.kmh = kmh; engine.previewRate = previewRate; engine.loops = loops }
    func start() { cancelTicker(); configure(); engine.start(now: ProcessInfo.processInfo.systemUptime); sessionSaved = false; publish(); runTicker() }
    func pause() { engine.pause(now: ProcessInfo.processInfo.systemUptime); cancelTicker(); publish() }
    func resume() { configure(); engine.resume(now: ProcessInfo.processInfo.systemUptime); runTicker() }
    func stop() { engine.stop(now: ProcessInfo.processInfo.systemUptime); cancelTicker(); publish() }
    func reset() { cancelTicker(); engine.reset(); sessionSaved = false; publish() }
    private func publish() { if let p = engine.position { mock.update(p, speed: engine.state == .running ? engine.kmh/3.6 : 0) } }
    private func runTicker() {
        guard ticker == nil, engine.state == .running else { return }
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { break }
                guard let self else { break }
                self.configure(); self.engine.advance(now: ProcessInfo.processInfo.systemUptime); self.publish()
                if self.engine.state != .running { self.ticker = nil; break }
            }
        }
    }
    private func cancelTicker() { ticker?.cancel(); ticker = nil }
    func saveRoute(context: ModelContext) {
        do { guard !points.isEmpty else { throw GPXError.empty }; context.insert(try SavedRoute(name: routeName, points: points, kmh: kmh, loops: loops, previewRate: previewRate)); try context.save() }
        catch { context.rollback(); self.error = error.localizedDescription }
    }
    func saveHistory(context: ModelContext) {
        guard !sessionSaved, engine.traveled > 0 else { return }
        context.insert(SimulationRecord(routeName: routeName, meters: engine.traveled, seconds: engine.elapsed))
        do { try context.save(); sessionSaved = true } catch { context.rollback(); self.error = error.localizedDescription }
    }
}

@main struct GhostStrideApp: App {
    @State private var model = AppModel()
    private let storage: Result<ModelContainer, Error> = Result { try ModelContainer(for: SavedRoute.self, FavoritePlace.self, SimulationRecord.self) }
    var body: some Scene {
        WindowGroup {
            switch storage {
            case .success(let container): RootView().environment(model).modelContainer(container)
            case .failure(let error): ContentUnavailableView("无法打开本地资料库", systemImage: "externaldrive.badge.exclamationmark", description: Text(error.localizedDescription + "\n请检查设备存储空间并重新启动。应用未删除原有数据。"))
            }
        }
    }
}
