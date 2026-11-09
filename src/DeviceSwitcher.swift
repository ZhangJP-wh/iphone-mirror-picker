import AppKit
import ApplicationServices
import Foundation

enum DeviceSwitcher {
    struct SwitchResult {
        let ok: Bool
        let message: String
        let menuNames: [String]
        let selected: String?
    }

    static func isAccessibilityTrusted(prompt: Bool) -> Bool {
        if prompt {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(opts)
        }
        return AXIsProcessTrusted()
    }

    static func switchTo(phoneName: String) -> SwitchResult {
        let target = phoneName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else {
            return SwitchResult(ok: false, message: "空设备名", menuNames: [], selected: nil)
        }
        guard isAccessibilityTrusted(prompt: true) else {
            openAccessibilitySettings()
            return SwitchResult(
                ok: false,
                message: "需要辅助功能权限：系统设置 → 隐私与安全 → 辅助功能 → 勾选「iPhone选机」后重试",
                menuNames: [],
                selected: nil
            )
        }

        if let url = URL(string: "x-apple.systempreferences:com.apple.AirDrop-Handoff-Settings.extension") {
            NSWorkspace.shared.open(url)
        }

        // Wait for System Settings + pane
        var settingsApp: NSRunningApplication?
        for _ in 0..<40 {
            settingsApp = NSWorkspace.shared.runningApplications.first {
                $0.bundleIdentifier == "com.apple.systempreferences"
                    || $0.localizedName == "System Settings"
                    || $0.localizedName == "系统设置"
            }
            if settingsApp != nil { break }
            Thread.sleep(forTimeInterval: 0.15)
        }
        guard let settingsApp, let pid = Optional(settingsApp.processIdentifier) else {
            return SwitchResult(ok: false, message: "无法打开系统设置", menuNames: [], selected: nil)
        }
        settingsApp.activate()

        let appEl = AXUIElementCreateApplication(pid)
        var popup: AXUIElement?
        for _ in 0..<20 {
            popup = findIPhonePopUp(appElement: appEl)
            if popup != nil { break }
            Thread.sleep(forTimeInterval: 0.35)
        }
        guard let popup else {
            return SwitchResult(
                ok: false,
                message: "未找到 iPhone 弹出菜单（请确认「隔空投送与连续互通」页已打开，且附近有多台可用 iPhone）",
                menuNames: [],
                selected: nil
            )
        }

        let before = axString(popup, kAXValueAttribute) ?? ""
        _ = axPress(popup)
        Thread.sleep(forTimeInterval: 0.75)

        // Collect menu items under popup
        var names: [String] = []
        var targetItem: AXUIElement?
        if let menu = axChildren(popup).first(where: { axRole($0) == kAXMenuRole }) {
            for item in axChildren(menu) where axRole(item) == kAXMenuItemRole {
                let trimmed = axTitle(item).trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { names.append(trimmed) }
                if trimmed == target { targetItem = item }
            }
        }

        // Fallback: scan all menu items in app
        if targetItem == nil {
            let all = flatten(appEl, limit: 800)
            for el in all where axRole(el) == kAXMenuItemRole {
                let n = axTitle(el).trimmingCharacters(in: .whitespacesAndNewlines)
                if n.localizedCaseInsensitiveContains("Phone") || n.localizedCaseInsensitiveContains("iPhone") {
                    if !names.contains(n) { names.append(n) }
                }
                if n == target { targetItem = el }
            }
        }

        guard let targetItem else {
            // Dismiss menu
            axCancelMenu()
            return SwitchResult(
                ok: false,
                message: "菜单中没有「\(target)」（手机可能不在附近）",
                menuNames: names,
                selected: before.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        _ = axPress(targetItem)
        Thread.sleep(forTimeInterval: 1.0)

        let popup2 = findIPhonePopUp(appElement: appEl) ?? popup
        let after = (axString(popup2, kAXValueAttribute) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let ok = after == target
        if ok {
            DeviceDiscovery.rememberSelection(after)
            DeviceDiscovery.rememberNamesFromSettings(names.isEmpty ? [after] : names)
            return SwitchResult(ok: true, message: "已切换到 \(after)", menuNames: names, selected: after)
        }
        if !names.isEmpty { DeviceDiscovery.rememberNamesFromSettings(names) }
        return SwitchResult(
            ok: false,
            message: "点击了菜单，但当前值仍是「\(after.isEmpty ? before : after)」",
            menuNames: names,
            selected: after.isEmpty ? nil : after
        )
    }

    // MARK: - AX helpers

    private static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func axCancelMenu() {
        let src = CGEventSource(stateID: .hidSystemState)
        if let down = CGEvent(keyboardEventSource: src, virtualKey: 53, keyDown: true),
           let up = CGEvent(keyboardEventSource: src, virtualKey: 53, keyDown: false) {
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    private static func findIPhonePopUp(appElement: AXUIElement) -> AXUIElement? {
        let all = flatten(appElement, limit: 1200)
        for el in all where axRole(el) == kAXPopUpButtonRole {
            let name = axTitle(el).trimmingCharacters(in: .whitespacesAndNewlines)
            if name == "iPhone" { return el }
        }
        return nil
    }

    private static func flatten(_ root: AXUIElement, limit: Int) -> [AXUIElement] {
        var out: [AXUIElement] = []
        var queue: [AXUIElement] = [root]
        while !queue.isEmpty && out.count < limit {
            let el = queue.removeFirst()
            out.append(el)
            queue.append(contentsOf: axChildren(el))
        }
        return out
    }

    private static func axChildren(_ el: AXUIElement) -> [AXUIElement] {
        var ref: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &ref)
        guard err == .success, let arr = ref as? [AXUIElement] else { return [] }
        return arr
    }

    private static func axRole(_ el: AXUIElement) -> String {
        axString(el, kAXRoleAttribute) ?? ""
    }

    /// Best-effort accessibility title / name (AppleScript `name of …`).
    private static func axTitle(_ el: AXUIElement) -> String {
        let candidates = [
            kAXTitleAttribute as String,
            kAXValueAttribute as String,
            kAXDescriptionAttribute as String,
            "AXTitle",
            "AXLabel"
        ]
        for attr in candidates {
            if let s = axString(el, attr)?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                // Skip generic role descriptions
                if s == "弹出式按钮" || s == "按钮" || s == "菜单项" || s == "文本" { continue }
                return s
            }
        }
        return ""
    }

    private static func axString(_ el: AXUIElement, _ attr: String) -> String? {
        var ref: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(el, attr as CFString, &ref)
        guard err == .success else { return nil }
        if let s = ref as? String { return s }
        return nil
    }

    @discardableResult
    private static func axPress(_ el: AXUIElement) -> Bool {
        let err = AXUIElementPerformAction(el, kAXPressAction as CFString)
        return err == .success
    }
}
