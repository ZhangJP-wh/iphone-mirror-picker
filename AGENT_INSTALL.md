# Agent install instructions / Agent 安装说明

If a user pastes https://github.com/ZhangJP-wh/iphone-mirror-picker and asks you to install this macOS menu-bar app, follow this file.

若用户把上述仓库链接发给你并要求安装本应用，请按本文件执行。

**Platform:** macOS 13+ only（需要系统「iPhone 镜像 / 隔空投送与连续互通」）。  
**Needs:** Xcode Command Line Tools（`swiftc`、`codesign`）。

## Success criteria / 成功标准

- `~/Applications/iPhone选机.app` exists and launches
- A dual-phone icon appears in the **menu bar**
- **Left-click** opens System Settings → AirDrop & Handoff / 隔空投送与连续互通（选机页）
- **Right-click** shows a device list +「打开选机页」+「退出」
- User is reminded to enable **Accessibility** for right-click auto-switch

## Procedure / 步骤

1. Download ZIP from GitHub（**Code → Download ZIP**）or  
   `git clone https://github.com/ZhangJP-wh/iphone-mirror-picker.git`
2. Unzip / enter the repo root（must contain `scripts/build-and-install.sh` and `src/`）.
3. On the user’s Mac, run:

```bash
cd /path/to/iphone-mirror-picker
bash scripts/build-and-install.sh
```

4. Confirm the menu-bar icon appears. If not, open `~/Applications/iPhone选机.app`.
5. Tell the user（in their language）to grant Accessibility if they want right-click switching:

   - 系统设置 → 隐私与安全 → 辅助功能 → 勾选「iPhone选机」
   - After reinstall/update: quit the app, reopen it, then re-check the box if needed

6. Smoke-test left-click → settings pane opens. Do **not** force a right-click switch unless the user asks（needs Accessibility + phones nearby）.

## Constraints / 约束

- macOS only. Do **not** try to install on Windows/Linux.
- Do **not** rewrite app code unless compile/install fails.
- Prefer ZIP download for non-technical users.
- Do **not** capture or commit the user’s real menu bar / wallpaper / device names.
- Official Apple iPhone Mirroring still allows **only one** active phone at a time; this tool only speeds up switching.

## Pasteable block / 可粘贴指令

```text
Please install this macOS menu-bar app for me from:
https://github.com/ZhangJP-wh/iphone-mirror-picker

Goal: build and install 「iPhone选机」 so I get a menu-bar icon.

Steps (do them for me on my Mac):
1. Download the repo ZIP from GitHub (Code → Download ZIP), or clone the repo.
2. Unzip if needed. The folder must contain scripts/build-and-install.sh and src/.
3. Run: bash scripts/build-and-install.sh
4. Confirm ~/Applications/iPhone选机.app launched and a dual-phone icon is in the menu bar.
5. Remind me: left-click opens the iPhone picker settings page; right-click lists phones (needs Accessibility: System Settings → Privacy & Security → Accessibility → enable 「iPhone选机」).
6. Do not rewrite the code unless install fails. Prefer ZIP for non-technical users.
When done, tell me briefly that it is installed and how left/right click work.
```
