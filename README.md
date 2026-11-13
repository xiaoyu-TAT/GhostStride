# GhostStride

个人使用的 iOS 原生地图选点、步行路线规划、**应用内部模拟运动**与 GPX 调试文件工具。中文界面，无账户、后端、订阅或付费地图密钥；最低 iOS 17，面向竖屏 iPhone。

**能力边界：**应用只更新自己的模拟位置；“本机位置”在应用内表示当前启用的位置源。普通 iOS 应用不能通过 Core Location 写入全系统 GPS。Xcode 定位模拟另需 Mac、Xcode 和调试会话。本项目不含私有定位注入、越狱、检测绕过或 HealthKit 写入。

## 已实现

- 地图轻点选点、经纬度输入校验、MKLocalSearch 搜索、SwiftData 收藏。
- 显式切换 Core Location 与 MockLocationProvider；拒绝定位权限仍可手动使用。
- 启用应用内模拟定位时，虚拟坐标可作为本机位置用于本应用的选点和路线起点。
- 起点/终点/多个途经点、重排/删除/替换地点；逐段步行规划及备选路线；失败后可手动直线连接。
- 距离累计、球面插值、10 Hz 模拟更新、平滑标记、已走/剩余轨迹、暂停/继续/停止/重置、循环及 1×/2×/5×预览。
- 步行/慢跑/快跑/骑行预设、自定义速度与配速、模拟仪表盘。
- 本地路线保存/读取/重命名/删除，显式标记为模拟的运动历史。
- GPX 1.1 `wpt` / `trk` 导出、文件选择器导入 `wpt` / `trkpt` / `rtept`，5 MB / 20000 点限制、非法数据提示。
- 距离单位、卫星地图、默认速度、定位诊断、系统浅色/深色主题。

## 验证状态

本版在 Linux 环境生成。当前环境没有 Swift、Xcode、Apple SDK 或 iOS 模拟器，**尚未完成 Swift 类型检查、xcodebuild、XCTest 执行或真机安装验证**。不能将静态检查通过视作已验证可编译。

已执行：15 个 Swift 文件的 Tree-sitter 语法解析、OpenStep 工程解析及引用完整性检查、Info.plist / Scheme / 资源检查、示例 GPX 坐标与时间检查、生成器重复性检查。XCTest 包含 17 项用例，待在 Mac 执行。实测记录见 [Docs/Validation.md](Docs/Validation.md)。

## 开发环境与打开工程

- Mac + Xcode 16 或更新版本（Swift 6 工具链），iOS 17+ SDK/设备。
- Swift 6 语言模式及完整并发检查。SwiftUI、MapKit、Core Location、SwiftData、Foundation、XCTest，无第三方运行时依赖。
- 直接打开 `GhostStride.xcodeproj`，选择共享 Scheme **GhostStride**。
- 已提交完整工程。可选安装 XcodeGen 2.42+，运行 `Scripts/generate-project.sh` 从 `project.yml` 重新生成；也可用 Python 3 运行 `python3 Scripts/bootstrap-project.py`。两种生成方式均会覆盖工程配置，请先保存自行修改的签名/工程设置。

## 真机安装

1. Xcode Settings > Accounts 添加自己的 Apple Account。
2. 连接 iPhone，信任 Mac；在 iPhone 设置 > 隐私与安全性开启开发者模式并按提示重启。
3. Target GhostStride > Signing & Capabilities，勾选 Automatically manage signing，选择 Personal Team。
4. 将 `com.example.GhostStride` 改成自己的唯一 Bundle Identifier。若重生成工程，同时修改 `project.yml`，或重新在 Xcode 设置。测试 target 如需真机测试也选择同一 Team。
5. 选择 iPhone 作为运行目标，按 ⌘R。按设备提示信任开发者签名。

无需付费开发者账户作为必备条件。免费 Personal Team 的签名通常约 7 天到期且存在设备、App ID 等配额；到期后连接 Xcode 重新签名安装，以 Apple 当前规则为准。详细步骤与故障排查见 [定位调试教程](Docs/LocationSimulation.md)。

## 模拟器运行与测试

Xcode 安装一个 iOS 17+ Simulator runtime，选择该模拟器后 ⌘R。按 ⌘U 执行测试。命令行：

