import SwiftUI
import SwiftData

struct SimulationControlView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        @Bindable var model = model
        Form {
            Section { WorkoutDashboardView() }
            Section("运动参数") {
                HStack { ForEach(MotionPreset.allCases) { preset in Button(preset.rawValue) { model.kmh = preset.kmh }.buttonStyle(.bordered) } }
                HStack { Text("速度 km/h"); TextField("8", value: $model.kmh, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                Slider(value: $model.kmh, in: 1...40, step: 0.1)
                HStack { Text("配速 min/km"); TextField("7.5", value: Binding(get: { MotionUnits.pace(kmh: model.kmh) }, set: { model.kmh = MotionUnits.speed(pace: $0) }), format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                Picker("预览倍率", selection: $model.previewRate) { Text("1×").tag(1.0); Text("2×").tag(2.0); Text("5×").tag(5.0) }.pickerStyle(.segmented)
                Toggle("循环播放", isOn: $model.loops)
            }.disabled(model.engine.state == .running || model.engine.state == .paused)
            Section {
                HStack {
                    switch model.engine.state {
                    case .running: Button("暂停", systemImage: "pause.fill") { model.pause() }
                    case .paused: Button("继续", systemImage: "play.fill") { model.resume() }
                    default: Button("开始模拟", systemImage: "play.fill") { model.useMock = true; model.switchSource(); model.start() }.disabled(model.points.isEmpty || !model.kmh.isFinite || model.kmh <= 0 || model.kmh > 200)
                    }
                    Spacer()
                    Button("停止", systemImage: "stop.fill") { model.stop(); model.saveHistory(context: context) }.disabled(model.engine.state != .running && model.engine.state != .paused)
                    Button("重置") { model.reset() }.disabled(model.engine.state == .running)
                }
                Button(model.sessionSaved ? "模拟记录已保存" : "保存本次模拟记录") { model.saveHistory(context: context) }.disabled(model.sessionSaved || model.engine.traveled == 0 || model.engine.state == .running || model.engine.state == .paused)
                GPXExportButton()
            }
            Section { Text("所有运动指标均为模拟值，不写入健康数据。用时为模拟时间；2×/5×会加快预览。后台自动暂停，返回后手动继续。GPX 使用设定速度生成时间，不受预览倍率影响。").font(.caption).foregroundStyle(.secondary) }
        }
        .navigationTitle("模拟运动").navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("完成") { dismiss() } }
        .onChange(of: model.engine.state) { _, state in if state == .finished { model.saveHistory(context: context) } }
    }
}
struct WorkoutDashboardView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Label("模拟记录", systemImage: "figure.run").foregroundStyle(.indigo); Spacer(); Text(model.engine.state.rawValue) }
            Text(distanceText(model.engine.traveled)).font(.system(size: 42, weight: .semibold, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
            ProgressView(value: model.geometry.distance > 0 ? min(1, model.engine.lapDistance/model.geometry.distance) : 0)
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                GridRow { metric("模拟用时", timeText(model.engine.elapsed)); metric("设定配速", String(format: "%.2f min/km", MotionUnits.pace(kmh: model.kmh))) }
                GridRow { metric("设定速度", String(format: "%.1f km/h", model.kmh)); metric("本圈剩余", distanceText(model.engine.remaining)) }
                GridRow { metric("剩余模拟时间", timeText(model.engine.remainingSeconds)); metric("预览倍率", String(format: "%.0f×", model.previewRate)) }
            }
            if let p = model.engine.position { Text(String(format: "模拟坐标 %.6f, %.6f", p.latitude, p.longitude)).font(.caption).monospacedDigit() }
        }.padding(.vertical, 8)
    }
    private func metric(_ title: String, _ value: String) -> some View { VStack(alignment: .leading) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.headline).monospacedDigit() } }
}
