import Cocoa

// MARK: - Settings Window Controller

class SettingsWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 650),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false
        )
        window.title = "ZoomIt for Mac — Settings"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)

        let scrollView = NSScrollView(frame: window.contentView!.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        let view = SettingsView(frame: NSRect(x: 0, y: 0, width: 500, height: 800))
        scrollView.documentView = view
        window.contentView = scrollView
    }
}

// MARK: - Settings View

class SettingsView: NSView {
    var filePathField: NSTextField!


    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    func setupUI() {
        var y = frame.height - 30

        y = addTitle("ZoomIt for Mac", at: y)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        y = addSubtitle("Version \(version)", at: y)
        y -= 10

        // ── Zoom (macOS native) ──
        y = addSection("Zoom (macOS Built-In)", at: y)
        let zoomNote = NSTextField(wrappingLabelWithString:
            "ZoomIt for Mac uses macOS Accessibility Zoom for screen magnification.\nEnable it in System Settings → Accessibility → Zoom → \"Use keyboard shortcuts to zoom\"")
        zoomNote.font = .systemFont(ofSize: 11)
        zoomNote.textColor = .secondaryLabelColor
        zoomNote.frame = NSRect(x: 30, y: y - 36, width: 430, height: 36)
        addSubview(zoomNote)
        y -= 42

        let zoom: [(String, String)] = [
            ("⌥⌘8", "Toggle zoom on/off"),
            ("⌥⌘=", "Zoom in"),
            ("⌥⌘−", "Zoom out"),
            ("Ctrl+Scroll", "Smooth zoom in/out"),
        ]
        for (key, desc) in zoom { y = addShortcut(key, desc, at: y) }

        let setupBtn = NSButton(frame: NSRect(x: 30, y: y - 28, width: 200, height: 24))
        setupBtn.title = "Open Zoom Settings…"
        setupBtn.bezelStyle = .rounded
        setupBtn.target = self
        setupBtn.action = #selector(openZoomPrefs)
        addSubview(setupBtn)
        y -= 36

        // ── ZoomIt Shortcuts ──
        y = addSection("ZoomIt for Mac Shortcuts", at: y)
        let globals: [(String, String)] = [
            ("Ctrl+1", "Draw Mode"),
            ("Ctrl+2", "Break Timer"),
            ("Ctrl+3", "DemoType (next block)"),
            ("Esc", "Cancel / Exit current mode"),
        ]
        for (key, desc) in globals { y = addShortcut(key, desc, at: y) }
        y -= 10

        y = addSection("Draw Mode", at: y)
        let draw: [(String, String)] = [
            ("1", "Arrow tool (default)"),
            ("2", "Rectangle tool"),
            ("3", "Freeform pen tool"),
            ("R / B / G / P", "Red / Blue / Green / Purple"),
            ("Ctrl+Z", "Undo"),
            ("E", "Erase all"),
        ]
        for (key, desc) in draw { y = addShortcut(key, desc, at: y) }
        y -= 16

        // ── DemoType Configuration ──
        y = addSection("DemoType Configuration", at: y)
        y -= 4

        // File path label
        let fileLabel = NSTextField(labelWithString: "Text file with [start]...[end] blocks:")
        fileLabel.font = .systemFont(ofSize: 12, weight: .medium)
        fileLabel.frame = NSRect(x: 30, y: y - 18, width: 350, height: 16)
        addSubview(fileLabel)
        y -= 24

        // File path field + Browse button
        filePathField = NSTextField(frame: NSRect(x: 30, y: y - 24, width: 340, height: 24))
        filePathField.font = .systemFont(ofSize: 12)
        filePathField.placeholderString = "/path/to/demotype.txt"
        filePathField.isEditable = true
        filePathField.isBordered = true
        filePathField.bezelStyle = .roundedBezel
        filePathField.stringValue = UserDefaults.standard.string(forKey: "demoTypeFilePath") ?? ""
        filePathField.target = self
        filePathField.action = #selector(filePathChanged)
        addSubview(filePathField)

        let browseBtn = NSButton(frame: NSRect(x: 378, y: y - 24, width: 90, height: 24))
        browseBtn.title = "Browse…"
        browseBtn.bezelStyle = .rounded
        browseBtn.target = self
        browseBtn.action = #selector(browseFile)
        addSubview(browseBtn)
        y -= 34

        // File format hint
        y -= 6
        let hint = NSTextField(wrappingLabelWithString:
            "File format example:\n[start]\nYour first text block here\n[end]\n[start]\nSecond block\n[end]")
        hint.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        hint.textColor = .tertiaryLabelColor
        hint.frame = NSRect(x: 30, y: y - 90, width: 430, height: 90)
        addSubview(hint)
        y -= 100

        // Resize to fit
        self.frame = NSRect(x: 0, y: 0, width: frame.width, height: frame.height - y + 20)
    }

    // MARK: - Actions

    @objc func browseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.title = "Select DemoType text file"
        if panel.runModal() == .OK, let url = panel.url {
            filePathField.stringValue = url.path
            UserDefaults.standard.set(url.path, forKey: "demoTypeFilePath")
        }
    }

    @objc func filePathChanged() {
        UserDefaults.standard.set(filePathField.stringValue, forKey: "demoTypeFilePath")
    }

    @objc func openZoomPrefs() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?Zoom") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Layout Helpers

    @discardableResult
    func addTitle(_ text: String, at y: CGFloat) -> CGFloat {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.frame = NSRect(x: 20, y: y - 30, width: 400, height: 28)
        addSubview(label)
        return y - 36
    }

    @discardableResult
    func addSubtitle(_ text: String, at y: CGFloat) -> CGFloat {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: 20, y: y - 18, width: 400, height: 16)
        addSubview(label)
        return y - 22
    }

    @discardableResult
    func addSection(_ text: String, at y: CGFloat) -> CGFloat {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.frame = NSRect(x: 20, y: y - 24, width: 400, height: 22)
        addSubview(label)

        let sep = NSBox(frame: NSRect(x: 20, y: y - 28, width: 460, height: 1))
        sep.boxType = .separator
        addSubview(sep)
        return y - 34
    }

    @discardableResult
    func addShortcut(_ key: String, _ desc: String, at y: CGFloat) -> CGFloat {
        let keyLabel = NSTextField(labelWithString: key)
        keyLabel.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        keyLabel.textColor = .systemBlue
        keyLabel.frame = NSRect(x: 30, y: y - 18, width: 150, height: 16)
        addSubview(keyLabel)

        let descLabel = NSTextField(labelWithString: desc)
        descLabel.font = .systemFont(ofSize: 12, weight: .regular)
        descLabel.textColor = .secondaryLabelColor
        descLabel.frame = NSRect(x: 190, y: y - 18, width: 280, height: 16)
        addSubview(descLabel)

        return y - 20
    }
}
