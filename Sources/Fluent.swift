import AppKit

// Fluent design tokens and primitive controls used to reproduce the
// Windows 11 Paint chrome with native AppKit drawing.

enum SkinLayout { case fluent, ribbon, classic }

enum Skin: String, CaseIterable {
    case win11, win10, win7, winxp

    var title: String {
        switch self {
        case .win11: return "Windows 11"
        case .win10: return "Windows 10"
        case .win7: return "Windows 7"
        case .winxp: return "Windows XP"
        }
    }
    var layout: SkinLayout {
        switch self {
        case .win11: return .fluent
        case .win10, .win7: return .ribbon
        case .winxp: return .classic
        }
    }
    var appName: String { self == .winxp ? "小畫家" : "小畫家" }
    var tokens: SkinTokens {
        func c(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor { Fluent.color(hex, a) }
        switch self {
        case .win11:
            return SkinTokens(
                chrome: c(0xFFFFFF), chromeBorder: c(0xE5E5E5),
                workspaceTop: c(0xEFEFF3), workspaceBottom: c(0xEFEFF3),
                statusFill: c(0xF3F3F3), divider: c(0xE4E4E4),
                ink: c(0x1B1B1B), inkSoft: c(0x5D5D5D), caption: c(0x5D5D5D),
                accent: c(0x0067C0), accentDeep: c(0x003E92), accentSoft: c(0xCCE4F7),
                checkedFill: c(0xEFF6FC), checkedBorder: c(0xA3CDEC),
                hoverFill: c(0x000000, 0.0373), pressFill: c(0x000000, 0.0745),
                fieldFill: c(0xFBFBFB), fieldBorder: c(0xE2E2E2), trackFill: c(0xD8D8D8),
                shadow: c(0x000000, 0.13),
                tabBar: c(0xFFFFFF), tabActive: c(0xFFFFFF), tabInactiveInk: c(0x1B1B1B),
                fileTab: c(0x0067C0),
                radius: 5, roundSwatches: true, bevel: false,
                faces: ["Segoe UI", "Microsoft JhengHei UI", "Microsoft JhengHei"],
                boldFaces: ["Segoe UI Semibold", "Microsoft JhengHei UI Bold"],
                menuHeight: 40, ribbonHeight: 104, statusHeight: 28)
        case .win10:
            return SkinTokens(
                chrome: c(0xF5F6F8), chromeBorder: c(0xD5D9DE),
                workspaceTop: c(0xC6CFE0), workspaceBottom: c(0xD8E1F0),
                statusFill: c(0xF0F0F0), divider: c(0xD9DDE3),
                ink: c(0x1B1B1B), inkSoft: c(0x5A5A5A), caption: c(0x6E6E6E),
                accent: c(0x0072C6), accentDeep: c(0x005A9E), accentSoft: c(0xCDE6F7),
                checkedFill: c(0xCDE6F7), checkedBorder: c(0x66A9D8),
                hoverFill: c(0x2E8ADA, 0.16), pressFill: c(0x2E8ADA, 0.3),
                fieldFill: c(0xFFFFFF), fieldBorder: c(0xC8CDD4), trackFill: c(0xCBCBCB),
                shadow: c(0x000000, 0.12),
                tabBar: c(0xFFFFFF), tabActive: c(0xF5F6F8), tabInactiveInk: c(0x1B1B1B),
                fileTab: c(0x0072C6),
                radius: 0, roundSwatches: false, bevel: false,
                faces: ["Segoe UI", "Microsoft JhengHei UI", "Microsoft JhengHei"],
                boldFaces: ["Segoe UI Semibold", "Microsoft JhengHei UI Bold"],
                menuHeight: 30, ribbonHeight: 100, statusHeight: 26)
        case .win7:
            return SkinTokens(
                chrome: c(0xE8F0FA), chromeBorder: c(0x9DB9D1),
                workspaceTop: c(0xA8B9CE), workspaceBottom: c(0xC9D5E5),
                statusFill: c(0xDDE9F6), divider: c(0xB6CBE0),
                ink: c(0x11314F), inkSoft: c(0x35526E), caption: c(0x3B5A79),
                accent: c(0x3C7FB1), accentDeep: c(0x1F4E73), accentSoft: c(0xCBE2F6),
                checkedFill: c(0xC5DEF5), checkedBorder: c(0x6AA4D4),
                hoverFill: c(0xFFE09A, 0.75), pressFill: c(0xF7C55E, 0.85),
                fieldFill: c(0xFDFEFF), fieldBorder: c(0xA6C0DA), trackFill: c(0xBACBDD),
                shadow: c(0x11314F, 0.18),
                tabBar: c(0xCFE0F1), tabActive: c(0xE8F0FA), tabInactiveInk: c(0x11314F),
                fileTab: c(0x3C7FB1),
                radius: 3, roundSwatches: false, bevel: false,
                faces: ["Segoe UI", "Microsoft JhengHei UI", "Microsoft JhengHei"],
                boldFaces: ["Segoe UI Semibold", "Microsoft JhengHei UI Bold"],
                menuHeight: 30, ribbonHeight: 100, statusHeight: 26)
        case .winxp:
            return SkinTokens(
                chrome: c(0xECE9D8), chromeBorder: c(0xACA899),
                workspaceTop: c(0x808080), workspaceBottom: c(0x808080),
                statusFill: c(0xECE9D8), divider: c(0xACA899),
                ink: c(0x000000), inkSoft: c(0x3C3C3C), caption: c(0x000000),
                accent: c(0x316AC5), accentDeep: c(0x0A246A), accentSoft: c(0xB6C7E6),
                checkedFill: c(0xDCD8C8), checkedBorder: c(0x808080),
                hoverFill: c(0x000000, 0.05), pressFill: c(0x000000, 0.12),
                fieldFill: c(0xFFFFFF), fieldBorder: c(0x808080), trackFill: c(0xACA899),
                shadow: c(0x000000, 0.0),
                tabBar: c(0xECE9D8), tabActive: c(0xECE9D8), tabInactiveInk: c(0x000000),
                fileTab: c(0x0A246A),
                radius: 0, roundSwatches: false, bevel: true,
                faces: ["Tahoma", "Microsoft JhengHei", "PingFang TC"],
                boldFaces: ["Tahoma Bold", "Microsoft JhengHei Bold"],
                menuHeight: 22, ribbonHeight: 0, statusHeight: 22)
        }
    }
}

struct SkinTokens {
    var chrome: NSColor
    var chromeBorder: NSColor
    var workspaceTop: NSColor
    var workspaceBottom: NSColor
    var statusFill: NSColor
    var divider: NSColor
    var ink: NSColor
    var inkSoft: NSColor
    var caption: NSColor
    var accent: NSColor
    var accentDeep: NSColor
    var accentSoft: NSColor
    var checkedFill: NSColor
    var checkedBorder: NSColor
    var hoverFill: NSColor
    var pressFill: NSColor
    var fieldFill: NSColor
    var fieldBorder: NSColor
    var trackFill: NSColor
    var shadow: NSColor
    var tabBar: NSColor
    var tabActive: NSColor
    var tabInactiveInk: NSColor
    var fileTab: NSColor
    var radius: CGFloat
    var roundSwatches: Bool
    var bevel: Bool
    var faces: [String]
    var boldFaces: [String]
    var menuHeight: CGFloat
    var ribbonHeight: CGFloat
    var statusHeight: CGFloat
}

enum Fluent {
    static var skin: Skin = .win11
    static var t: SkinTokens { skin.tokens }

