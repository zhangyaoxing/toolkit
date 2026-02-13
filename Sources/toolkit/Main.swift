import AppKit

@main
struct toolkit {
    static func main() {
        // --- Launch logic ---
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate

        // Key point: Set app to not show in Dock (UIElement mode)
        app.setActivationPolicy(.accessory)

        app.run()
    }
}
