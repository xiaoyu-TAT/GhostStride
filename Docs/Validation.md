# 第一版验证记录

## 当前执行环境

Linux x86_64；`xcodebuild`、`swift`、`xcodegen` 均不可用。仓库起始仅有 `.gitignore`，其原有内容保留并追加构建忽略项。没有执行 git push。

## 已执行且通过

- Tree-sitter Swift 语法解析：12 个应用源文件、3 个测试文件，共 15 个；无语法错误节点。这不是 Swift 编译器类型检查。
- OpenStep 解析：`project.pbxproj` 的 64 个对象；所有 source/resource 文件存在，引用 ID、目标依赖和共享 Scheme 引用完整。
- Info.plist 解析：仅使用期间定位权限，无后台定位、健康权限或额外 capability。
- GPX 示例解析：静态示例 1 点；运动示例 21 点，球面距离 2000.000 米，时间严格递增，跨度 900 秒，对应 8 km/h；仓库样例与打包资源一致。
- 图标资源引用检查。
- Python 工程生成器连续执行两次，工程文件及共享 Scheme 的 SHA-256 一致。
- 两个 Shell 脚本 `bash -n` 检查通过。
- `Scripts/test.sh` 在无 Xcode 的环境退出码为 1，准确报告缺少完整 Xcode；未执行任何 XCTest。

复现静态检查（独立可选依赖，不属于 App）：

```bash
python3 -m venv /tmp/ghoststride-validation
/tmp/ghoststride-validation/bin/pip install tree-sitter==0.26.1 tree-sitter-swift==0.7.4 openstep-parser==2.0.3
/tmp/ghoststride-validation/bin/python Scripts/validate-static.py
```

## 未执行，不能据此宣称通过

- Xcode 工程实际加载、Apple SDK 类型检查、Swift 6 并发诊断和链接。
- 17 项 XCTest：核心 10 项，GPX 6 项，SwiftData 1 项。
- iPhone/Simulator 安装、界面自动化、地图服务联网请求和真机权限弹窗。
- Personal Team 实际签名、系统文件导入导出、Xcode GPX 实际定位播放。

需在 Mac 打开工程，运行 README 中 `xcodebuild build` 和 `Scripts/test.sh`。若 Xcode 报错，以实际 SDK 诊断为准修复后重跑；静态解析结果不保证 SDK API 和并发兼容性。

## Mac / iPhone 手动验收路径

1. 拒绝定位权限，输入合法/非法坐标，搜索地点并收藏；重启验证收藏存在。
2. 地图追加三个不等距地点，规划步行路线；断网后验证失败提示及手动轨迹替代。
3. 播放、关闭面板、回到地图观察标记和进度；重新打开面板，确认没有重复计时。
4. 暂停等待再继续，检查暂停期间无距离累计；锁屏/后台后回来应保持暂停。
5. 比较 1×/2×/5×预览，验证模拟时间倍率；停止、重置、循环及单点轨迹边界。
6. 保存并重启读取路线；重命名和删除；验证模拟历史标签，无真实健康记录。
7. 两种 GPX 分别导出，文件扩展名为 `.gpx`；导回并对比路线。非法 XML、空文件、超过 5 MB 文件应报错。
8. Core Location 与 Mock 来源来回切换，检查诊断页坐标、速度和时间戳；Core Location 模拟标记需结合系统支持验证。
9. 按 LocationSimulation.md 进行 Xcode wpt 模拟，停止后检查恢复真实定位。
10. 检查小屏、深色模式、大字体、VoiceOver 与地图缩放手势；性能尚未在真实设备基准测量。
