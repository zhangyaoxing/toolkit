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
        
        // Get current window position and size
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        
        AXUIElementCopyAttributeValue(targetWindow, kAXPositionAttribute as CFString, &positionRef)
        AXUIElementCopyAttributeValue(targetWindow, kAXSizeAttribute as CFString, &sizeRef)
        
        var currentPosition = CGPoint.zero
        var currentSize = CGSize.zero
        
        if let posValue = positionRef {
            AXValueGetValue(posValue as! AXValue, .cgPoint, &currentPosition)
        }
        if let szValue = sizeRef {
            AXValueGetValue(szValue as! AXValue, .cgSize, &currentSize)
        }
        
        print("[DEBUG] Current window position: \(currentPosition), size: \(currentSize)")
        
        // Convert window position from top-left origin (Accessibility API) to bottom-left origin (NSScreen.frame)
        let mainScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let windowPositionBottomLeft = CGPoint(
            x: currentPosition.x,
            y: mainScreenHeight - currentPosition.y - currentSize.height
        )
        
        print("[DEBUG] Window position (bottom-left origin): \(windowPositionBottomLeft)")
        
        // Find current screen containing the window
        let windowCenter = CGPoint(
            x: windowPositionBottomLeft.x + currentSize.width / 2,
            y: windowPositionBottomLeft.y + currentSize.height / 2
        )
        
        guard let currentScreen = NSScreen.screens.first(where: { screen in
            let frame = screen.frame
            return windowCenter.x >= frame.minX && windowCenter.x <= frame.maxX &&
                   windowCenter.y >= frame.minY && windowCenter.y <= frame.maxY
        }) else {
            print("[ERROR] Could not determine current screen")
            return
        }
        
        print("[DEBUG] Current screen: \(currentScreen.displayName)")
        
        // Calculate relative position on current screen (0.0 - 1.0)
        // Use frame (not visibleFrame) to match cursor movement logic
        let currentFrame = currentScreen.frame
        let relativeX = (windowPositionBottomLeft.x - currentFrame.origin.x) / currentFrame.width
        let relativeY = (windowPositionBottomLeft.y - currentFrame.origin.y) / currentFrame.height
        
        print("[DEBUG] Relative position: (\(relativeX), \(relativeY)), current size: (\(currentSize.width), \(currentSize.height))")
        
        // Keep original window size, only adjust if it exceeds target screen visible area
        let targetFrame = targetScreen.frame
        let targetVisibleFrame = targetScreen.visibleFrame
        let finalWidth = min(currentSize.width, targetVisibleFrame.width)
        let finalHeight = min(currentSize.height, targetVisibleFrame.height)
        
        // Position on target screen (same logic as cursor movement)
        var newX = targetFrame.origin.x + (targetFrame.width * relativeX)
        var newY = targetFrame.origin.y + (targetFrame.height * relativeY)
        
        // Ensure window is within visible bounds (not under menu bar or dock)
        newX = max(targetVisibleFrame.origin.x, min(newX, targetVisibleFrame.origin.x + targetVisibleFrame.width - finalWidth))
        newY = max(targetVisibleFrame.origin.y, min(newY, targetVisibleFrame.origin.y + targetVisibleFrame.height - finalHeight))
        
        print("[DEBUG] New position (bottom-left origin): (\(newX), \(newY)), size: (\(finalWidth), \(finalHeight))")
        
        // Convert back to top-left origin for Accessibility API
        let finalX = newX
        let finalY = mainScreenHeight - newY - finalHeight
        
        print("[DEBUG] New position (top-left origin): (\(finalX), \(finalY))")
        
        // Set window position to new location
        var newPosition = CGPoint(x: finalX, y: finalY)
        let positionValue = AXValueCreate(.cgPoint, &newPosition)!
        let posResult = AXUIElementSetAttributeValue(targetWindow, kAXPositionAttribute as CFString, positionValue)
        print("[DEBUG] Set position result: \(posResult.rawValue)")
        
        // Set window size
        var newSize = CGSize(width: finalWidth, height: finalHeight)
        let sizeValue = AXValueCreate(.cgSize, &newSize)!
        let sizeResult = AXUIElementSetAttributeValue(targetWindow, kAXSizeAttribute as CFString, sizeValue)
        print("[DEBUG] Set size result: \(sizeResult.rawValue)")
        
        // Move cursor to window center after moving window
        // Note: finalX, finalY are in top-left origin (Accessibility API coordinates)
        let windowCenterX = finalX + finalWidth / 2
        let windowCenterY = finalY + finalHeight / 2
        
        let targetPoint = CGPoint(x: windowCenterX, y: windowCenterY)
        
        // For highlight, need to convert to bottom-left origin
        let highlightPoint = CGPoint(x: windowCenterX, y: mainScreenHeight - windowCenterY)
        
        print("[DEBUG] Moving cursor to window center (top-left): (\(windowCenterX), \(windowCenterY))")
        
        CursorMover.smoothMove(to: targetPoint) {
            Task { @MainActor in
                CursorMover.highlight(at: highlightPoint)
                CursorMover.focusWindowAtCursor()
            }
        }
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
        alert.icon = NSApp.applicationIconImage
        alert.runModal()
    }
}