    static func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: alpha)
    }

    static var chrome: NSColor { t.chrome }
    static var chromeBorder: NSColor { t.chromeBorder }
    static var workspace: NSColor { t.workspaceTop }
    static var statusFill: NSColor { t.statusFill }
    static var divider: NSColor { t.divider }
    static var ink: NSColor { t.ink }
    static var inkSoft: NSColor { t.inkSoft }
    static var caption: NSColor { t.caption }
    static var accent: NSColor { t.accent }
    static var accentDeep: NSColor { t.accentDeep }
    static var accentSoft: NSColor { t.accentSoft }
    static var checkedFill: NSColor { t.checkedFill }
    static var checkedBorder: NSColor { t.checkedBorder }
    static var hoverFill: NSColor { t.hoverFill }
    static var pressFill: NSColor { t.pressFill }
    static var fieldFill: NSColor { t.fieldFill }
    static var fieldBorder: NSColor { t.fieldBorder }
    static var trackFill: NSColor { t.trackFill }
    static var shadow: NSColor { t.shadow }
    static var radius: CGFloat { t.radius }
    static var roundSwatches: Bool { t.roundSwatches }
    static var classicChrome: Bool { t.bevel }

    static func ui(_ size: CGFloat, bold: Bool = false) -> NSFont {
        let tokens = t
        for name in (bold ? tokens.boldFaces : tokens.faces) {
            if let font = NSFont(name: name, size: size) { return font }
        }
        return NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular)
    }

    static func paragraph(_ alignment: NSTextAlignment) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byTruncatingTail
        return style
    }

    @discardableResult
    static func text(_ string: String, in rect: NSRect, font: NSFont,
                     color: NSColor, alignment: NSTextAlignment = .center) -> NSSize {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: paragraph(alignment)
        ]
        let measured = (string as NSString).size(withAttributes: attributes)
        let box = NSRect(x: rect.minX, y: rect.minY + (rect.height - measured.height) / 2,
                         width: rect.width, height: measured.height)
        (string as NSString).draw(in: box, withAttributes: attributes)
        return measured
    }

    static func width(_ string: String, font: NSFont) -> CGFloat {
        (string as NSString).size(withAttributes: [.font: font]).width
    }

    static func fill(_ rect: NSRect, radius: CGFloat, color: NSColor) {
        color.setFill()
        if radius <= 0 { rect.fill(); return }
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
    }

    static func stroke(_ rect: NSRect, radius: CGFloat, color: NSColor, width: CGFloat = 1) {
        color.setStroke()
        let inset = rect.insetBy(dx: width / 2, dy: width / 2)
        let path = radius <= 0 ? NSBezierPath(rect: inset)
            : NSBezierPath(roundedRect: inset, xRadius: radius, yRadius: radius)
        path.lineWidth = width
        path.stroke()
    }

    static func gradient(_ rect: NSRect, _ top: NSColor, _ bottom: NSColor) {
        if top == bottom { top.setFill(); rect.fill(); return }
        NSGradient(starting: top, ending: bottom)?.draw(in: rect, angle: -90)
    }

    // Classic Windows 3D border. Raised for buttons, sunken for wells and panes.
    static func bevel(_ rect: NSRect, raised: Bool, thin: Bool = false) {
        let light = color(0xFFFFFF), face = color(0xECE9D8)
        let shadow = color(0xACA899), dark = color(0x716F64)
        let outerTop = raised ? light : shadow
        let outerBottom = raised ? dark : light
        let innerTop = raised ? face : dark
        let innerBottom = raised ? shadow : face
        func edge(_ r: NSRect, _ top: NSColor, _ bottom: NSColor) {
            top.setFill()
            NSRect(x: r.minX, y: r.minY, width: r.width, height: 1).fill()
            NSRect(x: r.minX, y: r.minY, width: 1, height: r.height).fill()
            bottom.setFill()
            NSRect(x: r.minX, y: r.maxY - 1, width: r.width, height: 1).fill()
            NSRect(x: r.maxX - 1, y: r.minY, width: 1, height: r.height).fill()
        }
        edge(rect, outerTop, outerBottom)
        if !thin { edge(rect.insetBy(dx: 1, dy: 1), innerTop, innerBottom) }
    }
}

// MARK: - Icons

