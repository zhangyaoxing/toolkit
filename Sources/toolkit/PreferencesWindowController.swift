import AppKit
import HotKey

@MainActor
class PreferencesWindowController: NSWindowController {
    
    private var contentStackView: NSStackView!
    private var scrollView: NSScrollView!
    private var screenConfigs: [(screen: NSScreen, keyPopUp: NSPopUpButton, modifierCheckboxes: [NSButton])] = []
    private var windowMoveModifierPopUp: NSPopUpButton!
    
    override init(window: NSWindow?) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "显示器快捷键设置"
        window.center()
        
        super.init(window: window)
        
        setupWindowFrame()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func showWindow(_ sender: Any?) {
        // 每次显示时刷新显示器列表
        refreshScreenList()
        super.showWindow(sender)
    }
    
    private func setupWindowFrame() {
        guard let window = window else { return }
        
        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        
        // 创建滚动视图
        scrollView = NSScrollView(frame: contentView.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        
        contentView.addSubview(scrollView)
        window.contentView = contentView
    }
    
    private func refreshScreenList() {
        // 清除旧的配置
        screenConfigs.removeAll()
        
        // 获取当前所有显示器
        let screens = NSScreen.screens
        
        // 动态计算所需高度
        // 说明文本: 25, 窗口移动配置: 60, 按钮: 30, 上下边距: 40, 间距: 20
        // 每个显示器配置: 100, 分隔线: 1
        let instructionHeight: CGFloat = 25
        let windowMoveConfigHeight: CGFloat = 60
        let buttonHeight: CGFloat = 30
        let margins: CGFloat = 40  // 上下各 20
        let spacing: CGFloat = 20
        let separatorHeight: CGFloat = 1
        
        var totalHeight = margins + instructionHeight + spacing + windowMoveConfigHeight + spacing + separatorHeight + spacing
        for index in 0..<screens.count {
            totalHeight += 100  // 配置视图高度
            if index < screens.count - 1 {
                totalHeight += spacing + separatorHeight + spacing
            } else {
                totalHeight += spacing
            }
        }
        totalHeight += buttonHeight + 10  // 按钮加一点额外间距
        
        // 创建新的文档视图
        let docView = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: totalHeight))
        
        // 主堆栈视图
        contentStackView = NSStackView()
        contentStackView.orientation = .vertical
        contentStackView.alignment = .left
        contentStackView.spacing = 20
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加说明文本
        let instructionLabel = NSTextField(labelWithString: "为每个显示器配置快捷键：")
        instructionLabel.font = .systemFont(ofSize: 13, weight: .medium)
        contentStackView.addArrangedSubview(instructionLabel)
        
        // 添加窗口移动修饰键配置
        let windowMoveConfigView = createWindowMoveConfigView()
        contentStackView.addArrangedSubview(windowMoveConfigView)
        
        // 添加分隔线
        let mainSeparator = NSBox()
        mainSeparator.boxType = .separator
        mainSeparator.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(mainSeparator)
        mainSeparator.widthAnchor.constraint(equalToConstant: 460).isActive = true
        
        for (index, screen) in screens.enumerated() {
            let configView = createScreenConfigView(screen: screen, index: index)
            contentStackView.addArrangedSubview(configView)
            
            // 添加分隔线（除了最后一个）
            if index < screens.count - 1 {
                let separator = NSBox()
                separator.boxType = .separator
                separator.translatesAutoresizingMaskIntoConstraints = false
                contentStackView.addArrangedSubview(separator)
                separator.widthAnchor.constraint(equalToConstant: 460).isActive = true
            }
        }
        
