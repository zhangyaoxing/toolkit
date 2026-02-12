import AppKit

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