enum Glyph {
    case save, share, undo, redo, settings, chevron
    case selectRect, freeSelect, crop, resize, rotate, flip, removeBackground
    case pencil, bucket, letterA, eraser, dropper, magnifier
    case brush, marker, spray, pen
    case line, curve, oval, rectangle, roundRectangle, polygonShape
    case triangle, rightTriangle, diamond, pentagon, hexagon
    case arrowRight, arrowLeft, arrowUp, arrowDown
    case star4, star5, star6
    case calloutRectangle, calloutOval, calloutCloud, heart, lightning
    case outline, fillStyle, thickness, opacity
    case layers, copilot, plus, trash, duplicate, merge, eye, eyeOff, moveUp, moveDown
    case cursor, marquee, canvasSize, fitWindow, zoomOut, zoomIn, grid
}

struct GlyphPainter {
    // Draws a glyph inside `box` assuming a flipped (top-left origin) context.
    static func draw(_ glyph: Glyph, in box: NSRect,
                     tint: NSColor = Fluent.ink, accent: NSColor = Fluent.accent) {
        let unit = min(box.width, box.height) / 16
        let ox = box.minX + (box.width - 16 * unit) / 2
        let oy = box.minY + (box.height - 16 * unit) / 2
        func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: ox + x * unit, y: oy + y * unit) }
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
            NSRect(x: ox + x * unit, y: oy + y * unit, width: w * unit, height: h * unit)
        }
        func line(_ points: [NSPoint], close: Bool = false, width: CGFloat = 1.2,
                  color: NSColor? = nil, dash: Bool = false) {
            guard let first = points.first else { return }
            let ink = color ?? tint
            let path = NSBezierPath()
            path.move(to: first)
            for point in points.dropFirst() { path.line(to: point) }
            if close { path.close() }
            path.lineWidth = width * unit
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            if dash { path.setLineDash([1.7 * unit, 1.5 * unit], count: 2, phase: 0) }
            ink.setStroke()
            path.stroke()
        }
        func shape(_ points: [NSPoint], color: NSColor) {
            guard let first = points.first else { return }
            let path = NSBezierPath()
            path.move(to: first)
            for point in points.dropFirst() { path.line(to: point) }
            path.close()
            color.setFill()
            path.fill()
        }
        func frame(_ r: NSRect, radius: CGFloat = 0, width: CGFloat = 1.2,
                   color: NSColor? = nil, dash: Bool = false) {
            let ink = color ?? tint
            let path = radius > 0
                ? NSBezierPath(roundedRect: r, xRadius: radius * unit, yRadius: radius * unit)
                : NSBezierPath(rect: r)
            path.lineWidth = width * unit
            if dash { path.setLineDash([1.7 * unit, 1.5 * unit], count: 2, phase: 0) }
            ink.setStroke()
            path.stroke()
        }
        func oval(_ r: NSRect, width: CGFloat = 1.2, color: NSColor? = nil, filled: Bool = false) {
            let ink = color ?? tint
            let path = NSBezierPath(ovalIn: r)
            if filled { ink.setFill(); path.fill(); return }
            path.lineWidth = width * unit
            ink.setStroke()
            path.stroke()
        }
        func star(points count: Int, inner: CGFloat) {
            var pts = [NSPoint]()
            for i in 0..<(count * 2) {
                let angle = CGFloat(i) * .pi / CGFloat(count) - .pi / 2
                let radius: CGFloat = i % 2 == 0 ? 6.4 : inner
                pts.append(p(8 + cos(angle) * radius, 8 + sin(angle) * radius))
            }
            line(pts, close: true)
        }
        func polygon(sides: Int, radius: CGFloat = 6.3, rotation: CGFloat = -CGFloat.pi / 2) {
            var pts = [NSPoint]()
            for i in 0..<sides {
                let angle = rotation + CGFloat(i) * 2 * .pi / CGFloat(sides)
                pts.append(p(8 + cos(angle) * radius, 8 + sin(angle) * radius))
            }
            line(pts, close: true)
        }

        switch glyph {
        case .save:
            frame(rect(2.4, 2.4, 11.2, 11.2), radius: 1.2)
            line([p(5, 2.4), p(5, 6.2), p(11, 6.2), p(11, 2.4)])
            frame(rect(4.6, 8.6, 6.8, 5))
        case .share:
            frame(rect(2.4, 4.6, 8.4, 9), radius: 1.2)
            line([p(11.2, 7.4), p(14.2, 4.3), p(11.2, 1.6)], color: accent)
            line([p(14.2, 4.3), p(7.4, 4.3)], color: accent)
        case .undo:
            let path = NSBezierPath()
            path.move(to: p(3.2, 8.4))
            path.curve(to: p(12.4, 11.6), controlPoint1: p(5.4, 3.6), controlPoint2: p(13.4, 5.2))
            path.lineWidth = 1.35 * unit
            path.lineCapStyle = .round
            tint.setStroke()
            path.stroke()
            line([p(3.2, 4.4), p(3.2, 8.7), p(7.4, 8.7)])
        case .redo:
            let path = NSBezierPath()
            path.move(to: p(12.8, 8.4))
            path.curve(to: p(3.6, 11.6), controlPoint1: p(10.6, 3.6), controlPoint2: p(2.6, 5.2))
            path.lineWidth = 1.35 * unit
            path.lineCapStyle = .round
            tint.setStroke()
            path.stroke()
            line([p(12.8, 4.4), p(12.8, 8.7), p(8.6, 8.7)])
        case .settings:
            oval(rect(5.6, 5.6, 4.8, 4.8))
            for i in 0..<8 {
                let angle = CGFloat(i) * .pi / 4
                line([p(8 + cos(angle) * 5.1, 8 + sin(angle) * 5.1),
                      p(8 + cos(angle) * 6.8, 8 + sin(angle) * 6.8)], width: 1.5)
            }
        case .chevron:
            line([p(4.2, 6.4), p(8, 10), p(11.8, 6.4)], width: 1.25)
        case .selectRect:
            frame(rect(2.2, 2.2, 11.6, 11.6), dash: true)
        case .freeSelect:
            line([p(8, 1.8), p(10.2, 6.2), p(14.6, 6.6), p(11.2, 9.8),
                  p(12.4, 14.2), p(8, 12), p(3.6, 14.2), p(4.8, 9.8),
                  p(1.4, 6.6), p(5.8, 6.2)], close: true, dash: true)
        case .crop:
            line([p(4.6, 1.6), p(4.6, 11.4), p(14.4, 11.4)])
            line([p(1.6, 4.6), p(11.4, 4.6), p(11.4, 14.4)])
        case .resize:
            frame(rect(1.8, 1.8, 7.4, 7.4), dash: true)
            frame(rect(7, 7, 7.2, 7.2), color: accent)
            line([p(9.6, 12), p(12.2, 9.4)], color: accent)
        case .rotate:
            let path = NSBezierPath()
            path.move(to: p(2.6, 9.4))
            path.curve(to: p(13.4, 9.4), controlPoint1: p(3.2, 1.6), controlPoint2: p(12.8, 1.6))
            path.lineWidth = 1.3 * unit
            accent.setStroke()
            path.stroke()
            shape([p(11.2, 8.6), p(15.4, 8.6), p(13.3, 12.6)], color: accent)
        case .flip:
            line([p(8, 1.6), p(8, 14.4)], width: 1, dash: true)
            shape([p(6.6, 3.4), p(6.6, 12.6), p(1.4, 8)], color: accent)
            line([p(9.4, 3.4), p(9.4, 12.6), p(14.6, 8)], close: true)
        case .removeBackground:
            frame(rect(1.6, 3.2, 9.6, 9.6), radius: 1.2, color: accent, dash: true)
            oval(rect(3.6, 5.4, 2.4, 2.4), color: accent)
            line([p(3.2, 11.6), p(6, 8), p(8.6, 11.6)], color: accent)
            line([p(11.4, 6.4), p(14.4, 3.4)], color: accent)
            line([p(11.6, 3.4), p(14.4, 3.4), p(14.4, 6.2)], color: accent)
        case .pencil:
            shape([p(2.2, 13.8), p(3.4, 10.4), p(5.6, 12.6)], color: tint)
            line([p(4.2, 9.6), p(11, 2.8), p(13.2, 5), p(6.4, 11.8)], close: true)
            line([p(11, 2.8), p(13.2, 5)])
        case .bucket:
            line([p(3.1, 7.4), p(8.4, 2.1), p(13.4, 7.1), p(8.1, 12.4)], close: true)
            line([p(5.6, 4.9), p(5.6, 1.6)])
            shape([p(14, 9), p(15.4, 11.6), p(12.6, 11.6)], color: accent)
        case .letterA:
            line([p(3.2, 13.4), p(8, 2.6), p(12.8, 13.4)])
            line([p(5.2, 9.6), p(10.8, 9.6)])
        case .eraser:
            line([p(2.2, 11.2), p(8.6, 4.8), p(13.4, 9.6), p(11, 12), p(4.6, 12), p(2.2, 11.2)], close: true)
            line([p(5.8, 7.6), p(10.6, 12)])
        case .dropper:
            line([p(2.4, 13.6), p(2.4, 11.2), p(9, 4.6), p(11.4, 7), p(4.8, 13.6)], close: true)
            line([p(9.8, 3.8), p(12.2, 1.4), p(14.6, 3.8), p(12.2, 6.2)], close: true)
        case .magnifier:
            oval(rect(2.4, 2.4, 9, 9))
            line([p(10.6, 10.6), p(14, 14)], width: 1.5)
        case .brush:
            line([p(5.4, 1.8), p(10.6, 1.8), p(10.6, 8.6), p(5.4, 8.6)], close: true)
            line([p(5.4, 5.6), p(10.6, 5.6)])
            shape([p(6.2, 8.8), p(9.8, 8.8), p(8.9, 14.2), p(7.1, 14.2)], color: tint)
        case .marker:
            line([p(4.4, 2.2), p(11.6, 2.2), p(11.6, 7.4), p(4.4, 7.4)], close: true)
            shape([p(4.4, 7.6), p(11.6, 7.6), p(9.8, 13.6), p(6.2, 13.6)], color: accent)
        case .spray:
            line([p(6, 2.4), p(10, 2.4), p(10, 7.2), p(6, 7.2)], close: true)
            line([p(6, 7.4), p(10, 7.4), p(10, 13.6), p(6, 13.6)], close: true)
            for point in [p(12, 4), p(13.6, 6), p(12.4, 8.4), p(14, 10), p(12, 11.6)] {
                oval(NSRect(x: point.x - 0.6 * unit, y: point.y - 0.6 * unit,
                            width: 1.2 * unit, height: 1.2 * unit), color: tint, filled: true)
            }
        case .pen:
            line([p(2.4, 13.6), p(4, 9.8), p(11.4, 2.4), p(13.6, 4.6), p(6.2, 12), p(2.4, 13.6)], close: true)
        case .line:
            line([p(2.6, 13.4), p(13.4, 2.6)])
        case .curve:
            let path = NSBezierPath()
            path.move(to: p(2.2, 11.4))
            path.curve(to: p(13.8, 11.4), controlPoint1: p(5, 2), controlPoint2: p(11, 20))
            path.lineWidth = 1.2 * unit
            path.lineCapStyle = .round
            tint.setStroke()
            path.stroke()
        case .oval:
            oval(rect(2.2, 3.4, 11.6, 9.2))
        case .rectangle:
            frame(rect(2.2, 3.6, 11.6, 8.8))
        case .roundRectangle:
            frame(rect(2.2, 3.6, 11.6, 8.8), radius: 2.4)
        case .polygonShape:
            line([p(2.2, 9.6), p(6.4, 2.4), p(10.2, 6.6), p(13.8, 4.4), p(12.4, 13.6), p(4.2, 13.6)], close: true)
        case .triangle:
            line([p(8, 2.6), p(14, 13.4), p(2, 13.4)], close: true)
        case .rightTriangle:
            line([p(2.6, 2.6), p(2.6, 13.4), p(13.4, 13.4)], close: true)
        case .diamond:
            line([p(8, 2.2), p(13.8, 8), p(8, 13.8), p(2.2, 8)], close: true)
        case .pentagon:
            polygon(sides: 5)
        case .hexagon:
            polygon(sides: 6, rotation: 0)
        case .arrowRight:
            line([p(1.8, 5.6), p(8.6, 5.6), p(8.6, 2.6), p(14.2, 8), p(8.6, 13.4), p(8.6, 10.4), p(1.8, 10.4)], close: true)
        case .arrowLeft:
            line([p(14.2, 5.6), p(7.4, 5.6), p(7.4, 2.6), p(1.8, 8), p(7.4, 13.4), p(7.4, 10.4), p(14.2, 10.4)], close: true)
        case .arrowUp:
            line([p(5.6, 14.2), p(5.6, 7.4), p(2.6, 7.4), p(8, 1.8), p(13.4, 7.4), p(10.4, 7.4), p(10.4, 14.2)], close: true)
        case .arrowDown:
            line([p(5.6, 1.8), p(5.6, 8.6), p(2.6, 8.6), p(8, 14.2), p(13.4, 8.6), p(10.4, 8.6), p(10.4, 1.8)], close: true)
        case .star4:
            star(points: 4, inner: 2.1)
        case .star5:
            star(points: 5, inner: 2.7)
        case .star6:
            star(points: 6, inner: 3.3)
        case .calloutRectangle:
            frame(rect(1.8, 2.4, 12.4, 8.2), radius: 1.4)
            line([p(5, 10.6), p(4.2, 14), p(8.4, 10.6)], close: true)
        case .calloutOval:
            oval(rect(1.8, 2.4, 12.4, 8.2))
            line([p(5, 10.2), p(4.2, 14), p(8.4, 10)], close: true)
        case .calloutCloud:
            let path = NSBezierPath()
            path.appendOval(in: rect(2, 5.4, 5.6, 5))
            path.appendOval(in: rect(5, 2.6, 6.4, 5.8))
            path.appendOval(in: rect(8.6, 5, 5.6, 5.2))
            path.lineWidth = 1.2 * unit
            tint.setStroke()
            path.stroke()
            oval(rect(4.4, 11.4, 2, 2))
            oval(rect(2.6, 13.4, 1.4, 1.4))
        case .heart:
            let path = NSBezierPath()
            path.move(to: p(8, 13.6))
            path.curve(to: p(1.8, 6), controlPoint1: p(3.4, 10.4), controlPoint2: p(1.8, 8.4))
            path.curve(to: p(8, 5), controlPoint1: p(1.8, 2.4), controlPoint2: p(6.4, 2.4))
            path.curve(to: p(14.2, 6), controlPoint1: p(9.6, 2.4), controlPoint2: p(14.2, 2.4))
            path.curve(to: p(8, 13.6), controlPoint1: p(14.2, 8.4), controlPoint2: p(12.6, 10.4))
            path.lineWidth = 1.2 * unit
            tint.setStroke()
            path.stroke()
        case .lightning:
            line([p(9.4, 1.6), p(4, 8.8), p(7.4, 8.8), p(6.4, 14.4), p(12, 7), p(8.6, 7)], close: true)
        case .outline:
            line([p(2.4, 12.4), p(3.4, 9.6), p(10.6, 2.4), p(13.6, 5.4), p(6.4, 12.6)], close: true)
        case .fillStyle:
            frame(rect(2.2, 3.4, 11.6, 9.2), radius: 1.2)
            Fluent.accentSoft.setFill()
            NSBezierPath(roundedRect: rect(3.6, 4.8, 8.8, 6.4), xRadius: unit, yRadius: unit).fill()
        case .thickness:
            line([p(2.4, 4), p(13.6, 4)], width: 0.8)
            line([p(2.4, 7.4), p(13.6, 7.4)], width: 1.5)
            line([p(2.4, 11.4), p(13.6, 11.4)], width: 2.4)
        case .opacity:
            oval(rect(3.4, 2.2, 9.2, 11.6))
            let clip = NSBezierPath(ovalIn: rect(3.4, 2.2, 9.2, 11.6))
            NSGraphicsContext.saveGraphicsState()
            clip.addClip()
            tint.setFill()
            rect(3.4, 8, 9.2, 5.8).fill()
            NSGraphicsContext.restoreGraphicsState()
        case .layers:
            line([p(8, 1.8), p(14.4, 5.4), p(8, 9), p(1.6, 5.4)], close: true)
            line([p(2.4, 8.4), p(8, 11.6), p(13.6, 8.4)], color: accent)
            line([p(2.4, 11.2), p(8, 14.4), p(13.6, 11.2)], color: accent)
        case .copilot:
            let path = NSBezierPath()
            path.move(to: p(3, 12.4))
            path.curve(to: p(8, 3.2), controlPoint1: p(3.4, 6.4), controlPoint2: p(5, 3.2))
            path.curve(to: p(13, 12.4), controlPoint1: p(11, 3.2), controlPoint2: p(12.6, 6.4))
            path.curve(to: p(3, 12.4), controlPoint1: p(11, 14.4), controlPoint2: p(5, 14.4))
            accent.setFill()
            path.fill()
            Fluent.color(0x00A2ED).setFill()
            NSBezierPath(ovalIn: rect(9.6, 2.2, 4.4, 4.4)).fill()
        case .plus:
            line([p(8, 3.2), p(8, 12.8)], width: 1.4)
            line([p(3.2, 8), p(12.8, 8)], width: 1.4)
        case .trash:
            line([p(2.6, 4.2), p(13.4, 4.2)])
            line([p(6, 4.2), p(6, 2.4), p(10, 2.4), p(10, 4.2)])
            line([p(4.2, 4.4), p(5.1, 13.6), p(10.9, 13.6), p(11.8, 4.4)], close: false)
            line([p(5.1, 13.6), p(10.9, 13.6)])
        case .duplicate:
            frame(rect(2.2, 2.2, 9, 9), radius: 1.2)
            frame(rect(4.8, 4.8, 9, 9), radius: 1.2, color: accent)
        case .merge:
            frame(rect(2.4, 1.8, 11.2, 5.2), radius: 1)
            frame(rect(2.4, 8.4, 11.2, 5.4), radius: 1, color: accent)
            line([p(8, 7.2), p(8, 8.2)], color: accent)
        case .eye:
            let path = NSBezierPath()
            path.move(to: p(1.6, 8))
            path.curve(to: p(14.4, 8), controlPoint1: p(4.4, 2.4), controlPoint2: p(11.6, 2.4))
            path.curve(to: p(1.6, 8), controlPoint1: p(11.6, 13.6), controlPoint2: p(4.4, 13.6))
            path.lineWidth = 1.2 * unit
            tint.setStroke()
            path.stroke()
            oval(rect(6.2, 6.2, 3.6, 3.6), filled: false)
        case .eyeOff:
            let path = NSBezierPath()
            path.move(to: p(1.6, 8))
            path.curve(to: p(14.4, 8), controlPoint1: p(4.4, 2.4), controlPoint2: p(11.6, 2.4))
            path.curve(to: p(1.6, 8), controlPoint1: p(11.6, 13.6), controlPoint2: p(4.4, 13.6))
            path.lineWidth = 1.2 * unit
            Fluent.inkSoft.setStroke()
            path.stroke()
            line([p(2.6, 13.4), p(13.4, 2.6)], width: 1.4)
        case .moveUp:
            line([p(8, 13), p(8, 3)], width: 1.35)
            line([p(3.8, 7.2), p(8, 3), p(12.2, 7.2)], width: 1.35)
        case .moveDown:
            line([p(8, 3), p(8, 13)], width: 1.35)
            line([p(3.8, 8.8), p(8, 13), p(12.2, 8.8)], width: 1.35)
        case .cursor:
            shape([p(4.4, 2), p(4.4, 13.4), p(7.4, 10.4), p(9.6, 14.2), p(11.6, 13.2), p(9.4, 9.6), p(13.4, 9.2)], color: tint)
        case .marquee:
            frame(rect(2.4, 2.4, 11.2, 11.2), dash: true)
        case .canvasSize:
            frame(rect(2.2, 3.2, 11.6, 9.6))
        case .fitWindow:
            frame(rect(1.8, 3.4, 12.4, 9.2), radius: 1)
            line([p(4.4, 6.4), p(6.8, 8), p(4.4, 9.6)])
            line([p(11.6, 6.4), p(9.2, 8), p(11.6, 9.6)])
        case .zoomOut:
            oval(rect(2.2, 2.2, 9, 9))
            line([p(4.8, 6.7), p(8.6, 6.7)])
            line([p(10.4, 10.4), p(13.8, 13.8)], width: 1.5)
        case .zoomIn:
            oval(rect(2.2, 2.2, 9, 9))
            line([p(4.8, 6.7), p(8.6, 6.7)])
            line([p(6.7, 4.8), p(6.7, 8.6)])
            line([p(10.4, 10.4), p(13.8, 13.8)], width: 1.5)
        case .grid:
            frame(rect(2.4, 2.4, 11.2, 11.2))
            line([p(6.1, 2.4), p(6.1, 13.6)], width: 0.9)
            line([p(9.9, 2.4), p(9.9, 13.6)], width: 0.9)
            line([p(2.4, 6.1), p(13.6, 6.1)], width: 0.9)
            line([p(2.4, 9.9), p(13.6, 9.9)], width: 0.9)
        }
    }
}

