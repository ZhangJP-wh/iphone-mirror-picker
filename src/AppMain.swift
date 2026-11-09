import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem?
    private var phoneByTitle: [String: String] = [:] // menu title -> device name
    private var isSwitching = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("didFinishLaunching v1.8")
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let img = DualPhoneIcon.make(template: true)
            button.image = img
            button.imagePosition = .imageOnly
            button.toolTip = "左键：打开选机页｜右键：切换 iPhone"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        let m = NSMenu()
        m.delegate = self
        self.statusItem = item
        // Keep a retained menu; rebuild on open
        item.menu = nil // we pop manually on right-click
        rebuildMenu(into: m)
        // Store on statusItem via associated menu property on delegate
        objc_setAssociatedMenu(m)
        log("statusItem ready")
    }

    private var retainedMenu: NSMenu?
    private func objc_setAssociatedMenu(_ m: NSMenu) { retainedMenu = m }

    @objc func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            openPicker()
            return
        }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            guard let button = statusItem?.button, let menu = retainedMenu else { return }
            rebuildMenu(into: menu)
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 2), in: button)
        } else {
            openPicker()
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildMenu(into: menu)
    }

    private func rebuildMenu(into menu: NSMenu) {
        menu.removeAllItems()
        phoneByTitle.removeAll()

        let phones = DeviceDiscovery.listPhones()
        let selected = DeviceDiscovery.selectedName(from: phones)

        if phones.isEmpty {
            let empty = NSMenuItem(title: "未发现可用 iPhone", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for phone in phones {
                let title = phone.name
                let item = NSMenuItem(title: title, action: #selector(selectPhone(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = phone.name
                if let selected, selected == phone.name {
                    item.state = .on
                }
                if phone.nearby {
                    item.toolTip = "附近"
                }
                menu.addItem(item)
                phoneByTitle[title] = phone.name
            }
        }

        menu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(title: "打开选机页", action: #selector(openPicker), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        if !DeviceSwitcher.isAccessibilityTrusted(prompt: false) {
            let ax = NSMenuItem(title: "授予辅助功能权限…", action: #selector(openAXHelp), keyEquivalent: "")
            ax.target = self
            menu.addItem(ax)
        }

        menu.addItem(NSMenuItem.separator())
        let quit = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc func selectPhone(_ sender: NSMenuItem) {
        guard !isSwitching else { return }
        let name = (sender.representedObject as? String) ?? sender.title
        isSwitching = true
        // Run off the main menu-tracking runloop tick
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = DeviceSwitcher.switchTo(phoneName: name)
            DispatchQueue.main.async {
                self?.isSwitching = false
                if result.ok {
                    self?.log("switched OK -> \(result.selected ?? name)")
                    // Brief flash via tooltip
                    self?.statusItem?.button?.toolTip = result.message
                } else {
                    self?.log("switch FAIL: \(result.message)")
                    let alert = NSAlert()
                    alert.messageText = "切换失败"
                    alert.informativeText = result.message + "\n\n仍可用左键打开选机页手动切换。"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "好")
                    alert.runModal()
                }
                if let menu = self?.retainedMenu {
                    self?.rebuildMenu(into: menu)
                }
            }
        }
    }

    @objc func openPicker() {
        let url = URL(string: "x-apple.systempreferences:com.apple.AirDrop-Handoff-Settings.extension")!
        NSWorkspace.shared.open(url)
    }

    @objc func openAXHelp() {
        _ = DeviceSwitcher.isAccessibilityTrusted(prompt: true)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    private func log(_ s: String) {
        let logPath = "/tmp/iphone-picker.log"
        let line = s + "\n"
        guard let data = line.data(using: .utf8) else { return }
        if let fh = FileHandle(forWritingAtPath: logPath) {
            fh.seekToEndOfFile(); fh.write(data); try? fh.close()
        } else {
            FileManager.default.createFile(atPath: logPath, contents: data)
        }
    }
}

let gDelegate = AppDelegate()

@main
struct IPhonePickerApp {
    static func main() {
        let app = NSApplication.shared
        app.delegate = gDelegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
