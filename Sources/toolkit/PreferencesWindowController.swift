import AppKit
import HotKey

@MainActor
class PreferencesWindowController: NSWindowController {
    
    private var contentStackView: NSStackView!
    private var scrollView: NSScrollView!
    private var screenConfigs: [(screen: NSScreen, keyPopUp: NSPopUpButton, modifierCheckboxes: [NSButton])] = []
    private var windowMoveModifierPopUp: NSPopUpButton!
    private var saveButton: NSButton!
    private var isDirty: Bool = false {
        didSet {
            saveButton?.isEnabled = isDirty
        }
    }
    
    override init(window: NSWindow?) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Display Hotkey Settings"
        window.center()
        
        super.init(window: window)
        
        setupWindowFrame()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func showWindow(_ sender: Any?) {
        // Refresh display list each time the window is shown
        refreshScreenList()
        super.showWindow(sender)
    }
    
    private func setupWindowFrame() {
        guard let window = window else { return }
        
        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        
        // Create scroll view
        scrollView = NSScrollView(frame: contentView.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        
        contentView.addSubview(scrollView)
        window.contentView = contentView
    }
    
    private func refreshScreenList() {
        // Clear old configuration
        screenConfigs.removeAll()
        
        // Get all current displays
        let screens = NSScreen.screens
        
        // Dynamically calculate required height
        // Instruction text: 25, Window move config: 72, Buttons: 30, Top/bottom margins: 40, Spacing: 20
        // Each display config: 100, Separator: 1
        let instructionHeight: CGFloat = 25
        let windowMoveConfigHeight: CGFloat = 72
        let buttonHeight: CGFloat = 30
        let margins: CGFloat = 40  // 20 each for top and bottom
        let spacing: CGFloat = 20
        let separatorHeight: CGFloat = 1
        
        var totalHeight = margins + instructionHeight + spacing + windowMoveConfigHeight + spacing + separatorHeight + spacing
        for index in 0..<screens.count {
            totalHeight += 100  // Config view height
            if index < screens.count - 1 {
                totalHeight += spacing + separatorHeight + spacing
            } else {
                totalHeight += spacing
            }
        }
        totalHeight += buttonHeight + 10  // Buttons with a bit of extra spacing
        
        // Create new document view
        let docView = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: totalHeight))
        
        // Main stack view
        contentStackView = NSStackView()
        contentStackView.orientation = .vertical
        contentStackView.alignment = .left
        contentStackView.spacing = 20
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add instruction text
        let instructionLabel = NSTextField(labelWithString: "Configure hotkeys for each display:")
        instructionLabel.font = .systemFont(ofSize: 13, weight: .medium)
        contentStackView.addArrangedSubview(instructionLabel)
        
        // Add window move modifier configuration
        let windowMoveConfigView = createWindowMoveConfigView()
        contentStackView.addArrangedSubview(windowMoveConfigView)
        
        // Add separator
        let mainSeparator = NSBox()
        mainSeparator.boxType = .separator
        mainSeparator.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.addArrangedSubview(mainSeparator)
        mainSeparator.widthAnchor.constraint(equalToConstant: 460).isActive = true
        
        for (index, screen) in screens.enumerated() {
            let configView = createScreenConfigView(screen: screen, index: index)
            contentStackView.addArrangedSubview(configView)
            
            // Add separator (except for the last one)
            if index < screens.count - 1 {
                let separator = NSBox()
                separator.boxType = .separator
                separator.translatesAutoresizingMaskIntoConstraints = false
                contentStackView.addArrangedSubview(separator)
                separator.widthAnchor.constraint(equalToConstant: 460).isActive = true
            }
        }
        
        // Add save button
        let buttonContainer = NSView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        
        saveButton = NSButton(title: "Save", target: self, action: #selector(saveConfiguration))
        saveButton.bezelStyle = .rounded
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.isEnabled = false
        buttonContainer.addSubview(saveButton)
        
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(closeWindow))
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
        
        // Adjust window size to fit content
        if let window = window {
            let windowWidth: CGFloat = 520
            let titleBarHeight: CGFloat = 28
            let windowHeight = totalHeight + titleBarHeight
            
            // Limit maximum height to 80% of screen height
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
        
        // Load saved configuration
        loadConfiguration()
    }
    
    private func createWindowMoveConfigView() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = NSTextField(labelWithString: "Window Move Modifier:")
        titleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        
        windowMoveModifierPopUp = NSPopUpButton()
        windowMoveModifierPopUp.translatesAutoresizingMaskIntoConstraints = false
        windowMoveModifierPopUp.target = self
        windowMoveModifierPopUp.action = #selector(configurationChanged)
        