// MARK: - Buttons

class FluentControl: NSView {
    var onClick: (() -> Void)?
    var menuBuilder: (() -> NSMenu)?
    var isChecked = false { didSet { if isChecked != oldValue { needsDisplay = true } } }
    var isEnabledControl = true { didSet { needsDisplay = true } }
    var hovering = false
    var pressing = false

    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                                       owner: self))
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovering = false; pressing = false; needsDisplay = true }
    override func mouseDown(with event: NSEvent) {
        guard isEnabledControl else { return }
        pressing = true
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        pressing = false
        needsDisplay = true
        guard isEnabledControl, bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        if let builder = menuBuilder {
            let menu = builder()
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.maxY + 4), in: self)
            return
        }
        onClick?()
    }
    func backdrop(_ rect: NSRect, radius: CGFloat = -1) {
        let r = radius < 0 ? Fluent.radius : radius
        if Fluent.classicChrome {
            if isChecked || pressing {
                Fluent.color(0xDCD8C8).setFill(); rect.fill()
                Fluent.bevel(rect, raised: false)
            } else if hovering {
                Fluent.bevel(rect, raised: true)
            }
            return
        }
        if isChecked {
            Fluent.fill(rect, radius: r, color: Fluent.checkedFill)
            Fluent.stroke(rect, radius: r, color: Fluent.checkedBorder)
        } else if pressing {
            Fluent.fill(rect, radius: r, color: Fluent.pressFill)
        } else if hovering {
            Fluent.fill(rect, radius: r, color: Fluent.hoverFill)
        }
    }
}

