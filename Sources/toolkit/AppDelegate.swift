import AppKit
import HotKey

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    // 1. Define status bar item
    var statusItem: NSStatusItem?
    // Keep reference to HotKey objects to prevent deallocation
    var hotKeys: [HotKey] = []
    var preferencesWindowController: PreferencesWindowController?
    var screenToDisplayIDMap: [Int: CGDirectDisplayID] = [:]
    
    // Key mapping
    let keyMapping: [Key] = [
        .one, .two, .three, .four, .five, .six, .seven, .eight, .nine, .zero,
        .a, .b, .c, .d, .e, .f, .g, .h, .i, .j, .k, .l, .m, .n, .o, .p, .q, .r, .s, .t, .u, .v, .w, .x, .y, .z
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 2. Initialize status bar
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Use SF Symbols name
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            button.image = NSImage(
                systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "Mouse Mover")?
                .withSymbolConfiguration(config)
        }

        // 3. Build menu
        setupMenu()

        // 4. Setup hotkeys (reuse previous logic)
        setupHotKeys()
        
        // 5. Listen for configuration updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadHotKeys),
            name: NSNotification.Name("ReloadHotKeys"),
            object: nil
        )
    }

    func setupMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "About Mouse Tool", action: #selector(about), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    func setupHotKeys() {
        // Clear existing hotkeys
        hotKeys.removeAll()
        screenToDisplayIDMap.removeAll()
        
        print("[DEBUG] === Setting up hotkeys ===")
        let windowMoveModifier = AppPreferences.windowMoveModifier
        print("[DEBUG] Window move modifier: \(windowMoveModifier)")
        
        // Load from configuration
        if let savedData = UserDefaults.standard.data(forKey: "ScreenHotKeyConfigs"),
           let configs = try? JSONDecoder().decode([ScreenHotKeyConfig].self, from: savedData) {
            
            print("[DEBUG] Loaded \(configs.count) hotkey configs")
            
            for (index, config) in configs.enumerated() {
                guard config.keyCode < keyMapping.count else { continue }
                
                let key = keyMapping[config.keyCode]
                var modifiers: NSEvent.ModifierFlags = []
                
                let savedModifiers = NSEvent.ModifierFlags(rawValue: UInt(config.modifiers))
                if savedModifiers.contains(.command) { modifiers.insert(.command) }
                if savedModifiers.contains(.shift) { modifiers.insert(.shift) }
                if savedModifiers.contains(.option) { modifiers.insert(.option) }
                if savedModifiers.contains(.control) { modifiers.insert(.control) }
                
                print("[DEBUG] Config \(index): displayID=\(config.displayID), key=\(key), modifiers=\(modifiers)")
                
                // Register hotkey for cursor movement
                let cursorHotKey = HotKey(key: key, modifiers: modifiers)
                cursorHotKey.keyDownHandler = { [weak self] in
                    print("[DEBUG] Cursor hotkey triggered for displayID: \(config.displayID)")
                    self?.moveCursorToDisplay(displayID: config.displayID, moveWindow: false)
                }
                hotKeys.append(cursorHotKey)
                
                // Register additional hotkey with window move modifier for window movement
                if let windowMoveFlag = windowMoveModifier.eventFlag {
                    var windowModifiers = modifiers
                    windowModifiers.insert(windowMoveFlag)
                    
                    print("[DEBUG] Registering window move hotkey with modifiers: \(windowModifiers)")
                    
                    let windowHotKey = HotKey(key: key, modifiers: windowModifiers)
                    windowHotKey.keyDownHandler = { [weak self] in
                        print("[DEBUG] Window hotkey triggered for displayID: \(config.displayID)")
                        self?.moveCursorToDisplay(displayID: config.displayID, moveWindow: true)
                    }
                    hotKeys.append(windowHotKey)
                }
                
                screenToDisplayIDMap[index] = config.displayID
            }
        } else {
            // Default configuration (compatible with old version)
            let defaultConfigs: [(Key, NSEvent.ModifierFlags, Int)] = [
                (.one, [.command, .shift], 0),
                (.two, [.command, .shift], 1),
                (.three, [.command, .shift], 2)
            ]
            
            let screens = NSScreen.screens
            for (key, modifiers, index) in defaultConfigs {
                guard index < screens.count else { continue }
                
                let displayID = screens[index].displayID
                
                // Register hotkey for cursor movement
                let cursorHotKey = HotKey(key: key, modifiers: modifiers)
                cursorHotKey.keyDownHandler = { [weak self] in
                    self?.moveCursorToDisplay(displayID: displayID, moveWindow: false)
                }
                hotKeys.append(cursorHotKey)
                
                // Register additional hotkey with window move modifier for window movement
                if let windowMoveFlag = windowMoveModifier.eventFlag {
                    var windowModifiers = modifiers
                    windowModifiers.insert(windowMoveFlag)
                    
                    let windowHotKey = HotKey(key: key, modifiers: windowModifiers)
                    windowHotKey.keyDownHandler = { [weak self] in
                        self?.moveCursorToDisplay(displayID: displayID, moveWindow: true)
                    }
                    hotKeys.append(windowHotKey)
                }
                
                screenToDisplayIDMap[index] = displayID
            }
        }
    }

    func moveCursorToDisplay(displayID: CGDirectDisplayID, moveWindow: Bool = false) {
        print("[DEBUG] === moveCursorToDisplay called, displayID: \(displayID), moveWindow: \(moveWindow) ===")
        let screens = NSScreen.screens
        guard let targetScreen = screens.first(where: { $0.displayID == displayID }) else { 
            print("[ERROR] Target screen not found for displayID: \(displayID)")
            return 
        }
        let frame = targetScreen.frame
        print("[DEBUG] Target screen: \(targetScreen.displayName)")
        
        // If moveWindow flag is set, move window directly
        if moveWindow {
            print("[DEBUG] Moving window to screen: \(targetScreen.displayName)")
            moveWindowToScreen(targetScreen)
            return
        }

        if NSEvent.pressedMouseButtons == 0 {
            let centerX = frame.origin.x + (frame.size.width / 2)
            let centerY =
                (NSScreen.screens.first?.frame.height ?? 0)
                - (frame.origin.y + (frame.size.height / 2))

            // Use smooth movement
            let targetPoint = CGPoint(x: centerX, y: centerY)
            // Pre-calculate for the completion handler to avoid capturing 'screens' which is non-Sendable
            let highlightPoint = CGPoint(x: centerX, y: screens[0].frame.height - centerY)

            CursorMover.smoothMove(to: targetPoint) {
                // Show highlight and focus after movement
                Task { @MainActor in
                    CursorMover.highlight(at: highlightPoint)
                    CursorMover.focusWindowAtCursor()
                }
            }
        } else {
            // Move cursor to same relative position on new screen (maintain relative proportion)
            if let sourceScreen = CursorMover.currentScreen {
                let mouseLoc = NSEvent.mouseLocation
                let sourceFrame = sourceScreen.frame

                // Calculate relative position (0.0 - 1.0)
                let relativeX = (mouseLoc.x - sourceFrame.origin.x) / sourceFrame.width
                let relativeY = (mouseLoc.y - sourceFrame.origin.y) / sourceFrame.height

                // Position on target screen
                let newX = frame.origin.x + (frame.width * relativeX)
                let newY = frame.origin.y + (frame.height * relativeY)

                // Convert Y coordinate for smoothMove (top-left origin)
                let mainScreenHeight = NSScreen.screens.first?.frame.height ?? 0
                let warpY = mainScreenHeight - newY

                let targetPoint = CGPoint(x: newX, y: warpY)
                let highlightPoint = CGPoint(x: newX, y: newY)

                // Use smooth movement
                CursorMover.smoothMove(to: targetPoint) {
                    Task { @MainActor in
                        // Highlight (bottom-left origin)
                        CursorMover.highlight(at: highlightPoint)
                    }
                }
            }
        }
    }
    
    func moveWindowToScreen(_ targetScreen: NSScreen) {
        // Get currently focused window
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            print("[ERROR] No frontmost application found")
            return
        }
        
        print("[DEBUG] Frontmost app: \(frontmostApp.localizedName ?? "Unknown") (PID: \(frontmostApp.processIdentifier))")
        
        // Use Accessibility API to get windows
        let ownerPID = frontmostApp.processIdentifier
        let element = AXUIElementCreateApplication(ownerPID)
        var windowList: CFTypeRef?
        
        let result = AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &windowList)
        print("[DEBUG] AXUIElementCopyAttributeValue result: \(result.rawValue)")
        
        guard result == .success,
              let windows = windowList as? [AXUIElement],
              !windows.isEmpty else {
            print("[ERROR] Failed to get windows. Result: \(result.rawValue), Windows count: \(windowList != nil ? (windowList as? [AXUIElement])?.count ?? 0 : 0)")
            return
        }
        
        let targetWindow = windows.first!
        print("[DEBUG] Found \(windows.count) windows, using first one")
        
        // Calculate new window position (center on target screen)
        let screenFrame = targetScreen.visibleFrame
        
        // Set window position to screen visible area
        var newPosition = CGPoint(x: screenFrame.origin.x, y: screenFrame.origin.y)
        let positionValue = AXValueCreate(.cgPoint, &newPosition)!
        let posResult = AXUIElementSetAttributeValue(targetWindow, kAXPositionAttribute as CFString, positionValue)
        print("[DEBUG] Set position to \(newPosition), result: \(posResult.rawValue)")
        
    }

    @objc func showPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(window: nil)
        }
        preferencesWindowController?.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func reloadHotKeys() {
        setupHotKeys()
    }
    
    @objc func about() {
        let alert = NSAlert()
        alert.messageText = "MouseMover"
        alert.informativeText = "Move mouse to specified screen."
        alert.icon = statusItem?.button?.image
        alert.runModal()
    }
}