        for modifier in WindowMoveModifier.allCases {
            windowMoveModifierPopUp.addItem(withTitle: modifier.displayName)
        }
        
        container.addSubview(windowMoveModifierPopUp)
        
        let hintLabel = NSTextField(labelWithString: "Hold this key + hotkey to move current window to target screen")
        hintLabel.font = .systemFont(ofSize: 10, weight: .regular)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hintLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: 20),
            
            windowMoveModifierPopUp.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            windowMoveModifierPopUp.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            windowMoveModifierPopUp.widthAnchor.constraint(equalToConstant: 150),
            
            hintLabel.topAnchor.constraint(equalTo: windowMoveModifierPopUp.bottomAnchor, constant: 6),
            hintLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hintLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            container.heightAnchor.constraint(equalToConstant: 72),
            container.widthAnchor.constraint(equalToConstant: 460)
        ])
        
        return container
    }
    
    private func createScreenConfigView(screen: NSScreen, index: Int) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Display name
        let nameLabel = NSTextField(labelWithString: screen.displayName)
        nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)
        
        // Hotkey configuration
        let keyLabel = NSTextField(labelWithString: "Key:")
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(keyLabel)
        
        let keyPopUp = NSPopUpButton()
        keyPopUp.translatesAutoresizingMaskIntoConstraints = false
        keyPopUp.target = self
        keyPopUp.action = #selector(configurationChanged)
        
        // Add number and letter key options
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
        
        // Default to selecting a number key
        if index < 9 {
            keyPopUp.selectItem(at: index)
        }
        
        container.addSubview(keyPopUp)
        
        // Modifiers
        let modifierLabel = NSTextField(labelWithString: "Modifiers:")
        modifierLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(modifierLabel)
        
        let commandCheckbox = NSButton(checkboxWithTitle: "⌘ Command", target: self, action: #selector(configurationChanged))
        commandCheckbox.state = .on
        commandCheckbox.translatesAutoresizingMaskIntoConstraints = false
        
        let shiftCheckbox = NSButton(checkboxWithTitle: "⇧ Shift", target: self, action: #selector(configurationChanged))
        shiftCheckbox.state = .on
        shiftCheckbox.translatesAutoresizingMaskIntoConstraints = false
        
        let optionCheckbox = NSButton(checkboxWithTitle: "⌥ Option", target: self, action: #selector(configurationChanged))
        optionCheckbox.translatesAutoresizingMaskIntoConstraints = false
        
        let controlCheckbox = NSButton(checkboxWithTitle: "⌃ Control", target: self, action: #selector(configurationChanged))
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
        // Load window move modifier configuration
        let savedModifier = AppPreferences.windowMoveModifier
        if let index = WindowMoveModifier.allCases.firstIndex(of: savedModifier) {
            windowMoveModifierPopUp.selectItem(at: index)
        }
        
        // Load display hotkey configuration
        guard let savedData = UserDefaults.standard.data(forKey: "ScreenHotKeyConfigs"),
              let configs = try? JSONDecoder().decode([ScreenHotKeyConfig].self, from: savedData) else {
            return
        }
        
        // Update UI based on saved configuration
        for config in configs {
            if let index = screenConfigs.firstIndex(where: { $0.screen.displayID == config.displayID }) {
                let (_, keyPopUp, modifierCheckboxes) = screenConfigs[index]
                
                // Set key (simplified handling, actual implementation may need more complex mapping)
                if config.keyCode >= 0 && config.keyCode < keyPopUp.numberOfItems {
                    keyPopUp.selectItem(at: config.keyCode)
                }
                
                // Set modifier keys
                let flags = config.hotKeyModifiers
                modifierCheckboxes[0].state = flags.contains(.command) ? .on : .off
                modifierCheckboxes[1].state = flags.contains(.shift) ? .on : .off
                modifierCheckboxes[2].state = flags.contains(.option) ? .on : .off
                modifierCheckboxes[3].state = flags.contains(.control) ? .on : .off
            }
        }
    }
    
    @objc private func saveConfiguration() {
        // Save window move modifier configuration
        let selectedIndex = windowMoveModifierPopUp.indexOfSelectedItem
        if selectedIndex >= 0 && selectedIndex < WindowMoveModifier.allCases.count {
            AppPreferences.windowMoveModifier = WindowMoveModifier.allCases[selectedIndex]
        }
        
        // Save display hotkey configuration
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
            
            // Notify AppDelegate to reload hotkeys
            NotificationCenter.default.post(name: NSNotification.Name("ReloadHotKeys"), object: nil)
            
            // Mark as unmodified
            isDirty = false
        }
        
        close()
    }
    
    @objc private func closeWindow() {
        close()
    }
    
    @objc private func configurationChanged() {
        isDirty = true
    }
}
