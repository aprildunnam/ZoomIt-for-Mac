import Cocoa

// MARK: - Draw Overlay Controller
// Uses a TRANSPARENT window — no screenshot needed. You see your actual apps underneath.

class DrawOverlayController {
    var window: NSWindow?
    var drawView: DrawOverlayView?
    var onClose: (() -> Void)?
    var toolbarWindow: NSWindow?

    func show() {
        guard let screen = NSScreen.main else { return }

        let sf = screen.frame
        let win = KeyableWindow(contentRect: sf, styleMask: .borderless,
                                backing: .buffered, defer: false)
        win.level = .popUpMenu
        win.isOpaque = false           // TRANSPARENT — see through to apps
        win.hasShadow = false
        win.backgroundColor = .clear   // Fully clear background
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = DrawOverlayView(frame: sf)
        view.onEscape = { [weak self] in self?.close() }
        win.contentView = view

        self.window = win
        self.drawView = view

        showToolbar(on: screen)
        NSCursor.crosshair.push()
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        win.makeFirstResponder(view)
    }

    func showToolbar(on screen: NSScreen) {
        let tbW: CGFloat = 340
        let tbH: CGFloat = 48
        let tbFrame = NSRect(x: screen.frame.midX - tbW / 2,
                             y: screen.frame.maxY - tbH - 8,
                             width: tbW, height: tbH)

        let tbWin = KeyableWindow(contentRect: tbFrame, styleMask: .borderless,
                                  backing: .buffered, defer: false)
        tbWin.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
        tbWin.isOpaque = false
        tbWin.hasShadow = true
        tbWin.backgroundColor = .clear
        tbWin.isMovableByWindowBackground = true

        let tbView = DrawToolbarView(frame: NSRect(origin: .zero, size: tbFrame.size))
        tbView.drawView = drawView
        tbWin.contentView = tbView
        tbWin.orderFront(nil)
        self.toolbarWindow = tbWin
    }

    func close() {
        NSCursor.pop()
        toolbarWindow?.orderOut(nil); toolbarWindow = nil
        window?.orderOut(nil); window = nil
        drawView = nil
        onClose?()
    }
}

// MARK: - Draw Overlay View (transparent — draws on top of everything)

class DrawOverlayView: NSView {
    var lines: [DrawnLine] = []
    var currentLine: DrawnLine?
    var onEscape: (() -> Void)?

    // Default tool is arrow, colors: red/blue/green/purple
    var currentColor: NSColor = .red
    var penWidth: CGFloat = 3.0
    var currentTool: DrawnLine.DrawingTool = .arrow

    var shapeStart: CGPoint?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor  // Transparent!
    }

    required init?(coder: NSCoder) { fatalError() }
    override var acceptsFirstResponder: Bool { true }

    // MARK: - Rendering

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Background is CLEAR — you see your apps through the window
        NSColor.clear.set()
        bounds.fill(using: .copy)

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Draw completed elements
        for line in lines { DrawingRenderer.render(line, in: ctx) }

        // Draw current in-progress element
        if let current = currentLine { DrawingRenderer.render(current, in: ctx) }

        // HUD
        drawHUD()
    }

    private func drawHUD() {
        let toolName: String
        switch currentTool {
        case .arrow: toolName = "Arrow"
        case .rectangle: toolName = "Rectangle"
        case .pen: toolName = "Freeform"
        default: toolName = "Arrow"
        }

        let colorName = colorToName(currentColor)
        let text = "✏️ \(toolName) | \(colorName)  |  1: Arrow  2: Rect  3: Pen  |  R/B/G/P: color  |  ⌃Z: undo  |  Esc: exit"

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let bgRect = NSRect(x: bounds.midX - size.width/2 - 12, y: 16,
                            width: size.width + 24, height: size.height + 12)
        NSColor(white: 0, alpha: 0.7).setFill()
        NSBezierPath(roundedRect: bgRect, xRadius: 8, yRadius: 8).fill()
        (text as NSString).draw(at: NSPoint(x: bgRect.minX + 12, y: bgRect.minY + 6), withAttributes: attrs)
    }

    func colorToName(_ c: NSColor) -> String {
        if c == .red { return "Red" }
        if c == .systemBlue { return "Blue" }
        if c == .systemGreen { return "Green" }
        if c == .systemPurple { return "Purple" }
        return "Red"
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        shapeStart = loc

        switch currentTool {
        case .pen:
            currentLine = DrawnLine(color: currentColor, width: penWidth, points: [loc], tool: .pen)
        case .arrow, .rectangle:
            currentLine = DrawnLine(color: currentColor, width: penWidth, points: [loc, loc], tool: currentTool)
        default:
            currentLine = DrawnLine(color: currentColor, width: penWidth, points: [loc, loc], tool: .arrow)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        guard currentLine != nil else { return }

        switch currentLine!.tool {
        case .pen:
            currentLine?.points.append(loc)
        default:
            if let start = shapeStart {
                currentLine = DrawnLine(color: currentColor, width: penWidth,
                                        points: [start, loc], tool: currentLine!.tool)
            }
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let line = currentLine {
            lines.append(line)
            currentLine = nil
        }
        shapeStart = nil
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) {
        onEscape?()
    }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            penWidth = max(1, min(30, penWidth + event.scrollingDeltaY * 0.3))
            needsDisplay = true
        }
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        switch event.keyCode {
        case 53: onEscape?()  // Esc

        // Tool switching: 1=Arrow, 2=Rect, 3=Freeform
        case 18: currentTool = .arrow; needsDisplay = true
        case 19: currentTool = .rectangle; needsDisplay = true
        case 20: currentTool = .pen; needsDisplay = true

        // Colors
        case 15: currentColor = .red; needsDisplay = true
        case 11: currentColor = .systemBlue; needsDisplay = true
        case 5:  currentColor = .systemGreen; needsDisplay = true
        case 35: currentColor = .systemPurple; needsDisplay = true

        // Undo: Ctrl+Z
        case 6:
            if flags.contains(.control) && !lines.isEmpty {
                lines.removeLast(); needsDisplay = true
            }

        // Erase all: E
        case 14: lines.removeAll(); needsDisplay = true

        // Pen width: +/-
        case 24: penWidth = min(30, penWidth + 1); needsDisplay = true
        case 27: penWidth = max(1, penWidth - 1); needsDisplay = true

        default: break
        }
    }
}

