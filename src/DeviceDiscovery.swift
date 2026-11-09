import Foundation

struct MirrorPhone: Equatable {
    let name: String
    let address: String?
    let deviceID: String?
    let nearby: Bool
}

enum DeviceDiscovery {
    private static let excludeNameRegex: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: #"(?i)watch|airpods|mac\s|macbook|imac|mac\smini|beats|headset|headphone|keyboard|trackpad|mouse|magic\s"#
        )
    }()

    private static let excludeMinor: Set<String> = [
        "Keyboard", "Headset", "Headphones", "Magic Trackpad", "Mouse", "Trackpad"
    ]

    static func listPhones() -> [MirrorPhone] {
        let addressToID = cloudpairAddressMapping() // MAC -> UUID
        let bt = bluetoothDevices()
        var byName: [String: MirrorPhone] = [:]

        for dev in bt {
            let name = dev.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            if isExcluded(name: name, minorType: dev.minorType) { continue }

            let addr = normalizeMAC(dev.address)
            let id = addr.isEmpty ? nil : addressToID[addr]
            // Treat names that look like phones (iPhone… / …Phone… / …Phone12).
            // Headphones etc. are filtered by excludeNameRegex / excludeMinor above.
            let looksPhone = name.localizedCaseInsensitiveContains("iphone")
                || name.range(of: #"(?i)phone"#, options: .regularExpression) != nil

            // Keep Continuity-mapped nearby phone-like devices, or explicitly phone-named devices.
            let include: Bool
            if looksPhone {
                include = true
            } else if id != nil && dev.nearby && (dev.minorType == nil) {
                // Continuity accessory that isn't clearly a phone — skip to avoid Watch-like leftovers
                include = false
            } else {
                include = false
            }
            guard include else { continue }

            let phone = MirrorPhone(
                name: name,
                address: addr.isEmpty ? nil : addr,
                deviceID: id,
                nearby: dev.nearby
            )
            if let existing = byName[name] {
                if existing.deviceID == nil && phone.deviceID != nil { byName[name] = phone }
                else if !existing.nearby && phone.nearby { byName[name] = phone }
            } else {
                byName[name] = phone
            }
        }

        for cached in cachedNames() {
            if byName[cached] == nil {
                byName[cached] = MirrorPhone(name: cached, address: nil, deviceID: nil, nearby: false)
            }
        }

        // No hardcoded personal device names. Empty list → UI shows “未发现可用 iPhone”.
        return byName.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func selectedName(from phones: [MirrorPhone]) -> String? {
        if let last = UserDefaults.standard.string(forKey: "lastSelectedPhoneName")?
            .trimmingCharacters(in: .whitespacesAndNewlines), !last.isEmpty {
            if phones.contains(where: { $0.name == last }) { return last }
        }
        if let id = currentOnenessDeviceID() {
            if let match = phones.first(where: { $0.deviceID == id }) {
                return match.name
            }
            let map = cloudpairAddressMapping()
            if let mac = map.first(where: { $0.value == id })?.key,
               let match = phones.first(where: { $0.address == mac }) {
                return match.name
            }
        }
        return nil
    }

    static func rememberSelection(_ name: String) {
        UserDefaults.standard.set(
            name.trimmingCharacters(in: .whitespacesAndNewlines),
            forKey: "lastSelectedPhoneName"
        )
    }

    static func rememberNamesFromSettings(_ names: [String]) {
        let cleaned = names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return }
        UserDefaults.standard.set(cleaned, forKey: "cachedPhoneNames")
    }

    private static func cachedNames() -> [String] {
        (UserDefaults.standard.array(forKey: "cachedPhoneNames") as? [String] ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func currentOnenessDeviceID() -> String? {
        let p = UserDefaults(suiteName: "com.apple.ScreenContinuity")
        if let id = p?.string(forKey: "onenessPairedDeviceID"), !id.isEmpty { return id }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", "com.apple.ScreenContinuity", "onenessPairedDeviceID"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let s = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (s?.isEmpty == false) ? s : nil
        } catch {
            return nil
        }
    }

    private static func isExcluded(name: String, minorType: String?) -> Bool {
        if let m = minorType, excludeMinor.contains(m) { return true }
        let range = NSRange(name.startIndex..<name.endIndex, in: name)
        return excludeNameRegex.firstMatch(in: name, options: [], range: range) != nil
    }

    private static func normalizeMAC(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func cloudpairAddressMapping() -> [String: String] {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/com.apple.cloudpaird.plist")
        guard let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let map = dict["AddressMapping"] as? [String: String] else { return [:] }
        var out: [String: String] = [:]
        for (uuid, mac) in map {
            out[normalizeMAC(mac)] = uuid
        }
        return out
    }

    private struct BTDevice {
        let name: String
        let address: String
        let minorType: String?
        let nearby: Bool
    }

    private static func bluetoothDevices() -> [BTDevice] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = ["SPBluetoothDataType", "-json"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = root["SPBluetoothDataType"] as? [[String: Any]],
              let first = arr.first else { return [] }

        var result: [BTDevice] = []
        func ingest(_ list: Any?, nearbyForce: Bool) {
            guard let list = list as? [[String: Any]] else { return }
            for item in list {
                for (name, infoAny) in item {
                    guard let info = infoAny as? [String: Any] else { continue }
                    let addr = (info["device_address"] as? String) ?? ""
                    let minor = info["device_minorType"] as? String
                    let rssi = info["device_rssi"]
                    let isNearby = nearbyForce || rssi != nil
                    result.append(BTDevice(name: name, address: addr, minorType: minor, nearby: isNearby))
                }
            }
        }
        ingest(first["device_connected"], nearbyForce: true)
        ingest(first["device_not_connected"], nearbyForce: false)
        return result
    }
}