final class RibbonButton: FluentControl {
    enum Kind { case grid, wide, tall, text, labelled }
    var kind: Kind = .grid
    var glyph: Glyph?
    var caption: String = ""
    var showsChevron = false
    var glyphSize: CGFloat = 16
    var accentTint = Fluent.accent

    convenience init(_ glyph: Glyph?, caption: String = "", kind: Kind = .grid,
                     chevron: Bool = false, width: CGFloat? = nil, height: CGFloat? = nil) {
        self.init(frame: .zero)
        self.glyph = glyph
        self.caption = caption
        self.kind = kind
        self.showsChevron = chevron
        let defaultSize: NSSize
        switch kind {
        case .grid: defaultSize = NSSize(width: 32, height: 32)
        case .wide: defaultSize = NSSize(width: 44, height: 44)
        case .tall: defaultSize = NSSize(width: 54, height: 60)
        case .text: defaultSize = NSSize(width: max(52, Fluent.width(caption, font: Fluent.ui(13)) + 22), height: 30)
        case .labelled: defaultSize = NSSize(width: Fluent.width(caption, font: Fluent.ui(12)) + 40, height: 24)
        }
        setFrameSize(NSSize(width: width ?? defaultSize.width, height: height ?? defaultSize.height))
    }

    override func draw(_ dirtyRect: NSRect) {
        backdrop(bounds, radius: kind == .tall ? Fluent.radius + 1 : Fluent.radius)
        let tint = isEnabledControl ? Fluent.ink : Fluent.color(0x9B9B9B)
        let accent = isEnabledControl ? accentTint : Fluent.color(0xB4B4B4)
        switch kind {
        case .text:
            let inset: CGFloat = showsChevron ? 14 : 0
            Fluent.text(caption, in: NSRect(x: 0, y: 0, width: bounds.width - inset, height: bounds.height),
                        font: Fluent.ui(13), color: tint)
            if showsChevron {
                GlyphPainter.draw(.chevron, in: NSRect(x: bounds.maxX - 16, y: (bounds.height - 10) / 2,
                                                       width: 10, height: 10), tint: tint, accent: accent)
            }
        case .grid, .wide:
            let side = glyphSize
            var box = NSRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2,
                             width: side, height: side)
            if showsChevron { box.origin.x -= 4 }
            if let glyph { GlyphPainter.draw(glyph, in: box, tint: tint, accent: accent) }
            if showsChevron {
                GlyphPainter.draw(.chevron, in: NSRect(x: bounds.maxX - 13, y: (bounds.height - 10) / 2,
                                                       width: 10, height: 10), tint: tint, accent: accent)
            }
        case .tall:
            let side = glyphSize
            let box = NSRect(x: (bounds.width - side) / 2, y: 6, width: side, height: side)
            if let glyph { GlyphPainter.draw(glyph, in: box, tint: tint, accent: accent) }
            var captionTop = box.maxY + 3
            if showsChevron {
                GlyphPainter.draw(.chevron, in: NSRect(x: (bounds.width - 10) / 2, y: captionTop,
                                                       width: 10, height: 10), tint: tint, accent: accent)
                captionTop += 11
            }
            Fluent.text(caption, in: NSRect(x: 0, y: captionTop, width: bounds.width,
                                            height: bounds.maxY - captionTop),
                        font: Fluent.ui(11), color: tint)
        case .labelled:
            let box = NSRect(x: 5, y: (bounds.height - 16) / 2, width: 16, height: 16)
            if let glyph { GlyphPainter.draw(glyph, in: box, tint: tint, accent: accent) }
            let right: CGFloat = showsChevron ? 14 : 4
            Fluent.text(caption, in: NSRect(x: 25, y: 0, width: bounds.width - 25 - right, height: bounds.height),
                        font: Fluent.ui(12), color: tint, alignment: .left)
            if showsChevron {
                GlyphPainter.draw(.chevron, in: NSRect(x: bounds.maxX - 14, y: (bounds.height - 9) / 2,
                                                       width: 9, height: 9), tint: tint, accent: accent)
            }
        }
    }
}

