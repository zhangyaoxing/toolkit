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