// MARK: - Simplified Toolbar

class DrawToolbarView: NSView {
    weak var drawView: DrawOverlayView?
    var toolButtons: [NSButton] = []
    var colorButtons: [NSButton] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor(white: 0.12, alpha: 0.95).cgColor
        setupButtons()
    }

    required init?(coder: NSCoder) { fatalError() }

    func setupButtons() {
        let tools: [(String, String, DrawnLine.DrawingTool)] = [
            ("arrow.up.right", "Arrow (1)", .arrow),
            ("rectangle", "Rectangle (2)", .rectangle),
            ("scribble", "Freeform (3)", .pen),
        ]

        let colors: [(NSColor, String)] = [
            (.red, "Red (R)"),
            (.systemBlue, "Blue (B)"),
            (.systemGreen, "Green (G)"),
            (.systemPurple, "Purple (P)"),
        ]

        var x: CGFloat = 12

        for (i, (icon, tooltip, _)) in tools.enumerated() {
            let btn = NSButton(frame: NSRect(x: x, y: 8, width: 32, height: 32))
            btn.bezelStyle = .regularSquare
            btn.isBordered = false
            btn.image = NSImage(systemSymbolName: icon, accessibilityDescription: tooltip)
            btn.contentTintColor = i == 0 ? .systemYellow : .white
            btn.toolTip = tooltip
            btn.tag = i
            btn.target = self
            btn.action = #selector(toolSelected(_:))
            addSubview(btn)
            toolButtons.append(btn)
            x += 38
        }

        x += 8
        let sep = NSView(frame: NSRect(x: x, y: 10, width: 1, height: 28))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.3).cgColor
        addSubview(sep)
        x += 12

        for (i, (color, name)) in colors.enumerated() {
            let btn = NSButton(frame: NSRect(x: x, y: 10, width: 28, height: 28))
            btn.title = ""
            btn.bezelStyle = .regularSquare
            btn.isBordered = false
            btn.wantsLayer = true
            btn.layer?.backgroundColor = color.cgColor
            btn.layer?.cornerRadius = 14
            btn.layer?.borderWidth = i == 0 ? 3 : 2
            btn.layer?.borderColor = i == 0 ?
                NSColor.white.cgColor : NSColor.white.withAlphaComponent(0.4).cgColor
            btn.toolTip = name
            btn.tag = 100 + i
            btn.target = self
            btn.action = #selector(colorSelected(_:))
            addSubview(btn)
            colorButtons.append(btn)
            x += 34
        }
    }

    @objc func toolSelected(_ sender: NSButton) {
        let tools: [DrawnLine.DrawingTool] = [.arrow, .rectangle, .pen]
        guard sender.tag < tools.count else { return }
        drawView?.currentTool = tools[sender.tag]
        for btn in toolButtons {
            btn.contentTintColor = btn.tag == sender.tag ? .systemYellow : .white
        }
    }

    @objc func colorSelected(_ sender: NSButton) {
        let colors: [NSColor] = [.red, .systemBlue, .systemGreen, .systemPurple]
        let idx = sender.tag - 100
        guard idx >= 0 && idx < colors.count else { return }
        drawView?.currentColor = colors[idx]
        for btn in colorButtons {
            let isSelected = btn.tag == sender.tag
            btn.layer?.borderWidth = isSelected ? 3 : 2
            btn.layer?.borderColor = isSelected ?
                NSColor.white.cgColor : NSColor.white.withAlphaComponent(0.4).cgColor
        }
    }
}
