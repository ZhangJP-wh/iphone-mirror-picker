#!/usr/bin/env bash
# Build and install 「iPhone选机」menu-bar app to ~/Applications.
# Run on macOS 13+ with Xcode Command Line Tools (swiftc).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/src"
APP_NAME="iPhone选机"
APP_DIR="${HOME}/Applications/${APP_NAME}.app"
BIN_NAME="${APP_NAME}"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/iphone-picker-build.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

echo "==> Compiling ${APP_NAME}…"
swiftc -O \
  -framework AppKit \
  -framework ApplicationServices \
  -o "${BUILD_DIR}/${BIN_NAME}" \
  "${SRC}/AppMain.swift" \
  "${SRC}/Icon.swift" \
  "${SRC}/DeviceDiscovery.swift" \
  "${SRC}/DeviceSwitcher.swift"

echo "==> Assembling ${APP_DIR}…"
mkdir -p "${HOME}/Applications"
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${SRC}/Info.plist" "${APP_DIR}/Contents/Info.plist"
cp "${BUILD_DIR}/${BIN_NAME}" "${APP_DIR}/Contents/MacOS/${BIN_NAME}"
chmod +x "${APP_DIR}/Contents/MacOS/${BIN_NAME}"
printf 'APPL????' > "${APP_DIR}/Contents/PkgInfo"

# Optional: write a tiny synthetic status icon PNG from the same Icon.swift (best-effort).
# Menubar uses DualPhoneIcon.make at runtime; Resources icons are optional.

echo "==> Ad-hoc codesign…"
codesign -s - --force --deep "${APP_DIR}" >/dev/null

# Quit previous instance if running
pkill -x "${APP_NAME}" 2>/dev/null || true
sleep 0.4

echo "==> Launching…"
open "${APP_DIR}"

# Best-effort login item (macOS 13+; ignore failure)
osascript <<'OSA' >/dev/null 2>&1 || true
tell application "System Events"
  if not (exists login item "iPhone选机") then
    make login item at end with properties {path:(POSIX path of (path to home folder)) & "Applications/iPhone选机.app", hidden:false}
  end if
end tell
OSA

cat <<'MSG'

安装完成。

左键：打开「隔空投送与连续互通」选机页
右键：设备列表切换（需要辅助功能权限）

请打开：系统设置 → 隐私与安全 → 辅助功能 → 勾选「iPhone选机」
若刚安装/更新后列表里没有或勾不上，退出本应用再开一次，然后重新勾选。

没有辅助功能权限时，仍可用左键打开选机页手动切换。
MSG
