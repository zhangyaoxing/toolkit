import AppKit

@MainActor
class CursorMover {
    static func highlight(at point: CGPoint) {
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

    static var currentScreen: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }

    static func smoothMove(
        to targetPoint: CGPoint, duration: TimeInterval = 0.15,
        completion: @escaping @Sendable () -> Void = {}
    ) {
        let startPoint = NSEvent.mouseLocation
        // NSEvent.mouseLocation is in screen coordinates (bottom-left origin)
        // CGWarpMouseCursorPosition uses display coordinates (top-left origin usually, but let's check mapping)
        // Actually CGWarpMouseCursorPosition uses global display coordinates where (0,0) is top-left of main screen.
        // NSEvent.mouseLocation (0,0) is bottom-left of zero-screen.

        // Let's stick to converting everything to the CGWarpMouseCursorPosition coordinate system (Top-Left origin) for the interpolation

        guard let mainScreenHeight = NSScreen.screens.first?.frame.height else { return }

        let startWebPos = CGPoint(x: startPoint.x, y: mainScreenHeight - startPoint.y)
        // targetPoint passed in here is expected to be in CG coordinates (Top-Left 0,0) as it was used in AppDelegate for CGWarpMouseCursorPosition

        let startTime = Date()

        // Use a timer for animation
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed >= duration {
                // Final position update
                CGWarpMouseCursorPosition(targetPoint)

                // If dragging, post final drag event
                if NSEvent.pressedMouseButtons & 1 != 0 {
                    if let event = CGEvent(
                        mouseEventSource: nil, mouseType: .leftMouseDragged,
                        mouseCursorPosition: targetPoint, mouseButton: .left)
                    {
                        event.post(tap: .cghidEventTap)
                    }
                }

                timer.invalidate()
                completion()
                return
            }

            // Ease out cubic
            let t = CGFloat(elapsed / duration)
            let easeT = 1 - pow(1 - t, 3)

            let currentX = startWebPos.x + (targetPoint.x - startWebPos.x) * easeT
            let currentY = startWebPos.y + (targetPoint.y - startWebPos.y) * easeT
            let currentPoint = CGPoint(x: currentX, y: currentY)

            // Always warp for visual update (works without Accessibility permissions)
            CGWarpMouseCursorPosition(currentPoint)

            // If dragging, post drag event (requires Accessibility permissions) to move window
            if NSEvent.pressedMouseButtons & 1 != 0 {
                if let event = CGEvent(
                    mouseEventSource: nil, mouseType: .leftMouseDragged,
                    mouseCursorPosition: currentPoint, mouseButton: .left)
                {
                    event.post(tap: .cghidEventTap)
                }
            }
        }
    }

    static func focusWindowAtCursor() {
        // 1. 获取当前鼠标位置 (CG 坐标系)
        let mouseLocation = NSEvent.mouseLocation
        // 转换到屏幕坐标 (Y 轴翻转，因为 AX 使用的是屏幕坐标)
        let screenHeight = NSScreen.screens[0].frame.height
        let point = CGPoint(x: mouseLocation.x, y: screenHeight - mouseLocation.y)

        // 2. 获取坐标下的系统 UI 元素
        let systemWideElement = AXUIElementCreateSystemWide()
        var element: AXUIElement?

        // 探测该点下的元素
        let result = AXUIElementCopyElementAtPosition(
            systemWideElement, Float(mouseLocation.x), Float(point.y), &element)

        if result == .success, let targetElement = element {
            var pid: pid_t = 0
            AXUIElementGetPid(targetElement, &pid)

            // 3. 找到对应的应用并激活
            if let app = NSRunningApplication(processIdentifier: pid) {
                app.activate(options: [.activateIgnoringOtherApps])
                print("已聚焦窗口: \(app.localizedName ?? "未知")")
            }
        }
    }
}
