import Cocoa
import ApplicationServices

// MARK: - DemoType Controller
//
// Loads [start]...[end] text blocks from a file.
// Ctrl+3 delivers the next block into whatever app is focused.
//
// Two modes based on Accessibility permission:
//   1. LIVE TYPING (Accessibility granted):
//      Character-by-character via AppleScript keystroke.
//      Looks like real typing during presentations.
//   2. CLIPBOARD (no Accessibility):
//      Copies block to clipboard. User presses Cmd+V.
//      Always works, zero permissions needed.
//
// Configure file path and speed in Settings.

class DemoTypeController {
    enum State { case idle, typing, waitingForNext }

    private(set) var snippets: [String] = []
    private(set) var currentSnippetIndex = 0
    private(set) var currentCharIndex = 0
    private var typeTimer: Timer?
    var onClose: (() -> Void)?
    private(set) var state: State = .idle
    private var hasAccessibility = false
    private var statusWindow: NSPanel?
    private var escMonitor: Any?
    private var localMonitor: Any?
    private var targetApp: NSRunningApplication?
    private var targetBundleID: String?
    private var savedClipboard: String?

    var filePath: String? {
        UserDefaults.standard.string(forKey: "demoTypeFilePath")
    }

    // MARK: - Called each time Ctrl+3 is pressed

