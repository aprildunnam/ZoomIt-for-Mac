import Cocoa

/// A borderless NSWindow subclass that can become key and main.
/// By default, borderless windows (styleMask = .borderless) return false
/// for canBecomeKey/canBecomeMain, which prevents keyboard events from
/// reaching the contentView. This subclass fixes that.
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
