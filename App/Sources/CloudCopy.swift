import Foundation
import UIKit
import ReminderCore

/// 0.5 (pick 28): a second copy of the list in iCloud (key-value store), so it survives a new iPhone.
/// Never used in -uiTesting mode (the Store does not call it then).
enum CloudCopy {
    static let switchKey = "keepCloudCopy"
    static let maxBytes = 900_000
    private static var kvs: NSUbiquitousKeyValueStore { .default }

    static var isOn: Bool {
        UserDefaults.standard.object(forKey: switchKey) == nil ? true : UserDefaults.standard.bool(forKey: switchKey)
    }

    struct Copy {
        var list: ReminderList
        var savedAt: Date
        var device: String
    }

    /// The copy in iCloud, if there is a readable one with something in it.
    static func read() -> Copy? {
        kvs.synchronize()
        guard let data = kvs.data(forKey: "list"), let list = ReminderList.readCopy(data) else { return nil }
        let at = (kvs.object(forKey: "savedAt") as? Date) ?? .distantPast
        return Copy(list: list, savedAt: at, device: kvs.string(forKey: "device") ?? "")
    }

    /// Writes the list (oldest Done entries left out of this copy only, to stay under the size limit).
    /// Returns the time it was saved, or nil when nothing was written.
    @discardableResult
    static func write(_ list: ReminderList, at now: Date = Date()) -> Date? {
        guard isOn, let data = list.trimmedForCloud(maxBytes: maxBytes) else { return nil }
        kvs.set(data, forKey: "list")
        kvs.set(now, forKey: "savedAt")
        kvs.set(UIDevice.current.name, forKey: "device")
        kvs.synchronize()
        return now
    }

    static var lastSaved: Date? { kvs.object(forKey: "savedAt") as? Date }
}
