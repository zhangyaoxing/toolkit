import AppKit

extension NSScreen {
    var displayID: CGDirectDisplayID {
        return deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0
    }
    
    var isBuiltIn: Bool {
        return CGDisplayIsBuiltin(displayID) != 0
    }
    
    var displayName: String {
        let name = localizedName
        let isMain = self == NSScreen.main
        let size = "\(Int(frame.width))x\(Int(frame.height))"
        
        var tags: [String] = []
        if isBuiltIn {
            tags.append("内置")
        }
        if isMain {
            tags.append("主显示器")
        }
        
        let tagString = tags.isEmpty ? "" : " [\(tags.joined(separator: ", "))]"
        return "\(name) (\(size))\(tagString)"
    }
}

struct ScreenHotKeyConfig: Codable {
    let displayID: CGDirectDisplayID
    let keyCode: Int
    let modifiers: Int
    
    var hotKeyModifiers: NSEvent.ModifierFlags {
        return NSEvent.ModifierFlags(rawValue: UInt(modifiers))
    }
}

enum WindowMoveModifier: String, Codable, CaseIterable {
    case control = "control"
    case option = "option"
    case command = "command"
    case shift = "shift"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .control: return "⌃ Control"
        case .option: return "⌥ Option"
        case .command: return "⌘ Command"
        case .shift: return "⇧ Shift"
        case .none: return "禁用"
        }
    }
    
    var eventFlag: NSEvent.ModifierFlags? {
        switch self {
        case .control: return .control
        case .option: return .option
        case .command: return .command
        case .shift: return .shift
        case .none: return nil
        }
    }
}

struct AppPreferences {
    static var windowMoveModifier: WindowMoveModifier {
        get {
            if let savedValue = UserDefaults.standard.string(forKey: "WindowMoveModifier"),
               let modifier = WindowMoveModifier(rawValue: savedValue) {
                return modifier
            }
            return .none
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "WindowMoveModifier")
        }
    }
}
