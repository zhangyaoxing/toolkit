import AppKit
import HotKey

class AppDelegate: NSObject, NSApplicationDelegate {
    // 1. 定义状态栏条目
    var statusItem: NSStatusItem?
    // 保持 HotKey 对象的引用，否则会被销毁
    var hotKeys: [HotKey] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 2. 初始化状态栏
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = "🖱️" // 你也可以用 button.image 设置图标
        }

        // 3. 构建菜单
        setupMenu()

        // 4. 设置快捷键 (复用你之前的逻辑)
        setupHotKeys()
    }

    func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "关于鼠标工具", action: #selector(about), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator()) // 分割线
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
    }

    @MainActor
    @objc func about() {
        let alert = NSAlert()
        alert.messageText = "MouseMover"
        alert.informativeText = "将鼠标移动到指定屏幕。"
        alert.runModal()
    }
}

@main
struct toolkit {
    static func main() {
        // --- 启动逻辑 ---
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate

        // 关键点：设置应用不显示在 Dock 栏 (UIElement 模式)
        app.setActivationPolicy(.accessory) 

        app.run()
    }
}