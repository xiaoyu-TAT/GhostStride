import SwiftUI
import MapKit

struct RoutePlannerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var stops: [GeoPoint] = []
    @State private var picker = false
    @State private var editingIndex: Int?
    @State private var alternative = false
    @State private var loading = false
    @State private var error: String?
    @State private var routeTask: Task<Void, Never>?
    var body: some View {
        List {
            Section("按顺序设置起点、途经点、终点") {
                ForEach(Array(stops.enumerated()), id: \.offset) { i, point in
                    Button { editingIndex = i; picker = true } label: {
                        HStack { Text(i == 0 ? "起点" : (i == stops.count-1 ? "终点" : "途经点 \(i)")); Spacer(); Text(String(format: "%.5f, %.5f", point.latitude, point.longitude)).font(.caption).monospacedDigit() }
                    }
                }.onDelete { stops.remove(atOffsets: $0) }.onMove { stops.move(fromOffsets: $0, toOffset: $1) }
                Button("添加地点", systemImage: "plus") { editingIndex = nil; picker = true }.disabled(stops.count >= 25)
            }.disabled(loading)
            Section("本机位置") {
                Button("将本机位置设为起点", systemImage: "location.fill") {
                    guard let currentPoint = model.currentPoint else { return }
                    if stops.isEmpty {
                        stops = [currentPoint]
                    } else {
                        stops[0] = currentPoint
                    }
                }
                .disabled(loading || model.currentPoint == nil)
                Text(model.useMock
                     ? "当前本机位置来自应用内虚拟定位，仅影响 GhostStride。"
                     : "当前本机位置来自 Core Location。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("路线选项") {
                Toggle("优先选择较长备选步行路线", isOn: $alternative)
                Text("多段路线逐段规划；仅有一条路线时使用该路线。地图服务需要网络，区域可用性由 Apple 决定。").font(.caption).foregroundStyle(.secondary)
                Text("手动连线距离：\(distanceText(RouteGeometry(stops).distance))")
                Button("获取步行路线") { plan() }.disabled(stops.count < 2 || loading)
                Button("使用手动轨迹") { model.setRoute(stops); dismiss() }.disabled(stops.isEmpty || loading)
                Text("手动轨迹直接连接各点，可能穿过建筑或水域。").font(.caption).foregroundStyle(.secondary)
                if loading { ProgressView("正在规划…") }
                if let error { Text(error).foregroundStyle(.red) }
            }
            if model.engine.state == .running || model.engine.state == .paused { Text("应用新路线会结束当前播放；请先保存需要的模拟记录。").foregroundStyle(.orange) }
        }
        .navigationTitle("路线规划").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭") { dismiss() } }; ToolbarItem(placement: .primaryAction) { EditButton().disabled(loading) } }
        .onAppear { if stops.isEmpty { stops = model.points.count <= 25 ? model.points : [model.points.first!, model.points.last!] } }
        .sheet(isPresented: $picker) { NavigationStack { LocationPickerView { point in if let i = editingIndex, stops.indices.contains(i) { stops[i] = point } else { stops.append(point) } } } }
        .onDisappear { routeTask?.cancel() }
    }
    private func plan() {
        loading = true; error = nil
        routeTask = Task {
            do { let points = try await MapServices.walking(stops: stops, alternative: alternative); try Task.checkCancellation(); model.setRoute(points); loading = false; dismiss() }
            catch { if !Task.isCancelled { self.error = "步行路线不可用：\(error.localizedDescription) 可选择“使用手动轨迹”。"; loading = false } }
        }
    }
}
