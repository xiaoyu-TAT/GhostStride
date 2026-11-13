import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("imperial") private var imperial = false
    @AppStorage("satellite") private var satellite = false
    @AppStorage("defaultSpeed") private var defaultSpeed = 8.0
    var body: some View {
        @Bindable var model = model
        Form {
            Section("位置数据来源") {
                Toggle("使用应用内模拟定位", isOn: $model.useMock).onChange(of: model.useMock) { _, _ in model.switchSource() }
                Text(model.sourceName).foregroundStyle(.secondary)
                Text("关闭后按需请求使用期间的定位权限。拒绝授权不影响手动选点、规划或模拟播放。").font(.caption)
            }
            Section("显示") { Toggle("距离使用英里", isOn: $imperial); Toggle("卫星地图", isOn: $satellite); Text("速度与配速输入固定使用 km/h 和 min/km。主题跟随系统。").font(.caption) }
            Section("默认运动参数") { Slider(value: $defaultSpeed, in: 1...40, step: 0.5); Text(String(format: "新启动默认速度 %.1f km/h", defaultSpeed)); Button("应用到当前模拟参数") { model.kmh = defaultSpeed }.disabled(model.engine.state == .running || model.engine.state == .paused) }
            Section("开发调试") { NavigationLink("定位诊断与 GPX 说明") { DeveloperToolsView() } }
            Section("隐私") { Text("无账户、无后端、无遥测。路线和模拟记录保存在设备本地。地点搜索、地图及步行规划由 Apple MapKit 提供，相关查询需发送给 Apple。不读取或写入 Apple Health 数据。").font(.footnote) }
        }.navigationTitle("设置")
    }
}
struct DeveloperToolsView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        Form {
            Section("定位诊断") {
                LabeledContent("数据来源", value: model.sourceName)
                LabeledContent("模拟状态", value: model.engine.state.rawValue)
                if let sample = model.sample {
                    LabeledContent("纬度", value: String(format: "%.8f", sample.point.latitude))
                    LabeledContent("经度", value: String(format: "%.8f", sample.point.longitude))
                    LabeledContent(model.useMock ? "模拟速度 m/s" : "Core Location 速度 m/s", value: sample.speed.map { String(format: "%.3f", $0) } ?? "未知")
                    LabeledContent("采样时间", value: sample.timestamp.formatted(date: .omitted, time: .standard))
                } else { Text("暂无位置数据") }
            }
            Section("Xcode 定位调试") {
                Text("导出“Xcode 定位（wpt）”后，将 GPX 传到 Mac 并加入 Xcode 工程。在真机调试会话中使用 Debug > Simulate Location 选择该文件。需要 Mac、Xcode、签名及活跃调试连接。")
                Text("应用的开始按钮只移动本应用的模拟坐标。Core Location 没有供普通 App 写入全系统 GPS 的公开 API。Xcode 对其他进程的影响取决于系统与调试环境，不保证任何第三方 App 的表现。")
                Text("GPX 时间由路线距离和设定速度计算，预览倍率不写入 GPX。Xcode 各版本对时间和速度的解释可能不同，需实际调试验证。trk 文件用于轨迹查看，不能直接当作 Xcode wpt 路线。")
                GPXExportButton()
                Text("完整教程见仓库 Docs/LocationSimulation.md。")
            }
        }.navigationTitle("开发者工具").textSelection(.enabled)
    }
}
