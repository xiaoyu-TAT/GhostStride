#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodebuild >/dev/null; then echo '需要安装完整 Xcode 的 Mac。' >&2; exit 1; fi
# Run xcrun simctl list devices available and supply an installed simulator UDID.
: "${SIMULATOR_UDID:?请设置 SIMULATOR_UDID 为可用 iOS 17+ 模拟器 UUID}"
xcodebuild -project GhostStride.xcodeproj -scheme GhostStride -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO test