// A colour dot used by the Win11 palette. Left click sets colour 1, right click colour 2.
final class ColorDot: FluentControl {
    var color: NSColor = .black { didSet { needsDisplay = true } }
    var isEmptySlot = false
    var diameter: CGFloat = 22
    var onPick: ((NSColor, Bool) -> Void)?

    convenience init(_ color: NSColor, diameter: CGFloat = 22, empty: Bool = false) {
        self.init(frame: NSRect(x: 0, y: 0, width: diameter, height: diameter))
        self.color = color
        self.diameter = diameter
        self.isEmptySlot = empty
    }
    override func draw(_ dirtyRect: NSRect) {
        if Fluent.classicChrome {
            let well = bounds.insetBy(dx: 1, dy: 1)
            if !isEmptySlot { color.setFill(); well.insetBy(dx: 2, dy: 2).fill() }
            Fluent.bevel(well, raised: false, thin: true)
            if isChecked {
                Fluent.color(0x000000).setStroke()
                let ring = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
                ring.lineWidth = 1
                ring.stroke()
            }
            return
        }
        if !Fluent.roundSwatches {
            let square = bounds.insetBy(dx: 2, dy: 2)
            if !isEmptySlot { color.setFill(); square.fill() }
            (isChecked ? Fluent.accent : Fluent.color(0x000000, 0.35)).setStroke()
            let border = NSBezierPath(rect: square.insetBy(dx: 0.5, dy: 0.5))
            border.lineWidth = isChecked ? 1.6 : 1
            border.stroke()
            if hovering && !isChecked {
                Fluent.accent.setStroke()
                let ring = NSBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5))
                ring.lineWidth = 1
                ring.stroke()
            }
            return
        }
        let inset: CGFloat = isChecked ? 3 : 1.5
        let circle = bounds.insetBy(dx: inset, dy: inset)
        if isChecked {
            Fluent.accent.setStroke()
            let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 0.8, dy: 0.8))
            ring.lineWidth = 1.6
            ring.stroke()
        }
        let path = NSBezierPath(ovalIn: circle)
        if !isEmptySlot {
            color.setFill()
            path.fill()
        }
        (isEmptySlot ? Fluent.color(0xBDBDBD) : Fluent.color(0x000000, 0.22)).setStroke()
        path.lineWidth = 1
        path.stroke()
        if hovering && !isChecked {
            Fluent.color(0x000000, 0.35).setStroke()
            let ring = NSBezierPath(ovalIn: bounds.insetBy(dx: 0.8, dy: 0.8))
            ring.lineWidth = 1.2
            ring.stroke()
        }
    }
    override func mouseUp(with event: NSEvent) {
        pressing = false
        needsDisplay = true
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        onPick?(color, false)
    }
    override func rightMouseDown(with event: NSEvent) { onPick?(color, true) }
}

