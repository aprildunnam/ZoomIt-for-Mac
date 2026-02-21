import Cocoa

// MARK: - Break Timer Controller

class BreakTimerController {
    var window: NSWindow?
    var timerView: BreakTimerView?
    var onClose: (() -> Void)?

    deinit { close() }

    func show() {
        let duration = promptForDuration()
        guard duration > 0 else { return }

        guard let screen = NSScreen.main else { return }
        let sf = screen.frame

        let win = KeyableWindow(contentRect: sf, styleMask: .borderless,
                                backing: .buffered, defer: false)
        win.level = .popUpMenu
        win.isOpaque = true
        win.hasShadow = false
        win.backgroundColor = .black
        win.ignoresMouseEvents = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let view = BreakTimerView(frame: sf, duration: duration)
        view.onEscape = { [weak self] in self?.close() }
        view.onComplete = { [weak self] in self?.close() }
        win.contentView = view

        self.window = win
        self.timerView = view
        view.startTimer()
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        win.makeFirstResponder(view)
    }

    func promptForDuration() -> TimeInterval {
        let alert = NSAlert()
        alert.messageText = "Break Timer"
        alert.informativeText = "Enter duration in minutes:"
        alert.addButton(withTitle: "Start")
        alert.addButton(withTitle: "Cancel")

        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
        tf.stringValue = "5"
        alert.accessoryView = tf
        alert.window.initialFirstResponder = tf

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            return max(0.1, Double(tf.stringValue) ?? 5) * 60
        }
        return 0
    }

    func close() {
        timerView?.stopTimer()
        window?.orderOut(nil); window = nil; timerView = nil
        onClose?()
    }
}

// MARK: - Break Timer View

class BreakTimerView: NSView {
    var totalDuration: TimeInterval
    var remainingTime: TimeInterval
    var timer: Timer?
    var onEscape: (() -> Void)?
    var onComplete: (() -> Void)?

    var bgColor = NSColor(red: 0.08, green: 0.08, blue: 0.15, alpha: 1.0)

    init(frame: NSRect, duration: TimeInterval) {
        self.totalDuration = duration
        self.remainingTime = duration
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }
    override var acceptsFirstResponder: Bool { true }

    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.remainingTime -= 0.05
            if self.remainingTime <= 0 {
                self.remainingTime = 0
                self.stopTimer()
                self.needsDisplay = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { self.onComplete?() }
            }
            self.needsDisplay = true
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        bgColor.setFill()
        bounds.fill()

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let ringR: CGFloat = min(bounds.width, bounds.height) * 0.25
        let ringW: CGFloat = 12

        // Background ring
        let bgRing = NSBezierPath()
        bgRing.appendArc(withCenter: center, radius: ringR, startAngle: 0, endAngle: 360)
        bgRing.lineWidth = ringW
        NSColor.white.withAlphaComponent(0.15).setStroke()
        bgRing.stroke()

        // Progress ring
        let progress = CGFloat(remainingTime / totalDuration)
        let startA: CGFloat = 90
        let endA: CGFloat = startA - (360 * progress)

        let pRing = NSBezierPath()
        pRing.appendArc(withCenter: center, radius: ringR,
                        startAngle: startA, endAngle: endA, clockwise: true)
        pRing.lineWidth = ringW
        pRing.lineCapStyle = .round

        let color: NSColor = progress > 0.5 ? .systemBlue : (progress > 0.2 ? .systemYellow : .systemRed)
        color.setStroke()
        pRing.stroke()

        // Time display
        let mins = Int(remainingTime) / 60
        let secs = Int(remainingTime) % 60
        let timeStr = String(format: "%d:%02d", mins, secs)
        let timeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 96, weight: .thin),
            .foregroundColor: NSColor.white
        ]
        let ts = (timeStr as NSString).size(withAttributes: timeAttrs)
        (timeStr as NSString).draw(
            at: CGPoint(x: center.x - ts.width/2, y: center.y - ts.height/2),
            withAttributes: timeAttrs)

        // Label
        let label = remainingTime <= 0 ? "TIME'S UP!" : "BREAK"
        let lAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .light),
            .foregroundColor: NSColor.white.withAlphaComponent(0.6)
        ]
        let ls = (label as NSString).size(withAttributes: lAttrs)
        (label as NSString).draw(
            at: CGPoint(x: center.x - ls.width/2, y: center.y + ringR + 30),
            withAttributes: lAttrs)

        // Hint
        let hint = "Press Esc to dismiss  |  Ctrl+↑↓ to adjust time"
        let hAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor.white.withAlphaComponent(0.4)
        ]
        let hs = (hint as NSString).size(withAttributes: hAttrs)
        (hint as NSString).draw(
            at: CGPoint(x: center.x - hs.width/2, y: 40),
            withAttributes: hAttrs)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch event.keyCode {
        case 53: onEscape?()  // Esc
        case 126: // Up arrow - increase time (Ctrl+Up like ZoomIt)
            if flags.contains(.control) { remainingTime += 60; totalDuration += 60; needsDisplay = true }
        case 125: // Down arrow - decrease time
            if flags.contains(.control) { remainingTime = max(0, remainingTime - 60); totalDuration = max(60, totalDuration); needsDisplay = true }
        default: break
        }
    }
}
