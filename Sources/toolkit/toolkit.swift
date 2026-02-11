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
        // 转换坐标系供 NSPanel 使用 (NSPanel 使用左下角原点)
        let screenPoint = CGPoint(x: centerX, y: screens[0].frame.height - centerY)
        
        // 显示高亮
        CursorHighlighter.show(at: screenPoint)
    }

    @objc func about() {
        let alert = NSAlert()
        alert.messageText = "MouseMover"
        alert.informativeText = "将鼠标移动到指定屏幕。"
        alert.icon = statusItem?.button?.image
        alert.runModal()
    }
}

@MainActor
class CursorHighlighter {
    static func show(at point: CGPoint) {
        let circleSize: CGFloat = 80
        let borderWidth: CGFloat = 4
        let maxScale: CGFloat = 1.5
        let panelSize = circleSize * maxScale + borderWidth * 2
        let rect = NSRect(
            x: point.x - panelSize / 2,
            y: point.y - panelSize / 2,
            width: panelSize,
            height: panelSize
        )

        let panel = NSPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.level = .mainMenu
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false

        guard let contentView = panel.contentView else { return }
        contentView.wantsLayer = true

        let circleLayer = CALayer()
        circleLayer.bounds = CGRect(x: 0, y: 0, width: circleSize, height: circleSize)
        circleLayer.position = CGPoint(x: panelSize / 2, y: panelSize / 2)
        circleLayer.cornerRadius = circleSize / 2
        circleLayer.borderWidth = borderWidth
        circleLayer.borderColor = NSColor.systemOrange.cgColor
        circleLayer.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.2).cgColor

        contentView.layer?.addSublayer(circleLayer)
        panel.orderFrontRegardless()

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            panel.close()
        }

        let transformAnim = CABasicAnimation(keyPath: "transform.scale")
        transformAnim.fromValue = 0.5
        transformAnim.toValue = maxScale

        let fadeAnim = CABasicAnimation(keyPath: "opacity")
        fadeAnim.fromValue = 1.0
        fadeAnim.toValue = 0.0

        let group = CAAnimationGroup()
        group.animations = [transformAnim, fadeAnim]
        group.duration = 0.4
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards

        circleLayer.add(group, forKey: "highlight")
        CATransaction.commit()
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