// MARK: - Sliders

final class FluentSlider: NSView {
    var minValue: Double = 1
    var maxValue: Double = 100
    var value: Double = 10 { didSet { needsDisplay = true } }
    var vertical = false
    var onChange: ((Double) -> Void)?
    private var dragging = false

    override var isFlipped: Bool { true }

    convenience init(vertical: Bool, min: Double, max: Double, value: Double) {
        self.init(frame: .zero)
        self.vertical = vertical
        self.minValue = min
        self.maxValue = max
        self.value = value
    }

    private var fraction: CGFloat {
        let span = maxValue - minValue
        guard span > 0 else { return 0 }
        return CGFloat((value - minValue) / span)
    }

    override func draw(_ dirtyRect: NSRect) {
        let thickness: CGFloat = 4
        let knob: CGFloat = 16
        if vertical {
            let x = bounds.midX
            let top = knob / 2, bottom = bounds.height - knob / 2
            let track = NSRect(x: x - thickness / 2, y: top, width: thickness, height: bottom - top)
            Fluent.fill(track, radius: thickness / 2, color: Fluent.trackFill)
            // Vertical sliders in Paint grow upwards.
            let knobY = bottom - fraction * (bottom - top)
            let filled = NSRect(x: track.minX, y: knobY, width: thickness, height: track.maxY - knobY)
            Fluent.fill(filled, radius: thickness / 2, color: Fluent.accent)
            drawKnob(at: NSPoint(x: x, y: knobY), size: knob)
        } else {
            let y = bounds.midY
            let left = knob / 2, right = bounds.width - knob / 2
            let track = NSRect(x: left, y: y - thickness / 2, width: right - left, height: thickness)
            Fluent.fill(track, radius: thickness / 2, color: Fluent.trackFill)
            let knobX = left + fraction * (right - left)
            let filled = NSRect(x: left, y: track.minY, width: knobX - left, height: thickness)
            Fluent.fill(filled, radius: thickness / 2, color: Fluent.accent)
            drawKnob(at: NSPoint(x: knobX, y: y), size: knob)
        }
    }

