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
            button.image = NSImage(
                systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "Mouse Mover")?
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
        menu.addItem(
            NSMenuItem(
                title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

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
        let targetScreen = screens[index]
        let frame = targetScreen.frame

        if NSEvent.pressedMouseButtons == 0 {
            let centerX = frame.origin.x + (frame.size.width / 2)
            let centerY =
                (NSScreen.screens.first?.frame.height ?? 0)
                - (frame.origin.y + (frame.size.height / 2))

            CGWarpMouseCursorPosition(CGPoint(x: centerX, y: centerY))

            // 转换坐标系供 NSPanel 使用 (NSPanel 使用左下角原点)
            let screenPoint = CGPoint(x: centerX, y: screens[0].frame.height - centerY)
            CursorMover.highlight(at: screenPoint)
            CursorMover.focusWindowAtCursor()
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

                // 转换 Y 坐标用于 CGWarpMouseCursorPosition (top-left origin)
                let mainScreenHeight = NSScreen.screens.first?.frame.height ?? 0
                let warpY = mainScreenHeight - newY

                CGWarpMouseCursorPosition(CGPoint(x: newX, y: warpY))

                // 高亮 (bottom-left origin)
                CursorMover.highlight(at: CGPoint(x: newX, y: newY))
            }
        }
    }

    @objc func about() {
        let alert = NSAlert()
        alert.messageText = "MouseMover"
        alert.informativeText = "将鼠标移动到指定屏幕。"
        alert.icon = statusItem?.button?.image
        alert.runModal()
    }
}
