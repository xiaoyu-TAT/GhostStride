import SwiftUI
import MapKit
import SwiftData

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var phase
    var body: some View {
        @Bindable var model = model
        TabView {
            NavigationStack { MapHomeView() }.tabItem { Label("地图", systemImage: "map") }
            NavigationStack { RouteLibraryView() }.tabItem { Label("路线库", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }
            NavigationStack { SettingsView() }.tabItem { Label("设置", systemImage: "gearshape") }
        }
        .tint(.indigo)
        .onChange(of: phase) { _, value in if value != .active { model.pause(); model.real.stop() } else if !model.useMock { model.real.start() } }
        .alert("操作未完成", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) { Button("好") { model.error = nil } } message: { Text(model.error ?? "") }
    }
}
struct MapHomeView: View {
    @Environment(AppModel.self) private var model
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(center: GeoPoint.beijing.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)))
    @State private var picker = false
    @State private var planner = false
    @State private var controls = false
    @AppStorage("satellite") private var satellite = false
    var body: some View {
        @Bindable var model = model
        MapReader { proxy in
            Map(position: $camera) {
                if model.points.count > 1 { MapPolyline(coordinates: model.points.map(\.coordinate)).stroke(.gray.opacity(0.5), lineWidth: 6) }
                let done = model.geometry.completed(at: model.engine.lapDistance)
                if done.count > 1 { MapPolyline(coordinates: done.map(\.coordinate)).stroke(.indigo, lineWidth: 6) }
                if let p = model.selected { Marker("选点", coordinate: p.coordinate).tint(.orange) }
                if let sample = model.sample {
                    Annotation(model.useMock ? "模拟位置" : "Core Location", coordinate: sample.point.coordinate) {
                        Image(systemName: model.useMock ? "figure.run.circle.fill" : "location.circle.fill")
                            .font(.largeTitle).foregroundStyle(model.useMock ? .indigo : .blue).background(.background, in: Circle())
                            .accessibilityLabel(model.sourceName)
                    }
                }
            }
            .mapStyle(satellite ? .imagery : .standard)
            .animation(.linear(duration: 0.1), value: model.sample?.point)
            .onTapGesture { location in if let c = proxy.convert(location, from: .local) { model.select(GeoPoint(c)) } }
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    Button { picker = true } label: { Label("搜索地点或输入经纬度", systemImage: "magnifyingglass").frame(maxWidth: .infinity).padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) }
                    HStack {
                        Text(model.sourceName).font(.caption.bold()).padding(8).background(.regularMaterial, in: Capsule())
                        Spacer()
                        Button { model.useMock = false; model.switchSource(); if let p = model.real.sample?.point { focus(p) } } label: { Image(systemName: "location.fill").padding(12).background(.regularMaterial, in: Circle()) }.accessibilityLabel("获取真实位置")
                    }
                    if let message = model.real.message, !model.useMock { Text(message).font(.caption).padding(8).background(.regularMaterial) }
                }.padding()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                HStack { Text(model.routeName).font(.headline); Spacer(); Text(distanceText(model.geometry.distance)).monospacedDigit() }
                if let p = model.selected { Text(String(format: "选点 %.6f, %.6f", p.latitude, p.longitude)).font(.caption).foregroundStyle(.secondary) }
                HStack {
                    Button("追加选点", systemImage: "plus") { if let p = model.selected { model.setRoute(model.points + [p]) } }.disabled(model.selected == nil || model.engine.state == .running || model.engine.state == .paused)
                    Spacer()
                    Button("规划", systemImage: "point.topleft.down.to.point.bottomright.curvepath") { planner = true }
                    Button("播放", systemImage: "play.fill") { controls = true }.buttonStyle(.borderedProminent).disabled(model.points.isEmpty)
                }
                Text("应用内模拟不会修改其他 App 的定位").font(.caption2).foregroundStyle(.secondary)
            }.padding().background(.regularMaterial)
        }
        .navigationTitle("GhostStride").navigationBarTitleDisplayMode(.inline)
        .toolbar { NavigationLink { DeveloperToolsView() } label: { Image(systemName: "wrench.and.screwdriver") } }
        .sheet(isPresented: $picker) { NavigationStack { LocationPickerView { p in model.select(p); focus(p) } } }
        .sheet(isPresented: $planner) { NavigationStack { RoutePlannerView() } }
        .sheet(isPresented: $controls) { NavigationStack { SimulationControlView() } }
        .onChange(of: model.real.sample?.timestamp) { _, _ in if !model.useMock, let p = model.real.sample?.point { focus(p) } }
        .onChange(of: model.points) { _, points in
            guard !points.isEmpty else { return }
            let rect = points.reduce(MKMapRect.null) { $0.union(MKMapRect(origin: MKMapPoint($1.coordinate), size: MKMapSize(width: 1, height: 1))) }
            camera = .rect(rect.insetBy(dx: -max(500,rect.size.width*0.2), dy: -max(500,rect.size.height*0.2)))
        }
    }
    private func focus(_ p: GeoPoint) { camera = .region(MKCoordinateRegion(center: p.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012))) }
}
func distanceText(_ meters: Double) -> String {
    if UserDefaults.standard.bool(forKey: "imperial") { return String(format: "%.2f mi", meters/1609.344) }
    return String(format: "%.2f km", meters/1000)
}
func timeText(_ seconds: Double) -> String { let s = Int(max(0, min(seconds, 35999999))); return String(format: "%02d:%02d:%02d", s/3600, (s/60)%60, s%60) }
