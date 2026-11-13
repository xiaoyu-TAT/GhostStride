# 真机安装与 Xcode 定位模拟

## 能力边界

应用内“开始模拟”驱动 MockLocationProvider，只更新本应用地图和模拟指标。安装后可独立运行，不需要 Mac 连接；已有轨迹播放无需联网，地图底图、搜索和在线路线仍可能需要网络。普通 App 不能通过 Core Location 写入全系统 GPS。

Xcode 定位模拟由 Mac 的调试环境提供，依赖 Xcode、签名、设备连接及调试会话。对其他进程的影响由系统和调试环境决定，不保证第三方 App 表现。项目不含私有 API 注入、越狱依赖或检测绕过，不读写 Apple Health 成绩。

## Apple Account 与 Personal Team

1. 在 Mac 安装 Xcode 16+，首次打开完成组件安装。Xcode Settings > Locations 中将 Command Line Tools 指向完整 Xcode。
2. Xcode Settings > Accounts，点 + 添加 Apple Account，按提示登录。仅在 Apple/Xcode 界面输入账户凭据。
3. 打开 `GhostStride.xcodeproj`，选择蓝色工程图标 > TARGETS > GhostStride > Signing & Capabilities。
4. 勾选 Automatically manage signing；Team 选择自己的 Personal Team。
5. 将 `com.example.GhostStride` 改为自己的唯一标识符，例如 `com.yourname.GhostStride`。无需添加 iCloud、HealthKit 等 capability。若真机执行测试，测试 target 也需选择同一 Team。
6. 使用 XcodeGen 重生成时，在 `project.yml` 同步标识符；采用 Python 生成器时也同步脚本默认值。Team 可在 Xcode 内设置，不要提交账户凭据或证书。

无需付费账户作为安装先决条件，不需要 App Store 或 TestFlight。免费 Personal Team 通常约 7 天需重新签名，另有 App ID/设备数量配额，以 Apple 当前规则为准。到期后连接 Xcode 重新运行安装。

## 连接和安装到 iPhone

1. 使用数据线连接已解锁的 iPhone，手机确认“信任此电脑”，完成配对。
2. 在 iPhone 设置 > 隐私与安全性 > 开发者模式打开开关，按提示重启并再次确认。如果此项未显示，先用 Xcode 完成设备配对。
3. Xcode Window > Devices and Simulators 确认设备可用。如果设备 iOS 比当前 Xcode 支持版本新，更新 Xcode 和支持组件。
4. Scheme 选择 GhostStride，运行目标选择 iPhone，按 ⌘R。
5. 如提示开发者不受信任，根据当前 iOS 提示在设置 > 通用 > VPN 与设备管理中信任自己的开发者配置。
6. 先从路线库载入示例测试播放。拒绝位置授权仍可选点、播放；点击真实位置按钮时才需要使用期间定位权限。

签名失败时检查 Team、唯一 Bundle Identifier、账户联网、设备配对及免费配额；不要关闭签名验证或安装未知证书。

## 导出并导入 Xcode GPX

1. 在 GhostStride 选择路线和运动速度，点击“导出 GPX” > “Xcode 定位（wpt）”。
2. 保存到文件，通过 AirDrop 或自选文件传输方式复制到 Mac。应用不会自动上传轨迹。
3. Xcode File > Add Files to “GhostStride”… 选择 `.gpx`，可勾选 Copy items if needed。调试文件不必加入 App 资源 target。
4. 运行真机调试会话，选择 Debug > Simulate Location > 对应 GPX。也可使用调试栏的位置箭头菜单。
5. 如果文件未列出，在 Scheme > Edit Scheme > Run > Options 检查 Allow Location Simulation，并通过 Default Location 选择或添加文件。不同 Xcode 版本的入口名称可能变化。
6. 在 GhostStride 设置中关闭“使用应用内模拟定位”，授予权限，观察开发者工具的 Core Location 坐标和时间戳。

Core Location 也可能收到 Xcode 模拟输入。系统提供标记时，诊断页显示“系统报告为模拟”；“真实定位”表示系统位置提供者，并不保证来自物理 GPS。

Xcode 自定义路线需要 `wpt lat="…" lon="…"`。标准 `trk/trkseg/trkpt` 用于其他轨迹软件，不应直接视作 Xcode 可运行路线。先用 `Samples/StaticLocation.gpx` 验证坐标，再试 `Samples/TwoKilometers.gpx`。

导出时间按完整路线距离与设定速度生成，连续重复点去重，极近点至少相隔 1 ms；不是实际 GPS 采样时间。本应用 2×/5×预览、暂停、循环不会写入 GPX。Xcode 对时间戳、速度和循环的解释随版本变化，需在实际调试环境中验证，不能保证精确复现设定配速。

## 停止模拟与恢复真实位置

1. Xcode Debug > Simulate Location 选择 None / 不模拟（具体名称随版本变化）。
2. Scheme > Run > Options 将默认模拟位置设为 None，避免下次自动启用。
3. 停止调试，必要时断开连接并重新启动应用。
4. GhostStride 切换到 Core Location，在开阔区域等待新的有效定位，检查时间戳和坐标。
5. 若仍出现旧值，确认所有 Xcode 调试会话已结束，再重启应用或设备验证。授权、系统定位服务和物理环境也影响结果。

App 内“停止”只停止自身引擎，不能关闭 Mac 上的 Xcode 模拟。后台自动暂停内部播放，返回后需手动继续。

## 隐私

SwiftData 数据保存在设备本地，无登录、后端、遥测或健康数据访问。地图、搜索及步行路线由 Apple MapKit 提供，查询需要发送给 Apple。GPX 包含精确坐标，分享前确认接收者。