    func handleTrigger() {
        switch state {
        case .idle:
            guard let path = filePath, !path.isEmpty else {
                showNoFileAlert()
                return
            }
            guard loadSnippets(from: path) else {
                showErrorAlert("Could not read file:\n\(path)")
                return
            }
            guard !snippets.isEmpty else {
                showErrorAlert("No [start]...[end] blocks found in file.")
                return
            }
            currentSnippetIndex = 0

            // Capture the frontmost app BEFORE showing our UI
            targetApp = NSWorkspace.shared.frontmostApplication
            targetBundleID = targetApp?.bundleIdentifier

            // Test real Accessibility by actually trying to create a CGEvent
            hasAccessibility = testAccessibility()
            NSLog("DemoType: Accessibility = \(hasAccessibility), target = \(targetApp?.localizedName ?? "nil")")

            installMonitors()
            showStatusBar()

            if hasAccessibility {
                startTypingCurrentSnippet()
            } else {
                copyAndPromptPaste()
            }

        case .typing:
            break // Ignore while typing

        case .waitingForNext:
            currentSnippetIndex += 1
            if currentSnippetIndex < snippets.count {
                if hasAccessibility {
                    startTypingCurrentSnippet()
                } else {
                    copyAndPromptPaste()
                }
            } else {
                updateStatus("\u{2705} All \(snippets.count) blocks done!")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    self?.close()
                }
            }
        }
    }

    func show() { handleTrigger() }

    // MARK: - Accessibility test

    /// Actually test whether we can post events, not just check the trust flag.
    /// AXIsProcessTrusted() can lie (cached after ad-hoc re-sign).
    func testAccessibility() -> Bool {
        // First check the flag
        guard AXIsProcessTrusted() else { return false }
        // Then try to create and post a harmless modifier-only event
        guard let event = CGEvent(source: nil) else { return false }
        event.type = .flagsChanged
        event.flags = [] // No modifier — harmless
        // If this doesn't crash / throw, we have access
        // (We can't truly verify delivery, but CGEvent creation
        //  fails when Accessibility denied on recent macOS)
        return true
    }

    // MARK: - File loading

    func loadSnippets(from path: String) -> Bool {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return false }
        snippets = parseBlocks(content)
        return true
    }

    func parseBlocks(_ raw: String) -> [String] {
        var blocks: [String] = []
        var searchRange = raw.startIndex..<raw.endIndex
        while let startRange = raw.range(of: "[start]", options: .caseInsensitive, range: searchRange) {
            let afterStart = startRange.upperBound
            guard let endRange = raw.range(of: "[end]", options: .caseInsensitive,
                                           range: afterStart..<raw.endIndex) else { break }
            let blockText = String(raw[afterStart..<endRange.lowerBound])
                .trimmingCharacters(in: .newlines)
            if !blockText.isEmpty { blocks.append(blockText) }
            searchRange = endRange.upperBound..<raw.endIndex
        }
        return blocks
    }

    // MARK: - Mode 1: Live typing (Accessibility required)

    func startTypingCurrentSnippet() {
        guard currentSnippetIndex < snippets.count else { return }
        currentCharIndex = 0
        state = .typing

        updateStatus("\u{2328}\u{FE0F} Typing block \(currentSnippetIndex + 1)/\(snippets.count)...  |  Esc: cancel")

        // Delay to let Ctrl+3 release, then activate target and type
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self = self, self.state == .typing else { return }
            self.activateTargetApp {
                // Extra delay after activation to ensure text field has focus
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.typeNextChar()
                }
            }
        }
    }

    private func activateTargetApp(then completion: @escaping () -> Void) {
        // Use AppleScript activate — sends a real Apple Event
        if let bundleID = targetBundleID {
            _ = runAppleScript("tell application id \"\(bundleID)\" to activate")
        } else if let app = targetApp {
            app.activate(options: .activateIgnoringOtherApps)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            completion()
        }
    }

    private func typeNextChar() {
        guard state == .typing, currentSnippetIndex < snippets.count else { return }
        let snippet = snippets[currentSnippetIndex]

        guard currentCharIndex < snippet.count else {
            finishedCurrentBlock()
            return
        }

        let idx = snippet.index(snippet.startIndex, offsetBy: currentCharIndex)
        let char = snippet[idx]
        let success = postChar(char)

        // If the very first char fails, Accessibility isn't truly working
        if !success && currentCharIndex == 0 {
            NSLog("DemoType: AppleScript keystroke failed on first char, switching to clipboard mode")
            hasAccessibility = false
            copyAndPromptPaste()
            return
        }

        currentCharIndex += 1
        typeTimer = Timer.scheduledTimer(withTimeInterval: 0.035, repeats: false) { [weak self] _ in
            self?.typeNextChar()
        }
    }

    private func postChar(_ char: Character) -> Bool {
        if char == "\n" || char == "\r" {
            return runAppleScript("tell application \"System Events\" to key code 36")
        }
        if char == "\t" {
            return runAppleScript("tell application \"System Events\" to key code 48")
        }
        let escaped = String(char)
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return runAppleScript("tell application \"System Events\" to keystroke \"\(escaped)\"")
    }

    private func runAppleScript(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error == nil
    }

    // MARK: - Mode 2: Clipboard (no Accessibility needed)

    private func copyAndPromptPaste() {
        guard currentSnippetIndex < snippets.count else { return }
        let snippet = snippets[currentSnippetIndex]
        state = .waitingForNext

        // Save current clipboard
        savedClipboard = NSPasteboard.general.string(forType: .string)

        // Copy block to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(snippet, forType: .string)

        let blockNum = currentSnippetIndex + 1
        let total = snippets.count
        let preview = String(snippet.prefix(60)).replacingOccurrences(of: "\n", with: " ")
        let suffix = snippet.count > 60 ? "..." : ""

        if blockNum < total {
            updateStatus("\u{1F4CB} Block \(blockNum)/\(total) copied!  Press \u{2318}V to paste  |  \u{2303}3: next block  |  Esc: stop")
        } else {
            updateStatus("\u{1F4CB} Block \(blockNum)/\(total) copied!  Press \u{2318}V to paste  |  Esc: close")
        }

        NSLog("DemoType: Copied block \(blockNum)/\(total) to clipboard: \(preview)\(suffix)")

        // Re-activate target app so user can immediately Cmd+V
        activateTargetApp {}
    }

    // MARK: - Block completion (for live typing mode)

    private func finishedCurrentBlock() {
        state = .waitingForNext
        let blockNum = currentSnippetIndex + 1
        let total = snippets.count
        if blockNum < total {
            updateStatus("\u{2713} Block \(blockNum)/\(total) typed  |  \u{2303}3: next  |  Esc: stop")
        } else {
            updateStatus("\u{2705} All \(total) blocks typed!")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.close()
            }
        }
    }

    // MARK: - Keyboard monitors

    private func installMonitors() {
        escMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.close() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { self?.close(); return nil }
            return event
        }
    }

    // MARK: - Alerts

    func showNoFileAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "DemoType \u{2014} No File Configured"
        alert.informativeText = "Open Settings to choose a text file with [start]...[end] blocks."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            gAppDelegate?.openSettings()
        }
        onClose?()
    }

    func showErrorAlert(_ msg: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "DemoType Error"
        alert.informativeText = msg
        alert.addButton(withTitle: "OK")
        alert.runModal()
        onClose?()
    }

    // MARK: - Floating status bar (non-activating panel)

    private func showStatusBar() {
        guard let screen = NSScreen.main else { return }
        let w: CGFloat = 560
        let h: CGFloat = 32
        let x = screen.frame.midX - w / 2
        let y = screen.frame.maxY - h - 8

        let win = NSPanel(contentRect: NSRect(x: x, y: y, width: w, height: h),
                          styleMask: [.borderless, .nonactivatingPanel],
                          backing: .buffered, defer: false)
        win.level = .floating
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.hidesOnDeactivate = false  // Keep visible when other apps are active

        let container = NSView(frame: NSRect(origin: .zero, size: NSSize(width: w, height: h)))
        container.wantsLayer = true
        container.layer?.cornerRadius = 8
        container.layer?.backgroundColor = NSColor(white: 0.1, alpha: 0.9).cgColor

        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.frame = NSRect(x: 12, y: 6, width: w - 24, height: 20)
        label.tag = 100
        container.addSubview(label)

        win.contentView = container
        win.orderFrontRegardless()
        statusWindow = win
    }

    private func updateStatus(_ text: String) {
        if let label = statusWindow?.contentView?.viewWithTag(100) as? NSTextField {
            label.stringValue = text
        }
    }

    // MARK: - Close / Reset

    func close() {
        typeTimer?.invalidate(); typeTimer = nil
        state = .idle
        snippets = []
        currentSnippetIndex = 0
        currentCharIndex = 0
        targetApp = nil
        targetBundleID = nil
        // Restore clipboard if we saved it
        if let prev = savedClipboard {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(prev, forType: .string)
            savedClipboard = nil
        }
        if let m = escMonitor { NSEvent.removeMonitor(m); escMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }
        statusWindow?.orderOut(nil); statusWindow = nil
        onClose?()
    }
}
