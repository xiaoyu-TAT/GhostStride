import SwiftUI
import MapKit
import SwiftData

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \FavoritePlace.name) private var favorites: [FavoritePlace]
    var onSelect: (GeoPoint) -> Void
    @State private var query = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var name = "收藏地点"
    @State private var point: GeoPoint?
    @State private var results: [MKMapItem] = []
    @State private var loading = false
    @State private var error: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var camera: MapCameraPosition = .region(MKCoordinateRegion(center: GeoPoint.beijing.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)))
    var body: some View {
        Form {
            Section("地图选点") {
                MapReader { proxy in
                    Map(position: $camera) { if let point { Marker("选点", coordinate: point.coordinate) } }
                        .frame(height: 220).onTapGesture { location in if let c = proxy.convert(location, from: .local) { choose(GeoPoint(c)) } }
                }
                Text("轻点地图选择位置").font(.caption)
            }
            Section("地点搜索") {
                HStack { TextField("名称或地址", text: $query).onSubmit(search); Button(action: search) { Image(systemName: "magnifyingglass") }.disabled(query.trimmingCharacters(in: .whitespaces).isEmpty) }
                if loading { ProgressView("搜索中") }
                ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                    Button { name = item.name ?? "收藏地点"; choose(GeoPoint(item.placemark.coordinate)) } label: { VStack(alignment: .leading) { Text(item.name ?? "地点"); Text(item.placemark.title ?? "").font(.caption).foregroundStyle(.secondary) } }
                }
            }
            Section("手动经纬度（十进制度）") {
                TextField("纬度 −90…90", text: $latitude).keyboardType(.numbersAndPunctuation)
                TextField("经度 −180…180", text: $longitude).keyboardType(.numbersAndPunctuation)
                Button("校验并选中") {
                    guard let lat = Double(latitude), let lon = Double(longitude), GeoPoint(latitude: lat, longitude: lon).isValid else { error = "请输入有效经纬度。"; return }
                    choose(GeoPoint(latitude: lat, longitude: lon))
                }
                TextField("收藏名称", text: $name)
                Button("收藏当前选点", systemImage: "star") {
                    guard let point else { return }; context.insert(FavoritePlace(name: name.isEmpty ? "收藏地点" : name, point: point))
                    do { try context.save() } catch { context.rollback(); self.error = error.localizedDescription }
                }.disabled(point == nil)
            }
            Section("收藏地点") {
                if favorites.isEmpty { Text("暂无收藏").foregroundStyle(.secondary) }
                ForEach(favorites) { favorite in Button(favorite.name) { choose(favorite.point) } }
                    .onDelete { indices in for i in indices { context.delete(favorites[i]) }; do { try context.save() } catch { context.rollback(); self.error = error.localizedDescription } }
            }
            if let error { Section { Text(error).foregroundStyle(.red) } }
        }
        .navigationTitle("选择地点").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("使用") { if let point { onSelect(point); dismiss() } }.disabled(point == nil) } }
        .onDisappear { searchTask?.cancel() }
    }
    private func choose(_ p: GeoPoint) { point = p; latitude = String(format: "%.8f", p.latitude); longitude = String(format: "%.8f", p.longitude); camera = .region(MKCoordinateRegion(center: p.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))); error = nil }
    private func search() {
        searchTask?.cancel(); loading = true; error = nil
        searchTask = Task { do { let found = try await MapServices.search(query); try Task.checkCancellation(); results = found; loading = false; if found.isEmpty { error = "未找到地点，请尝试其他关键词或手动选点。" } } catch { if !Task.isCancelled { self.error = error.localizedDescription; loading = false } } }
    }
}
