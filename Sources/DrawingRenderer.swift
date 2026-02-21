import Cocoa

// MARK: - Shared Drawing Renderer

class DrawingRenderer {
    /// Render a DrawnLine element into a CGContext.
    /// `scale` adjusts line widths when zoomed (pass 1.0 for normal).
    static func render(_ line: DrawnLine, in ctx: CGContext, scale: CGFloat = 1.0) {
        let isHL = line.tool == .highlighter
        let alpha: CGFloat = isHL ? 0.35 : 1.0
        let color = line.color.withAlphaComponent(min(line.color.alphaComponent, alpha))
        let w = (isHL ? line.width * 5 : line.width) * scale

        switch line.tool {
        case .pen, .highlighter:
            guard line.points.count > 1 else { return }
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(w)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.beginPath()
            ctx.move(to: line.points[0])
            for i in 1..<line.points.count { ctx.addLine(to: line.points[i]) }
            ctx.strokePath()

        case .line:
            guard line.points.count >= 2 else { return }
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(w)
            ctx.setLineCap(.round)
            ctx.beginPath()
            ctx.move(to: line.points.first!)
            ctx.addLine(to: line.points.last!)
            ctx.strokePath()

        case .arrow:
            guard line.points.count >= 2 else { return }
            let s = line.points.first!, e = line.points.last!
            ctx.setStrokeColor(color.cgColor)
            ctx.setFillColor(color.cgColor)
            ctx.setLineWidth(w)
            ctx.setLineCap(.round)
            ctx.beginPath(); ctx.move(to: s); ctx.addLine(to: e); ctx.strokePath()
            // Arrowhead
            let angle = atan2(e.y - s.y, e.x - s.x)
            let hl: CGFloat = max(12, w * 4)
            let ha: CGFloat = .pi / 6
            let p1 = CGPoint(x: e.x - hl * cos(angle - ha), y: e.y - hl * sin(angle - ha))
            let p2 = CGPoint(x: e.x - hl * cos(angle + ha), y: e.y - hl * sin(angle + ha))
            ctx.beginPath(); ctx.move(to: e); ctx.addLine(to: p1)
            ctx.addLine(to: p2); ctx.closePath(); ctx.fillPath()

        case .rectangle:
            guard line.points.count >= 2 else { return }
            let s = line.points.first!, e = line.points.last!
            let rect = CGRect(x: min(s.x, e.x), y: min(s.y, e.y),
                              width: abs(e.x - s.x), height: abs(e.y - s.y))
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(w)
            ctx.stroke(rect)

        case .ellipse:
            guard line.points.count >= 2 else { return }
            let s = line.points.first!, e = line.points.last!
            let rect = CGRect(x: min(s.x, e.x), y: min(s.y, e.y),
                              width: abs(e.x - s.x), height: abs(e.y - s.y))
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(w)
            ctx.strokeEllipse(in: rect)

        case .text:
            guard let pt = line.points.first else { return }
            let fontSize = max(line.width * 6, 18)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: line.color
            ]
            let nsStr = line.text as NSString
            let size = nsStr.size(withAttributes: attrs)
            // Need to flip coordinate for text in CG context
            ctx.saveGState()
            ctx.translateBy(x: pt.x, y: pt.y + size.height)
            ctx.scaleBy(x: 1, y: -1)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            nsStr.draw(at: .zero, withAttributes: attrs)
            NSGraphicsContext.restoreGraphicsState()
            ctx.restoreGState()

        case .blur:
            guard line.points.count > 1 else { return }
            // Draw a semi-transparent gray overlay to simulate blur
            ctx.setStrokeColor(NSColor(white: 0.5, alpha: 0.6).cgColor)
            ctx.setLineWidth(w * 3)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.setBlendMode(.normal)
            ctx.beginPath()
            ctx.move(to: line.points[0])
            for i in 1..<line.points.count { ctx.addLine(to: line.points[i]) }
            ctx.strokePath()
        }
    }
}
