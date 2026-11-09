# iPhone选机 / iPhone Mirror Picker

macOS 菜单栏小工具：一键打开系统「iPhone 镜像」选机页，并可选右键直切已配对的 iPhone。

A tiny macOS menu-bar helper: left-click opens the system iPhone Mirroring device picker; right-click can switch among paired iPhones.

**仓库 / Repo:** https://github.com/ZhangJP-wh/iphone-mirror-picker  
**版本 / Version:** **1.8**（见 `src/Info.plist`）  
**系统 / Requires:** macOS 13+（实际依赖本机「iPhone 镜像 / 隔空投送与连续互通」能力）

![菜单栏图标预览（合成图，非真实桌面截图）](docs/icon-preview.png)

> 预览图由 `Icon.swift` 合成，**不是**真实菜单栏截图，避免泄露壁纸、天气、其他 App 或个人状态。  
> Preview is synthesized from `Icon.swift`, **not** a real menubar screenshot.

## 一句话场景 / What it’s for

- 两台（或多台）iPhone 轮流做「iPhone 镜像」时，不想每次点进设置里翻找  
  Switch which paired iPhone is selected for Apple’s iPhone Mirroring without digging through Settings every time
- **官方一次仍然只能镜像一台**；本工具只加速切换，不能两台同时可操作镜像  
  Apple still allows only **one** active mirrored iPhone; this app only speeds switching

## 怎么用 / How to use

| 操作 | 效果 |
|------|------|
| **左键**点菜单栏图标 | 打开「系统设置 → 隔空投送与连续互通」选机页 |
| **右键**点菜单栏图标 | 列出已发现的 iPhone；点名称尝试自动切换；底部有「打开选机页」「退出」 |
| 未授予辅助功能时 | 右键仍可看列表/开选机页；自动点击切换会提示去开权限 |

## 给电脑小白：一分钟安装（仅 Mac）

## For beginners: 1-minute install (Mac only)

1. 打开本仓库 → 绿色 **Code** → **Download ZIP**  
   Open this repo → **Code** → **Download ZIP**
2. 解压，得到含 `scripts/` 与 `src/` 的文件夹  
   Unzip so you see `scripts/` and `src/`
3. 打开「终端」，把下面路径改成你解压后的真实路径后回车：

```bash
cd ~/Downloads/iphone-mirror-picker-main
bash scripts/build-and-install.sh
```

4. 看菜单栏是否出现双机图标；没有就打开 `~/Applications/iPhone选机.app`  
   Check the menu bar for the dual-phone icon; if missing, open `~/Applications/iPhone选机.app`

需要 **Xcode 命令行工具**（有 `swiftc`）。若提示未安装，按系统弹窗安装即可。

## 给 AI Agent：把下面整段复制发给你的 Agent

## For AI Agents: paste this block

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

完整步骤见 [`AGENT_INSTALL.md`](./AGENT_INSTALL.md)。  
Full agent steps: [`AGENT_INSTALL.md`](./AGENT_INSTALL.md).

---

## 权限 / Permissions

右键**自动切换**需要 **辅助功能**：

1. 系统设置 → 隐私与安全 → 辅助功能  
2. 勾选「iPhone选机」  
3. 刚安装/更新后若无效：先退出再打开本应用，再勾一次  

没有辅助功能时，**左键打开选机页**仍然可用。

## 局限 / Limitations

- Apple 官方「iPhone 镜像」同一时间只能选 **一台**
- 右键自动切换靠辅助功能点击系统设置 UI，**系统改版后可能失效**
- 手机不在附近时，弹出菜单里可能没有该机
- 没有公开、可靠的纯后台改选方式；本工具不伪装系统偏好写入

## 隐私说明 / Privacy

- 本仓库**不包含**作者真实设备名、真实菜单栏截图或本机路径  
- 设备列表在**你自己的 Mac 上运行时**动态读取蓝牙 / Continuity 名称；名单不会写进仓库  
- 请勿把带真实桌面/壁纸/个人状态的截图提交进本仓库  

## 开发者：本地编译

```bash
cd /path/to/iphone-mirror-picker
bash scripts/build-and-install.sh
```

或手动：

```bash
cd src
swiftc -O -framework AppKit -framework ApplicationServices \
  -o "iPhone选机" AppMain.swift Icon.swift DeviceDiscovery.swift DeviceSwitcher.swift
```

合成图标预览（可选）：

```bash
cd src
swiftc -framework AppKit -o /tmp/export_preview Icon.swift ExportPreview.swift
/tmp/export_preview ../docs
```

## 源码结构 / Layout

```
src/AppMain.swift           # 菜单栏、左键/右键
src/Icon.swift              # 双机模板图标（运行时绘制）
src/DeviceDiscovery.swift   # 发现已配对/附近的 iPhone 名
src/DeviceSwitcher.swift    # 辅助功能点击系统设置完成切换
src/Info.plist
src/ExportPreview.swift     # 仅用于生成 docs 预览图
scripts/build-and-install.sh
AGENT_INSTALL.md
```

## License

MIT — see [LICENSE](./LICENSE).
