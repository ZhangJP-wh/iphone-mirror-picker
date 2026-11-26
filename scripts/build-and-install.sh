#!/usr/bin/env bash
# Build and install 「iPhone Mirror 选机」menu-bar app to ~/Applications.
# Run on macOS 13+ with Xcode Command Line Tools (swiftc).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/src"
APP_NAME="iPhone Mirror 选机"
APP_DIR="${HOME}/Applications/${APP_NAME}.app"
BIN_NAME="${APP_NAME}"
# Previous bundle name. Removed on install so a re-run does not leave two menu-bar apps.
LEGACY_APP_DIR="${HOME}/Applications/iPhone选机.app"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/iphone-picker-build.XXXXXX")"
trap 'rm -rf "$BUILD_DIR"' EXIT

# Quit a running copy before replacing its bundle.
# pkill -x only sees the first 16 bytes of the process name, which truncates
# this app's executable name, so match the on-disk path instead.
quit_app_at() {
  local app_dir="$1"
  [[ -d "$app_dir" ]] || return 0
  local needle="${app_dir}/Contents/MacOS/"
  local pids
  pids="$(ps -ax -o pid=,command= | grep -F "${needle}" | grep -v grep | awk '{print $1}' || true)"
  [[ -z "${pids}" ]] && return 0
  local pid
  for pid in ${pids}; do
    kill "$pid" 2>/dev/null || true
  done
}

echo "==> Compiling ${APP_NAME}…"
swiftc -O \
  -framework AppKit \
  -framework ApplicationServices \
  -o "${BUILD_DIR}/${BIN_NAME}" \
  "${SRC}/AppMain.swift" \
  "${SRC}/Icon.swift" \
  "${SRC}/DeviceDiscovery.swift" \
  "${SRC}/DeviceSwitcher.swift"

echo "==> Replacing any previous install…"
# Bundle id stays local.iphone-picker so an existing Accessibility grant still applies.
osascript -e 'tell application id "local.iphone-picker" to quit' >/dev/null 2>&1 || true
pkill -x "iPhone选机" 2>/dev/null || true
quit_app_at "${LEGACY_APP_DIR}"
quit_app_at "${APP_DIR}"
sleep 0.4

echo "==> Assembling ${APP_DIR}…"
mkdir -p "${HOME}/Applications"
rm -rf "${LEGACY_APP_DIR}"
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

echo "==> Launching…"
open "${APP_DIR}"

# Best-effort login item (macOS 13+; ignore failure).
# Drop the previous product-name login item so only the new app stays.
osascript <<'OSA' >/dev/null 2>&1 || true
tell application "System Events"
  if exists login item "iPhone选机" then
    delete login item "iPhone选机"
  end if
  if not (exists login item "iPhone Mirror 选机") then
    make login item at end with properties {path:(POSIX path of (path to home folder)) & "Applications/iPhone Mirror 选机.app", hidden:false}
  end if
end tell
OSA

cat <<'MSG'

安装完成。

应用：~/Applications/iPhone Mirror 选机.app

左键：打开「隔空投送与连续互通」选机页
右键：设备列表切换（需要辅助功能权限）

请打开：系统设置 → 隐私与安全 → 辅助功能 → 勾选「iPhone Mirror 选机」
若刚安装/更新后列表里没有或勾不上，退出本应用再开一次，然后重新勾选。

没有辅助功能权限时，仍可用左键打开选机页手动切换。
MSG
