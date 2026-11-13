import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension UTType { static let ghostStrideGPX = UTType(exportedAs: "com.example.ghoststride.gpx", conformingTo: .xml) }

struct GPXDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.ghostStrideGPX, .xml, .data] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { guard let data = configuration.file.regularFileContents else { throw GPXError.empty }; self.data = data }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
struct GPXExportButton: View {
    @Environment(AppModel.self) private var model
    @State private var document = GPXDocument(data: Data())
    @State private var exporting = false
    var body: some View {
        Menu {
            ForEach(GPXFormat.allCases) { format in Button(format.rawValue) {
                do { document = GPXDocument(data: try GPXService.export(points: model.points, name: model.routeName, kmh: model.kmh, format: format)); exporting = true } catch { model.error = error.localizedDescription }
            } }
        } label: { Label("导出 GPX", systemImage: "square.and.arrow.up") }
        .disabled(model.points.isEmpty)
        .fileExporter(isPresented: $exporting, document: document, contentType: .ghostStrideGPX, defaultFilename: "GhostStride") { result in if case .failure(let error) = result { model.error = error.localizedDescription } }
    }
}
struct RouteLibraryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedRoute.createdAt, order: .reverse) private var routes: [SavedRoute]
    @Query(sort: \SimulationRecord.createdAt, order: .reverse) private var history: [SimulationRecord]
    @State private var importing = false
    @State private var renaming: SavedRoute?
    @State private var newName = ""
    @State private var saved = false
    var body: some View {
        @Bindable var model = model
        List {
            Section("当前路线") {
                TextField("路线名称", text: $model.routeName)
                Text("\(model.points.count) 个点 · \(distanceText(model.geometry.distance))")
                Button("保存当前路线", systemImage: "square.and.arrow.down") { model.saveRoute(context: context); saved = model.error == nil }.disabled(model.points.isEmpty)
                GPXExportButton()
                Button("导入 GPX", systemImage: "doc.badge.plus") { importing = true }
                Button("载入约 2 公里示例") { loadSample("TwoKilometers") }
                Button("载入静态位置示例") { loadSample("StaticLocation") }
            }
            Section("已保存路线") {
                if routes.isEmpty { ContentUnavailableView("暂无路线", systemImage: "map", description: Text("在地图上选点规划，或导入 GPX。")) }
                ForEach(routes) { route in
                    Button { do { model.setRoute(try route.points(), name: route.name); model.kmh = route.kmh; model.loops = route.loops; model.previewRate = route.previewRate } catch { model.error = error.localizedDescription } } label: {
                        VStack(alignment: .leading) { Text(route.name); Text("\(distanceText(route.totalDistance)) · \(route.createdAt.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(.secondary) }
                    }
                    .swipeActions { Button("删除", role: .destructive) { context.delete(route); persist() }; Button("重命名") { renaming = route; newName = route.name }.tint(.blue) }
                }
            }
            Section("模拟运动历史 · 非真实运动成绩") {
                if history.isEmpty { Text("暂无模拟记录").foregroundStyle(.secondary) }
                ForEach(history) { record in
                    VStack(alignment: .leading) { Text("模拟 · \(record.routeName)"); Text("\(distanceText(record.meters)) · \(timeText(record.simulatedSeconds))").monospacedDigit(); Text(record.createdAt.formatted()).font(.caption).foregroundStyle(.secondary) }
                        .swipeActions { Button("删除", role: .destructive) { context.delete(record); persist() } }
                }
            }
        }
        .navigationTitle("路线库")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.xml, .data], allowsMultipleSelection: false) { result in
            do { if let url = try result.get().first { let points = try GPXService.read(url: url); model.setRoute(points, name: url.deletingPathExtension().lastPathComponent) } } catch { model.error = error.localizedDescription }
        }
        .alert("路线已保存", isPresented: $saved) { Button("好", role: .cancel) {} }
        .alert("重命名路线", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("名称", text: $newName)
            Button("保存") { if !newName.trimmingCharacters(in: .whitespaces).isEmpty { renaming?.name = newName; persist() }; renaming = nil }
            Button("取消", role: .cancel) { renaming = nil }
        }
    }
    private func persist() { do { try context.save() } catch { context.rollback(); model.error = error.localizedDescription } }
    private func loadSample(_ name: String) { do { guard let url = Bundle.main.url(forResource: name, withExtension: "gpx") else { throw CocoaError(.fileNoSuchFile) }; model.setRoute(try GPXService.read(url: url), name: name == "TwoKilometers" ? "约 2 公里示例" : "静态位置") } catch { model.error = error.localizedDescription } }
}