        // 添加保存按钮
        let buttonContainer = NSView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let saveButton = NSButton(title: "保存", target: self, action: #selector(saveConfiguration))
        saveButton.bezelStyle = .rounded
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(saveButton)
        
        let cancelButton = NSButton(title: "取消", target: self, action: #selector(closeWindow))
        cancelButton.bezelStyle = .rounded
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(cancelButton)
        
        NSLayoutConstraint.activate([
            saveButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            saveButton.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
            saveButton.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor),
            saveButton.widthAnchor.constraint(equalToConstant: 80),
            
            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -10),
            cancelButton.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 80),
            
            buttonContainer.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        contentStackView.addArrangedSubview(buttonContainer)
        
        docView.addSubview(contentStackView)
        
        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: docView.topAnchor, constant: 20),
            contentStackView.leadingAnchor.constraint(equalTo: docView.leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(equalTo: docView.trailingAnchor, constant: -20),
        ])
        
        scrollView.documentView = docView
        
        // 调整窗口大小以适应内容
        if let window = window {
            let windowWidth: CGFloat = 520
            let titleBarHeight: CGFloat = 28
            let windowHeight = totalHeight + titleBarHeight
            
            // 限制最大高度为屏幕的80%
            let maxHeight = (NSScreen.main?.visibleFrame.height ?? 800) * 0.8
            let finalHeight = min(windowHeight, maxHeight)
            
            let currentFrame = window.frame
            let newFrame = NSRect(
                x: currentFrame.origin.x,
                y: currentFrame.origin.y + currentFrame.height - finalHeight,
                width: windowWidth,
                height: finalHeight
            )
            window.setFrame(newFrame, display: true, animate: true)
            window.center()
        }
        
        // 加载已保存的配置
        loadConfiguration()
    }
    
    private func createWindowMoveConfigView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "窗口移动修饰键：")
        titleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        windowMoveModifierPopUp = NSPopUpButton()
        windowMoveModifierPopUp.translatesAutoresizingMaskIntoConstraints = false
        
        for modifier in WindowMoveModifier.allCases {
            windowMoveModifierPopUp.addItem(withTitle: modifier.displayName)
        }
        
        container.addSubview(windowMoveModifierPopUp)
        
        let hintLabel = NSTextField(labelWithString: "按住此键 + 快捷键将移动当前窗口到目标屏幕")
        hintLabel.font = .systemFont(ofSize: 10, weight: .regular)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hintLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            windowMoveModifierPopUp.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            windowMoveModifierPopUp.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 10),
            windowMoveModifierPopUp.widthAnchor.constraint(equalToConstant: 150),
            
            hintLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            hintLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hintLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            container.heightAnchor.constraint(equalToConstant: 60),
            container.widthAnchor.constraint(equalToConstant: 460)
        ])
        
        return container
    }
    
    private func createScreenConfigView(screen: NSScreen, index: Int) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // 显示器名称
        let nameLabel = NSTextField(labelWithString: screen.displayName)
        nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)
        
        // 快捷键配置
        let keyLabel = NSTextField(labelWithString: "按键:")
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(keyLabel)
        
        let keyPopUp = NSPopUpButton()
        keyPopUp.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加数字键和字母键选项
        let keys: [(String, Key)] = [
            ("1", .one), ("2", .two), ("3", .three), ("4", .four), ("5", .five),
            ("6", .six), ("7", .seven), ("8", .eight), ("9", .nine), ("0", .zero),
            ("A", .a), ("B", .b), ("C", .c), ("D", .d), ("E", .e), ("F", .f),
            ("G", .g), ("H", .h), ("I", .i), ("J", .j), ("K", .k), ("L", .l),
            ("M", .m), ("N", .n), ("O", .o), ("P", .p), ("Q", .q), ("R", .r),
            ("S", .s), ("T", .t), ("U", .u), ("V", .v), ("W", .w), ("X", .x),
            ("Y", .y), ("Z", .z)
        ]
        
        for (title, _) in keys {
            keyPopUp.addItem(withTitle: title)
        }
        
        // 默认选择数字键
        if index < 9 {
            keyPopUp.selectItem(at: index)
        }
        
        container.addSubview(keyPopUp)
        
        // 修饰键
        let modifierLabel = NSTextField(labelWithString: "修饰键:")
        modifierLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(modifierLabel)
        
        let commandCheckbox = NSButton(checkboxWithTitle: "⌘ Command", target: nil, action: nil)
        commandCheckbox.state = .on
        commandCheckbox.translatesAutoresizingMaskIntoConstraints = false
        
        let shiftCheckbox = NSButton(checkboxWithTitle: "⇧ Shift", target: nil, action: nil)
        shiftCheckbox.state = .on
        shiftCheckbox.translatesAutoresizingMaskIntoConstraints = false
        
        let optionCheckbox = NSButton(checkboxWithTitle: "⌥ Option", target: nil, action: nil)
        optionCheckbox.translatesAutoresizingMaskIntoConstraints = false
        
        let controlCheckbox = NSButton(checkboxWithTitle: "⌃ Control", target: nil, action: nil)
        controlCheckbox.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(commandCheckbox)
        container.addSubview(shiftCheckbox)
        container.addSubview(optionCheckbox)
        container.addSubview(controlCheckbox)
        
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: container.topAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            keyLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 10),
            keyLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            keyLabel.widthAnchor.constraint(equalToConstant: 60),
            
            keyPopUp.centerYAnchor.constraint(equalTo: keyLabel.centerYAnchor),
            keyPopUp.leadingAnchor.constraint(equalTo: keyLabel.trailingAnchor, constant: 5),
            keyPopUp.widthAnchor.constraint(equalToConstant: 100),
            
            modifierLabel.topAnchor.constraint(equalTo: keyLabel.bottomAnchor, constant: 10),
            modifierLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            commandCheckbox.topAnchor.constraint(equalTo: modifierLabel.bottomAnchor, constant: 5),
            commandCheckbox.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            
            shiftCheckbox.centerYAnchor.constraint(equalTo: commandCheckbox.centerYAnchor),
            shiftCheckbox.leadingAnchor.constraint(equalTo: commandCheckbox.trailingAnchor, constant: 10),
            
            optionCheckbox.centerYAnchor.constraint(equalTo: commandCheckbox.centerYAnchor),
            optionCheckbox.leadingAnchor.constraint(equalTo: shiftCheckbox.trailingAnchor, constant: 10),
            
            controlCheckbox.centerYAnchor.constraint(equalTo: commandCheckbox.centerYAnchor),
            controlCheckbox.leadingAnchor.constraint(equalTo: optionCheckbox.trailingAnchor, constant: 10),
            
            container.heightAnchor.constraint(equalToConstant: 100),
            container.widthAnchor.constraint(equalToConstant: 460)
        ])
        
        screenConfigs.append((screen, keyPopUp, [commandCheckbox, shiftCheckbox, optionCheckbox, controlCheckbox]))
        
        return container
    }
    
    private func loadConfiguration() {
        // 加载窗口移动修饰键配置
        let savedModifier = AppPreferences.windowMoveModifier
        if let index = WindowMoveModifier.allCases.firstIndex(of: savedModifier) {
            windowMoveModifierPopUp.selectItem(at: index)
        }
        
        // 加载显示器快捷键配置
        guard let savedData = UserDefaults.standard.data(forKey: "ScreenHotKeyConfigs"),
              let configs = try? JSONDecoder().decode([ScreenHotKeyConfig].self, from: savedData) else {
            return
        }
        
        // 根据保存的配置更新 UI
        for config in configs {
            if let index = screenConfigs.firstIndex(where: { $0.screen.displayID == config.displayID }) {
                let (_, keyPopUp, modifierCheckboxes) = screenConfigs[index]
                
                // 设置按键（这里简化处理，实际可能需要更复杂的映射）
                if config.keyCode >= 0 && config.keyCode < keyPopUp.numberOfItems {
                    keyPopUp.selectItem(at: config.keyCode)
                }
                
                // 设置修饰键
                let flags = config.hotKeyModifiers
                modifierCheckboxes[0].state = flags.contains(.command) ? .on : .off
                modifierCheckboxes[1].state = flags.contains(.shift) ? .on : .off
                modifierCheckboxes[2].state = flags.contains(.option) ? .on : .off
                modifierCheckboxes[3].state = flags.contains(.control) ? .on : .off
            }
        }
    }
    
    @objc private func saveConfiguration() {
        // 保存窗口移动修饰键配置
        let selectedIndex = windowMoveModifierPopUp.indexOfSelectedItem
        if selectedIndex >= 0 && selectedIndex < WindowMoveModifier.allCases.count {
            AppPreferences.windowMoveModifier = WindowMoveModifier.allCases[selectedIndex]
        }
        
        // 保存显示器快捷键配置
        var configs: [ScreenHotKeyConfig] = []
        
        for (screen, keyPopUp, modifierCheckboxes) in screenConfigs {
            let keyCode = keyPopUp.indexOfSelectedItem
            
            var modifierFlags: NSEvent.ModifierFlags = []
            if modifierCheckboxes[0].state == .on { modifierFlags.insert(.command) }
            if modifierCheckboxes[1].state == .on { modifierFlags.insert(.shift) }
            if modifierCheckboxes[2].state == .on { modifierFlags.insert(.option) }
            if modifierCheckboxes[3].state == .on { modifierFlags.insert(.control) }
            
            let config = ScreenHotKeyConfig(
                displayID: screen.displayID,
                keyCode: keyCode,
                modifiers: Int(modifierFlags.rawValue)
            )
            configs.append(config)
        }
        
        if let encoded = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(encoded, forKey: "ScreenHotKeyConfigs")
            
            // 通知 AppDelegate 重新加载快捷键
            NotificationCenter.default.post(name: NSNotification.Name("ReloadHotKeys"), object: nil)
            
            let alert = NSAlert()
            alert.messageText = "保存成功"
            alert.informativeText = "快捷键配置已保存！"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
        
        close()
    }
    
    @objc private func closeWindow() {
        close()
    }
}
