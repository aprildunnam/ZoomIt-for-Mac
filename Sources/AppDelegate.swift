import Cocoa
import Carbon

// MARK: - Global Carbon Hotkey Handler

// Carbon hotkeys work system-wide without Accessibility permission.
// This is a C-level callback so it must be a free function.

private func carbonHotkeyHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event else { return OSStatus(eventNotHandledErr) }

    var hotkeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        UInt32(kEventParamDirectObject),
        UInt32(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotkeyID
    )
    guard status == noErr else { return status }

    DispatchQueue.main.async {
        guard let delegate = NSApp.delegate as? AppDelegate else { return }
        switch hotkeyID.id {
        case 1: delegate.toggleDraw()
        case 2: delegate.toggleTimer()
        case 3: delegate.toggleDemoType()
        case 4: delegate.closeAll()  // Escape
        default: break
        }
    }

    return noErr
}

// MARK: - App Delegate (Menu Bar App)
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var drawController: DrawOverlayController?
    var timerController: BreakTimerController?
    var demoTypeController: DemoTypeController?
    var settingsWindowController: SettingsWindowController?

    var hotKeyRefs: [EventHotKeyRef?] = []
    var escapeMonitor: Any?
    var escapeHotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        registerCarbonHotkeys()
        registerEscapeFailsafe()
        showLaunchNotification()
    }

    // MARK: - Carbon Global Hotkeys (no Accessibility permission needed)
    func registerCarbonHotkeys() {
        // Install the Carbon event handler
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotkeyHandler,
            1,
            &eventType,
            nil,
            nil
        )

        // Register Ctrl+1, Ctrl+2, Ctrl+3, Ctrl+4
        // Carbon key codes: 1=18, 2=19, 3=20, 4=21
        // Carbon modifier: controlKey = 0x1000
        let signature = OSType(0x5A4D4954) // 'ZMIT'
        let hotkeys: [(id: UInt32, keyCode: UInt32)] = [
            (1, 18),  // Ctrl+1 → Draw
            (2, 19),  // Ctrl+2 → Timer
            (3, 20),  // Ctrl+3 → DemoType
        ]

        for hk in hotkeys {
            let hotkeyID = EventHotKeyID(signature: signature, id: hk.id)
            var hotkeyRef: EventHotKeyRef?
            let status = RegisterEventHotKey(
                hk.keyCode,
                UInt32(controlKey),
                hotkeyID,
                GetApplicationEventTarget(),
                0,
                &hotkeyRef
            )
            if status == noErr {
                hotKeyRefs.append(hotkeyRef)
            }
        }
    }

    // MARK: - Escape Failsafe (local monitor + Carbon hotkey)
    func registerEscapeFailsafe() {
        // Local Escape: when our overlay has focus
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                DispatchQueue.main.async { self?.closeAll() }
                return nil
            }
            return event
        }
    }

    /// Register a temporary Carbon Escape hotkey (global, no Accessibility needed).
    /// Call this when DemoType activates (target app has focus, not ZoomIt).
    func registerEscapeHotkey() {
        guard escapeHotKeyRef == nil else { return }
        let signature = OSType(0x5A4D4954) // 'ZMIT'
        let hotkeyID = EventHotKeyID(signature: signature, id: 4)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            53,  // Escape key code
            0,   // No modifier
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            escapeHotKeyRef = ref
        }
    }

    /// Unregister the temporary Escape hotkey so it doesn't swallow Escape globally.
    func unregisterEscapeHotkey() {
        if let ref = escapeHotKeyRef {
            UnregisterEventHotKey(ref)
            escapeHotKeyRef = nil
        }
    }

    // MARK: - Launch Toast Notification
    func showLaunchNotification() {
        guard let screen = NSScreen.main else { return }
        let w: CGFloat = 300
        let h: CGFloat = 64
        let x = screen.frame.maxX - w - 20
        let y = screen.frame.maxY - h - 40

        let win = NSWindow(contentRect: NSRect(x: x, y: y, width: w, height: h),
                           styleMask: .borderless, backing: .buffered, defer: false)
        win.level = .floating
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true

        let container = NSView(frame: NSRect(origin: .zero, size: NSSize(width: w, height: h)))
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.backgroundColor = NSColor(white: 0.15, alpha: 0.95).cgColor

        let icon = NSImageView(frame: NSRect(x: 14, y: 16, width: 32, height: 32))
        icon.image = NSImage(systemSymbolName: "pencil.tip.crop.circle.fill", accessibilityDescription: nil)
        icon.contentTintColor = .systemBlue
        container.addSubview(icon)

        let title = NSTextField(labelWithString: "ZoomIt for Mac is running")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .white
        title.frame = NSRect(x: 54, y: 34, width: 240, height: 20)
        container.addSubview(title)

        let sub = NSTextField(labelWithString: "⌥⌘8 zoom · ⌃1 draw · ⌃2 timer · ⌃3 type")
        sub.font = .systemFont(ofSize: 11, weight: .regular)
        sub.textColor = NSColor.white.withAlphaComponent(0.6)
        sub.frame = NSRect(x: 54, y: 14, width: 240, height: 16)
        container.addSubview(sub)

        win.contentView = container
        win.alphaValue = 0
        win.orderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in ctx.duration = 0.3; win.animator().alphaValue = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            NSAnimationContext.runAnimationGroup({ ctx in ctx.duration = 0.5; win.animator().alphaValue = 0 },
                                                completionHandler: { win.orderOut(nil) })
        }
    }

    // MARK: - Status Bar
    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pencil.tip.crop.circle.fill",
                                   accessibilityDescription: "ZoomIt for Mac")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        let menu = NSMenu()

        // Zoom section — uses macOS native Accessibility Zoom
        let zoomHeader = NSMenuItem(title: "── Zoom (macOS built-in) ──", action: nil, keyEquivalent: "")
        zoomHeader.isEnabled = false
        menu.addItem(zoomHeader)
        let z1 = NSMenuItem(title: "  Toggle Zoom       ⌥⌘8", action: nil, keyEquivalent: "")
        z1.isEnabled = false
        menu.addItem(z1)
        let z2 = NSMenuItem(title: "  Zoom In            ⌥⌘=", action: nil, keyEquivalent: "")
        z2.isEnabled = false
        menu.addItem(z2)
        let z3 = NSMenuItem(title: "  Zoom Out          ⌥⌘−", action: nil, keyEquivalent: "")
        z3.isEnabled = false
        menu.addItem(z3)
        let z4 = NSMenuItem(title: "  Smooth Zoom   ⌃Scroll", action: nil, keyEquivalent: "")
        z4.isEnabled = false
        menu.addItem(z4)
        menu.addItem(NSMenuItem(title: "  Enable Zoom in Settings…", action: #selector(openZoomSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        // ZoomIt features
        menu.addItem(NSMenuItem(title: "Draw Mode        ⌃1", action: #selector(toggleDraw), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Break Timer      ⌃2", action: #selector(toggleTimer), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "DemoType         ⌃3", action: #selector(toggleDemoType), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit ZoomIt for Mac", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    // MARK: - Close all overlays
    func closeAll() {
        drawController?.close()
        drawController = nil
        timerController?.close()
        timerController = nil
        demoTypeController?.close()
        demoTypeController = nil
        unregisterEscapeHotkey()
    }

    // MARK: - Actions
    @objc func toggleDraw() {
        if drawController != nil { drawController?.close(); drawController = nil; return }
        closeAll()
        drawController = DrawOverlayController()
        drawController?.onClose = { [weak self] in self?.drawController = nil }
        drawController?.show()
    }

    @objc func toggleTimer() {
        if timerController != nil { timerController?.close(); timerController = nil; return }
        closeAll()
        timerController = BreakTimerController()
        timerController?.onClose = { [weak self] in self?.timerController = nil }
        timerController?.show()
    }

    @objc func toggleDemoType() {
        // If already active, trigger the next block (don't create a new controller)
        if let controller = demoTypeController {
            controller.handleTrigger()
            return
        }
        // First press — create controller and start
        let controller = DemoTypeController()
        controller.onClose = { [weak self] in
            self?.unregisterEscapeHotkey()
            self?.demoTypeController = nil
        }
        demoTypeController = controller
        registerEscapeHotkey()  // Capture Escape globally while DemoType is active
        controller.show()
    }

    @objc func openZoomSettings() {
        // Open System Settings → Accessibility → Zoom
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?Zoom") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openSettings() {
        if settingsWindowController == nil { settingsWindowController = SettingsWindowController() }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func quitApp() { NSApp.terminate(nil) }
}
