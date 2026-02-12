import AppKit
import HotKey

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    // 1. 定义状态栏条目
    var statusItem: NSStatusItem?
    // 保持 HotKey 对象的引用，否则会被销毁
    var hotKeys: [HotKey] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 2. 初始化状态栏
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // 使用 SF Symbols 名字
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            button.image = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "Mouse Mover")?
                .withSymbolConfiguration(config)
        }

        // 3. 构建菜单
        setupMenu()

        // 4. 设置快捷键 (复用你之前的逻辑)
        setupHotKeys()
    }

    func setupMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: "关于鼠标工具", action: #selector(about), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    func setupHotKeys() {
        let hk1 = HotKey(key: .one, modifiers: [.command, .shift])
        let hk2 = HotKey(key: .two, modifiers: [.command, .shift])
        let hk3 = HotKey(key: .three, modifiers: [.command, .shift])
        hk1.keyDownHandler = { [weak self] in
            self?.moveCursorToScreen(index: 0)
        }
        hk2.keyDownHandler = { [weak self] in
            self?.moveCursorToScreen(index: 1)
        }
        hk3.keyDownHandler = { [weak self] in
            self?.moveCursorToScreen(index: 2)
        }
        hotKeys.append(hk1)
        hotKeys.append(hk2)
        hotKeys.append(hk3)
    }

    func moveCursorToScreen(index: Int) {
        let screens = NSScreen.screens
        guard index < screens.count else { return }
        let frame = screens[index].frame
        let centerX = frame.origin.x + (frame.size.width / 2)
        let centerY = (NSScreen.screens.first?.frame.height ?? 0) - (frame.origin.y + (frame.size.height / 2))
        CGWarpMouseCursorPosition(CGPoint(x: centerX, y: centerY))
        // 转换坐标系供 NSPanel 使用 (NSPanel 使用左下角原点)
        let screenPoint = CGPoint(x: centerX, y: screens[0].frame.height - centerY)

        // 显示高亮
        CursorHighlighter.show(at: screenPoint)
        CursorHighlighter.focusWindowAtCursor()
    }

    @objc func about() {
        let alert = NSAlert()
        alert.messageText = "MouseMover"
        alert.informativeText = "将鼠标移动到指定屏幕。"
        alert.icon = statusItem?.button?.image
        alert.runModal()
    }
}
