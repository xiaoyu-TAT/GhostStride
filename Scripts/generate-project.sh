#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v xcodegen >/dev/null; then
  echo '请先在 Mac 安装 XcodeGen（brew install xcodegen），或直接打开已提交的 GhostStride.xcodeproj。' >&2
  exit 1
fi
xcodegen generate --spec project.yml
