import AppKit
import HotKey

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    // 1. 定义状态栏条目
    var statusItem: NSStatusItem?
    // 保持 HotKey 对象的引用，否则会被销毁
    var hotKeys: [HotKey] = []
    var preferencesWindowController: PreferencesWindowController?
    var screenToDisplayIDMap: [Int: CGDirectDisplayID] = [:]
    
    // 按键映射
    let keyMapping: [Key] = [
        .one, .two, .three, .four, .five, .six, .seven, .eight, .nine, .zero,
        .a, .b, .c, .d, .e, .f, .g, .h, .i, .j, .k, .l, .m, .n, .o, .p, .q, .r, .s, .t, .u, .v, .w, .x, .y, .z
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 2. 初始化状态栏
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // 使用 SF Symbols 名字
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            button.image = NSImage(
                systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "Mouse Mover")?
                .withSymbolConfiguration(config)
        }

        // 3. 构建菜单
        setupMenu()

        // 4. 设置快捷键 (复用你之前的逻辑)
        setupHotKeys()
        
        // 5. 监听配置更新
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadHotKeys),
            name: NSNotification.Name("ReloadHotKeys"),
            object: nil
        )
    }

    func setupMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "选项...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "关于鼠标工具", action: #selector(about), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    func setupHotKeys() {
        // 清除现有快捷键
        hotKeys.removeAll()
        screenToDisplayIDMap.removeAll()
        
        // 从配置加载
        if let savedData = UserDefaults.standard.data(forKey: "ScreenHotKeyConfigs"),
           let configs = try? JSONDecoder().decode([ScreenHotKeyConfig].self, from: savedData) {
            
            for (index, config) in configs.enumerated() {
                guard config.keyCode < keyMapping.count else { continue }
                
                let key = keyMapping[config.keyCode]
                var modifiers: NSEvent.ModifierFlags = []
                
                let savedModifiers = NSEvent.ModifierFlags(rawValue: UInt(config.modifiers))
                if savedModifiers.contains(.command) { modifiers.insert(.command) }
                if savedModifiers.contains(.shift) { modifiers.insert(.shift) }
                if savedModifiers.contains(.option) { modifiers.insert(.option) }
                if savedModifiers.contains(.control) { modifiers.insert(.control) }
                
                let hotKey = HotKey(key: key, modifiers: modifiers)
                hotKey.keyDownHandler = { [weak self] in
                    self?.moveCursorToDisplay(displayID: config.displayID)
                }
                hotKeys.append(hotKey)
                screenToDisplayIDMap[index] = config.displayID
            }
        } else {
            // 默认配置（兼容旧版本）
            let defaultConfigs: [(Key, NSEvent.ModifierFlags, Int)] = [
                (.one, [.command, .shift], 0),
                (.two, [.command, .shift], 1),
                (.three, [.command, .shift], 2)
            ]
            
            let screens = NSScreen.screens
            for (key, modifiers, index) in defaultConfigs {
                guard index < screens.count else { continue }
                
                let hotKey = HotKey(key: key, modifiers: modifiers)
                let displayID = screens[index].displayID
                hotKey.keyDownHandler = { [weak self] in
                    self?.moveCursorToDisplay(displayID: displayID)
                }
                hotKeys.append(hotKey)
                screenToDisplayIDMap[index] = displayID
            }
        }
    }

    func moveCursorToDisplay(displayID: CGDirectDisplayID) {
        let screens = NSScreen.screens
        guard let targetScreen = screens.first(where: { $0.displayID == displayID }) else { return }
        let frame = targetScreen.frame

        if NSEvent.pressedMouseButtons == 0 {
            let centerX = frame.origin.x + (frame.size.width / 2)
            let centerY =
                (NSScreen.screens.first?.frame.height ?? 0)
                - (frame.origin.y + (frame.size.height / 2))

            // 使用平滑移动
            let targetPoint = CGPoint(x: centerX, y: centerY)
            // Pre-calculate for the completion handler to avoid capturing 'screens' which is non-Sendable
            let highlightPoint = CGPoint(x: centerX, y: screens[0].frame.height - centerY)

            CursorMover.smoothMove(to: targetPoint) {
                // 移动结束后显示高亮和聚焦
                Task { @MainActor in
                    CursorMover.highlight(at: highlightPoint)
                    CursorMover.focusWindowAtCursor()
                }
            }
        } else {
            // 鼠标移动到新屏幕上同样位置 (保持相对比例)
            if let sourceScreen = CursorMover.currentScreen {
                let mouseLoc = NSEvent.mouseLocation
                let sourceFrame = sourceScreen.frame

                // 计算相对位置 (0.0 - 1.0)
                let relativeX = (mouseLoc.x - sourceFrame.origin.x) / sourceFrame.width
                let relativeY = (mouseLoc.y - sourceFrame.origin.y) / sourceFrame.height

                // 目标屏幕上的位置
                let newX = frame.origin.x + (frame.width * relativeX)
                let newY = frame.origin.y + (frame.height * relativeY)

                // 转换 Y 坐标用于 smoothMove (top-left origin)
                let mainScreenHeight = NSScreen.screens.first?.frame.height ?? 0
                let warpY = mainScreenHeight - newY

                let targetPoint = CGPoint(x: newX, y: warpY)
                let highlightPoint = CGPoint(x: newX, y: newY)

                // 使用平滑移动
                CursorMover.smoothMove(to: targetPoint) {
                    Task { @MainActor in
                        // 高亮 (bottom-left origin)
                        CursorMover.highlight(at: highlightPoint)
                    }
                }
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
        alert.informativeText = "将鼠标移动到指定屏幕。"
        alert.icon = statusItem?.button?.image
        alert.runModal()
    }
}