    private func drawKnob(at point: NSPoint, size: CGFloat) {
        let outer = NSRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: outer).fill()
        Fluent.color(0x000000, 0.18).setStroke()
        let ring = NSBezierPath(ovalIn: outer.insetBy(dx: 0.5, dy: 0.5))
        ring.lineWidth = 1
        ring.stroke()
        let inner = outer.insetBy(dx: size * 0.3, dy: size * 0.3)
        Fluent.accent.setFill()
        NSBezierPath(ovalIn: inner).fill()
    }

    private func update(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let knob: CGFloat = 16
        var f: CGFloat
        if vertical {
            let top = knob / 2, bottom = bounds.height - knob / 2
            f = bottom - top > 0 ? (bottom - point.y) / (bottom - top) : 0
        } else {
            let left = knob / 2, right = bounds.width - knob / 2
            f = right - left > 0 ? (point.x - left) / (right - left) : 0
        }
        f = Swift.max(0, Swift.min(1, f))
        value = minValue + Double(f) * (maxValue - minValue)
        onChange?(value)
    }
    override func mouseDown(with event: NSEvent) { dragging = true; update(event) }
    override func mouseDragged(with event: NSEvent) { if dragging { update(event) } }
    override func mouseUp(with event: NSEvent) { dragging = false }
}

// MARK: - Containers

// A ribbon group: children laid out by the owner, caption centred underneath,
// and a hairline separator on the trailing edge.
final class RibbonGroup: NSView {
    var caption: String = ""
    var showsSeparator = true
    override var isFlipped: Bool { true }

    convenience init(caption: String) {
        self.init(frame: .zero)
        self.caption = caption
    }
    override func draw(_ dirtyRect: NSRect) {
        if !caption.isEmpty {
            Fluent.text(caption, in: NSRect(x: 0, y: bounds.maxY - 19, width: bounds.width, height: 16),
                        font: Fluent.ui(11.5), color: Fluent.caption)
        }
        if showsSeparator {
            Fluent.divider.setFill()
            NSRect(x: bounds.maxX - 1, y: 8, width: 1, height: bounds.height - 16).fill()
        }
    }
}

final class FlippedView: NSView {
    var background: NSColor?
    var bottomBorder: NSColor?
    var topBorder: NSColor?
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        if let background { background.setFill(); bounds.fill() }
        if let topBorder { topBorder.setFill(); NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill() }
        if let bottomBorder {
            bottomBorder.setFill()
            NSRect(x: 0, y: bounds.maxY - 1, width: bounds.width, height: 1).fill()
        }
    }
}

// Rounded white card with a hairline border, used for the shape gallery and
// the floating slider panel.
final class CardView: NSView {
    var radius: CGFloat = 7
    var fillColor = Fluent.chrome
    var borderColor = Fluent.fieldBorder
    var dropsShadow = false
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        if dropsShadow {
            NSGraphicsContext.saveGraphicsState()
            let shade = NSShadow()
            shade.shadowColor = Fluent.shadow
            shade.shadowBlurRadius = 6
            shade.shadowOffset = NSSize(width: 0, height: -1)
            shade.set()
            Fluent.fill(bounds.insetBy(dx: 1, dy: 1), radius: radius, color: fillColor)
            NSGraphicsContext.restoreGraphicsState()
        } else {
            Fluent.fill(bounds, radius: radius, color: fillColor)
        }
        Fluent.stroke(bounds, radius: radius, color: borderColor)
    }
}