```bash
xcrun simctl list devices available
SIMULATOR_UDID='<可用模拟器 UUID>' ./Scripts/test.sh
# 只编译，免签名：
xcodebuild -project GhostStride.xcodeproj -scheme GhostStride \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

测试覆盖经纬度、Haversine、累计距离、不等距插值、跨日期变更线、配速换算、暂停恢复、完成边界、空/单点、循环、非法时钟与速度、GPX 双格式和时间顺序、无效文件及 SwiftData 保存/读取/删除。

## 使用流程

1. 地图上轻点选点，点击“追加选点”；或通过搜索栏输入经纬度、搜索、收藏。
2. 点击“规划”，添加起点/途经点/终点。“编辑”可拖动调整顺序和删除，点击地点可替换。获取步行路线或使用手动轨迹。
3. 点击“播放”，设定速度，开始模拟。返回地图可观察运动标记与已完成线段。播放期间可关闭面板，计时任务不会重复创建。
4. 后台或应用失去活跃状态自动暂停；返回后打开播放面板继续。参数在运行/暂停期间锁定，停止后可修改；再次开始从起点播放。
5. 在“路线库”命名并保存路线。运动停止/结束可保存模拟记录；控制面板观察到完成时自动保存。替换路线或重置会丢弃未保存的本次模拟状态。
6. “导出 GPX”选择 Xcode wpt 或标准 trk，保存到文件，再通过文件 App 分享/AirDrop 到 Mac。

模拟用时包含预览倍率：2×预览的一秒墙钟时间推进两秒模拟时间。暂停不累计，后台不追赶。循环的总距离持续累计，进度和剩余时间指当前圈。单点路线是静态位置，立即完成且距离为零。模拟速度绝不是实际 GPS 传感器速度。

## GPX

`Samples/TwoKilometers.gpx` 是按球面距离构造的约 2000 米直线路线，21 个点，8 km/h 对应 45 秒间隔；仅用于调试，不表示可通行道路。`Samples/StaticLocation.gpx` 是一个静态点。两者也随应用打包，可在路线库载入。

导出使用 GPX 1.1、八位小数坐标和 UTC 时间戳；去掉连续重复点，时间按累计距离/设定速度推算，极近点至少相隔 1 ms。预览倍率、暂停、已播放进度和循环次数不写入文件；每次导出完整的一圈路线。导入不重放原文件的时间、速度或海拔，以当前设定速度播放。混合文件优先 trkpt，然后 rtept，最后 wpt；多段轨迹按文件顺序连接，间隙会直连。XML DTD/实体声明拒绝导入。

Xcode 使用 `wpt`，标准 `trk` 不可直接视为 Xcode 可运行定位路线。时间/速度播放行为仍须在使用的 Xcode 版本验证，详见教程。

## 架构和目录

```text
GhostStride/App/           App 入口与主线程 AppModel
GhostStride/Engine/        纯 Swift 坐标、路线几何、可注入时钟状态机
GhostStride/Services/      真实/模拟定位、MapKit 路线与搜索、GPX
GhostStride/Persistence/   SwiftData 路线、收藏、模拟记录
GhostStride/Views/         地图、选点、规划、播放、仪表盘、资料库、设置、诊断
GhostStride/Resources/     权限说明、图标、打包示例
GhostStrideTests/          XCTest 核心、GPX、SwiftData 测试
GhostStride.xcodeproj/     工程与共享 Scheme
Scripts/                  工程生成、Mac 测试、静态验证
Samples/                  可直接添加到 Xcode 的 GPX
Docs/                     真机教程、验证记录
```

SimulationEngine 接受单调时间，不持有 UI 或计时器。AppModel 在主线程持有唯一可取消 Task；每次更新通过距离查找和球面插值产生坐标。后台暂停，不申请后台定位。SwiftData 只保存本地数据，持久化失败显示错误并保留原始数据库。没有遥测；地图、地点搜索和路线请求由 Apple 服务处理，需网络。

## 已知限制与后续方向

- Apple SDK 编译和设备行为尚待 Mac 验证；地图服务覆盖、权限弹窗、系统文件选择器需要实际验收。
- 不提供全系统 GPS 修改、后台连续播放或 Apple Health 成绩写入。
- 路线规划最多 25 个停靠点；步行备选按每段距离选最短或最长，不展示全部组合。长导入轨迹进入规划器时以首尾点作为新的停靠点。
- 手动轨迹不进行道路吸附。坐标按 MapKit/GPX 原值处理，不额外进行地域坐标变换。
- 尚无自动 UI 测试、真实设备性能基准、撤销操作、多段 GPX 间隙保留和跨启动播放恢复。
- 后续可增加海拔与原始时间保留、路线编辑撤销、轨迹分段、VoiceOver 真机审计及更多设备自动化测试。
