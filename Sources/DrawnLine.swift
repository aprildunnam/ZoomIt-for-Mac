import Cocoa

// MARK: - Drawing Model

struct DrawnLine {
    var color: NSColor
    var width: CGFloat
    var points: [CGPoint]
    var tool: DrawingTool = .pen
    var text: String = ""  // For text annotations

    enum DrawingTool {
        case pen
        case arrow
        case rectangle
        case ellipse
        case line
        case highlighter
        case text
        case blur
    }
}
