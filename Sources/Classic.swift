import AppKit

// Chrome used by the Windows 10 / Windows 7 ribbon skins and by the
// Windows XP classic skin.

// MARK: - Ribbon tab strip (Windows 10 / Windows 7)

final class TabStrip: NSView {
    var tabs: [String] = ["常用", "檢視"]
    var activeIndex = 0
    var paintButton = false
    var onSelect: ((Int) -> Void)?
    var onFile: (() -> Void)?
    private var hoverIndex = -1
    private var fileWidth: CGFloat { paintButton ? 46 : 54 }
    private let tabWidth: CGFloat = 62

    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp, .inVisibleRect],
                                       owner: self))
    }
    private func index(at point: NSPoint) -> Int {
        if point.x < fileWidth { return -1 }
        let offset = Int((point.x - fileWidth) / tabWidth)
        return offset >= 0 && offset < tabs.count ? offset : -2
    }
    override func mouseMoved(with event: NSEvent) {
        hoverIndex = index(at: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }
    override func mouseExited(with event: NSEvent) { hoverIndex = -2; needsDisplay = true }
    override func mouseUp(with event: NSEvent) {
        let target = index(at: convert(event.locationInWindow, from: nil))
        if target == -1 { onFile?() } else if target >= 0 { activeIndex = target; onSelect?(target); needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        let tokens = Fluent.t
        Fluent.gradient(bounds, tokens.tabBar, tokens.tabBar)
        // File tab.
        let file = NSRect(x: 0, y: 0, width: fileWidth, height: bounds.height)
        tokens.fileTab.setFill()
        if paintButton {
            let button = file.insetBy(dx: 4, dy: 3)
            NSBezierPath(roundedRect: button, xRadius: 3, yRadius: 3).fill()
            let mark = NSRect(x: button.midX - 8, y: button.midY - 7, width: 16, height: 14)
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: mark.minX, y: mark.minY + 2, width: 8, height: 8)).fill()
            NSColor(srgbRed: 0.95, green: 0.75, blue: 0.2, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: mark.midX - 2, y: mark.minY, width: 7, height: 7)).fill()
            NSColor(srgbRed: 0.35, green: 0.7, blue: 0.95, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: mark.maxX - 7, y: mark.maxY - 8, width: 6, height: 6)).fill()
        } else if Fluent.skin == .win7 {
            NSBezierPath(roundedRect: file.insetBy(dx: 2, dy: 2), xRadius: 3, yRadius: 3).fill()
            Fluent.text("檔案", in: file, font: Fluent.ui(13), color: .white)
        } else {
            file.fill()
            Fluent.text("檔案", in: file, font: Fluent.ui(13), color: .white)
        }
        // Regular tabs.
        for (index, title) in tabs.enumerated() {
            let rect = NSRect(x: fileWidth + CGFloat(index) * tabWidth, y: 0,
                              width: tabWidth, height: bounds.height)
            if index == activeIndex {
                tokens.tabActive.setFill()
                if Fluent.skin == .win7 {
                    let path = NSBezierPath(roundedRect: NSRect(x: rect.minX, y: rect.minY + 2,
                                                                width: rect.width, height: rect.height),
                                            xRadius: 4, yRadius: 4)
                    path.fill()
                    tokens.chromeBorder.setStroke()
                    path.lineWidth = 1
                    path.stroke()
                } else {
                    rect.fill()
                }
            } else if index == hoverIndex {
                Fluent.hoverFill.setFill()
                rect.insetBy(dx: 1, dy: 2).fill()
            }
            Fluent.text(title, in: rect, font: Fluent.ui(13), color: tokens.tabInactiveInk)
        }
        // Hairline under the inactive part of the strip.
        tokens.chromeBorder.setFill()
        NSRect(x: 0, y: bounds.maxY - 1, width: bounds.width, height: 1).fill()
    }
}

// MARK: - Windows XP toolbox

final class ToolboxView: NSView {
    private(set) var buttons: [PaintTool: RibbonButton] = [:]
    private let freeButton: RibbonButton
    var onSelect: ((PaintTool, Bool) -> Void)?
    var onWidth: ((CGFloat) -> Void)?
    var onZoom: ((CGFloat) -> Void)?
    var onShapeStyle: ((Int) -> Void)?
    var onTransparent: ((Bool) -> Void)?
    var onBrushTip: ((Int, CGFloat) -> Void)?
    var activeTool: PaintTool = .pencil { didSet { needsDisplay = true } }
    var freeActive = false { didSet { needsDisplay = true } }
    var activeWidth: CGFloat = 3 { didSet { needsDisplay = true } }
    var shapeStyle = 0 { didSet { needsDisplay = true } }
    var transparent = false { didSet { needsDisplay = true } }
    var brushTip = 0 { didSet { needsDisplay = true } }
    var zoomLevel: CGFloat = 1 { didSet { needsDisplay = true } }

    // Classic Paint toolbox order, including free-form select.
    static let slots: [PaintTool] = [
        .select, .select,
        .eraser, .fill,
        .picker, .magnifier,
        .pencil, .brush,
        .spray, .text,
        .line, .curve,
        .rectangle, .polygon,
        .ellipse, .rounded
    ]
    static let cell = NSSize(width: 25, height: 24)
    static let preferredWidth: CGFloat = 56
    static var gridHeight: CGFloat { cell.height * 8 + 4 }

    private enum OptionKind {
        case none, widths, eraser, spray, zoom, shapes, transparency, tips
    }

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        freeButton = RibbonButton(.freeSelect, kind: .grid,
                                  width: ToolboxView.cell.width, height: ToolboxView.cell.height)
        super.init(frame: frameRect)
        freeButton.glyphSize = 16
        freeButton.toolTip = "任意選取"
        freeButton.onClick = { [weak self] in self?.onSelect?(.select, true) }
        addSubview(freeButton)
        for tool in Set(ToolboxView.slots) {
            let button = RibbonButton(tool.glyph, kind: .grid,
                                      width: ToolboxView.cell.width, height: ToolboxView.cell.height)
            button.glyphSize = 16
            button.toolTip = tool.rawValue
            button.onClick = { [weak self] in self?.onSelect?(tool, false) }
            buttons[tool] = button
            addSubview(button)
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        var rectPlaced = false
        for (index, tool) in ToolboxView.slots.enumerated() {
            let origin = NSPoint(x: 3 + CGFloat(index % 2) * ToolboxView.cell.width,
                                 y: 2 + CGFloat(index / 2) * ToolboxView.cell.height)
            if index == 0 { freeButton.setFrameOrigin(origin); continue }
            if tool == .select {
                if rectPlaced { continue }
                rectPlaced = true
            }
            buttons[tool]?.setFrameOrigin(origin)
        }
    }

    func select(_ tool: PaintTool, free: Bool) {
        activeTool = tool
        freeActive = free && tool == .select
        freeButton.isChecked = freeActive
        for (candidate, button) in buttons {
            button.isChecked = candidate == tool && !(candidate == .select && freeActive)
        }
    }

    private var optionsRect: NSRect {
        NSRect(x: 3, y: ToolboxView.gridHeight + 6,
               width: ToolboxView.cell.width * 2, height: 74)
    }

    private var optionKind: OptionKind {
        switch activeTool {
        case .select, .text: return .transparency
        case .eraser: return .eraser
        case .magnifier: return .zoom
        case .brush: return .tips
        case .spray: return .spray
        case .line, .curve: return .widths
        case .rectangle, .polygon, .ellipse, .rounded: return .shapes
        default: return .none
        }
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let box = optionsRect
        guard box.contains(point) else { return }
        switch optionKind {
        case .widths:
            let widths: [CGFloat] = [1, 2, 3, 5, 8]
            let row = Int((point.y - box.minY - 4) / 14)
            guard widths.indices.contains(row) else { return }
            activeWidth = widths[row]; onWidth?(activeWidth)
        case .eraser:
            let sizes: [CGFloat] = [4, 8, 12, 16]
            let row = Int((point.y - box.minY - 6) / 16)
            guard sizes.indices.contains(row) else { return }
            activeWidth = sizes[row]; onWidth?(activeWidth)
        case .spray:
            let sizes: [CGFloat] = [4, 10, 18]
            let row = Int((point.y - box.minY - 4) / 22)
            guard sizes.indices.contains(row) else { return }
            activeWidth = sizes[row]; onWidth?(activeWidth)
        case .zoom:
            let levels: [CGFloat] = [1, 2, 6, 8]
            let column = point.x < box.midX ? 0 : 1
            let row = point.y < box.midY ? 0 : 1
            let level = levels[row * 2 + column]
            zoomLevel = level; onZoom?(level)
        case .shapes:
            let row = Int((point.y - box.minY) / (box.height / 3))
            let styles = [0, 2, 1]
            guard styles.indices.contains(row) else { return }
            shapeStyle = styles[row]; onShapeStyle?(shapeStyle)
        case .transparency:
            transparent = point.x >= box.midX
            onTransparent?(transparent)
        case .tips:
            let column = min(3, max(0, Int((point.x - box.minX) / (box.width / 4))))
            let row = min(2, max(0, Int((point.y - box.minY) / (box.height / 3))))
            brushTip = row * 4 + column
            let width: CGFloat = [3, 7, 12][row]
            activeWidth = width
            onBrushTip?(brushTip, width)
        case .none:
            break
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        Fluent.chrome.setFill()
        bounds.fill()
        let box = optionsRect
        Fluent.color(0xFFFFFF).setFill()
        box.fill()
        Fluent.bevel(box, raised: false)
        switch optionKind {
        case .none:
            break
        case .widths:
            for (index, width) in [CGFloat(1), 2, 3, 5, 8].enumerated() {
                let row = NSRect(x: box.minX + 2, y: box.minY + 4 + CGFloat(index) * 14, width: box.width - 4, height: 13)
                let selected = abs(width - activeWidth) < 0.01
                if selected { Fluent.color(0x316AC5).setFill(); row.fill() }
                (selected ? NSColor.white : NSColor.black).setFill()
                NSRect(x: row.minX + 5, y: row.midY - width / 2, width: row.width - 10, height: width).fill()
            }
        case .eraser:
            for (index, width) in [CGFloat(4), 8, 12, 16].enumerated() {
                let row = NSRect(x: box.minX + 4, y: box.minY + 6 + CGFloat(index) * 16, width: box.width - 8, height: 15)
                let selected = abs(width - activeWidth) < 0.01
                if selected { Fluent.color(0x316AC5).setFill(); row.fill() }
                (selected ? NSColor.white : NSColor.black).setFill()
                let side = 3 + CGFloat(index) * 2
                NSRect(x: row.midX - side / 2, y: row.midY - side / 2, width: side, height: side).fill()
            }
        case .spray:
            for (index, width) in [CGFloat(4), 10, 18].enumerated() {
                let row = NSRect(x: box.minX + 4, y: box.minY + 4 + CGFloat(index) * 22, width: box.width - 8, height: 20)
                if abs(width - activeWidth) < 0.01 { Fluent.color(0x316AC5).setFill(); row.fill(); NSColor.white.setFill() }
                else { NSColor.black.setFill() }
                let dots = 3 + index * 3
                for dot in 0..<dots {
                    let angle = CGFloat(dot) / CGFloat(dots) * .pi * 2
                    let radius = 2 + CGFloat(index) * 2
                    NSBezierPath(ovalIn: NSRect(x: row.midX + cos(angle) * radius - 1, y: row.midY + sin(angle) * radius - 1, width: 2, height: 2)).fill()
                }
            }
        case .zoom:
            let levels = ["1x", "2x", "6x", "8x"]
            let values: [CGFloat] = [1, 2, 6, 8]
            for index in 0..<4 {
                let rect = NSRect(x: box.minX + CGFloat(index % 2) * box.width / 2,
                                  y: box.minY + CGFloat(index / 2) * box.height / 2,
                                  width: box.width / 2, height: box.height / 2).insetBy(dx: 2, dy: 2)
                if values[index] == zoomLevel { Fluent.color(0x316AC5).setFill(); rect.fill() }
                Fluent.bevel(rect, raised: values[index] != zoomLevel, thin: true)
                Fluent.text(levels[index], in: rect, font: Fluent.ui(11),
                            color: values[index] == zoomLevel ? .white : .black)
            }
        case .shapes:
            let styles = [0, 2, 1]
            for (index, style) in styles.enumerated() {
                let row = NSRect(x: box.minX + 3, y: box.minY + 3 + CGFloat(index) * (box.height - 6) / 3,
                                 width: box.width - 6, height: (box.height - 6) / 3 - 2)
                if style == shapeStyle { Fluent.color(0x316AC5).setFill(); row.fill() }
                let mark = row.insetBy(dx: 8, dy: 3)
                let ink: NSColor = style == shapeStyle ? .white : .black
                if style != 1 {
                    ink.setStroke()
                    let path = NSBezierPath(rect: mark.insetBy(dx: 0.5, dy: 0.5))
                    path.lineWidth = 1
                    path.stroke()
                }
                if style != 0 {
                    ink.setFill()
                    mark.insetBy(dx: style == 1 ? 0 : 2, dy: style == 1 ? 0 : 2).fill()
                }
            }
        case .transparency:
            for (index, title) in ["不透明", "透明"].enumerated() {
                let rect = NSRect(x: box.minX + CGFloat(index) * box.width / 2, y: box.minY,
                                  width: box.width / 2, height: box.height).insetBy(dx: 3, dy: 8)
                let selected = (index == 1) == transparent
                if selected { Fluent.color(0x316AC5).setFill(); rect.fill() }
                Fluent.bevel(rect, raised: !selected, thin: true)
                Fluent.text(title, in: rect, font: Fluent.ui(10), color: selected ? .white : .black)
            }
        case .tips:
            for index in 0..<12 {
                let rect = NSRect(x: box.minX + CGFloat(index % 4) * box.width / 4,
                                  y: box.minY + CGFloat(index / 4) * box.height / 3,
                                  width: box.width / 4, height: box.height / 3)
                if index == brushTip { Fluent.color(0x316AC5).setFill(); rect.fill() }
                let ink: NSColor = index == brushTip ? .white : .black
                ink.setFill()
                let mark = rect.insetBy(dx: 4, dy: 4)
                let column = index % 4
                if column == 0 { NSBezierPath(ovalIn: mark).fill() }
                else if column == 1 { mark.fill() }
                else {
                    ink.setStroke()
                    let path = NSBezierPath()
                    if column == 2 { path.move(to: NSPoint(x: mark.minX, y: mark.maxY)); path.line(to: NSPoint(x: mark.maxX, y: mark.minY)) }
                    else { path.move(to: NSPoint(x: mark.minX, y: mark.minY)); path.line(to: NSPoint(x: mark.maxX, y: mark.maxY)) }
                    path.lineWidth = 1 + CGFloat(index / 4)
                    path.stroke()
                }
            }
        }
    }
}

// MARK: - Windows XP palette

final class ClassicPalette: NSView {
    // The 28 colours shipped with classic Microsoft Paint.
    static let colors: [UInt32] = [
        0x000000, 0x808080, 0x800000, 0x808000, 0x008000, 0x008080, 0x000080,
        0x800080, 0x808040, 0x004040, 0x0080FF, 0x004080, 0x8000FF, 0x804000,
        0xFFFFFF, 0xC0C0C0, 0xFF0000, 0xFFFF00, 0x00FF00, 0x00FFFF, 0x0000FF,
        0xFF00FF, 0xFFFF80, 0x00FF80, 0x80FFFF, 0x8080FF, 0xFF0080, 0xFF8040
    ]
    static let swatch: CGFloat = 16
    static let preferredHeight: CGFloat = 46

    var primary = NSColor.black { didSet { needsDisplay = true } }
    var secondary = NSColor.white { didSet { needsDisplay = true } }
    var onPick: ((NSColor, Bool) -> Void)?
    var onEdit: (() -> Void)?

    override var isFlipped: Bool { true }

    private let gridOrigin = NSPoint(x: 44, y: 7)

    private func index(at point: NSPoint) -> Int? {
        let column = Int((point.x - gridOrigin.x) / ClassicPalette.swatch)
        let row = Int((point.y - gridOrigin.y) / ClassicPalette.swatch)
        guard column >= 0, column < 14, row >= 0, row < 2 else { return nil }
        let index = row * 14 + column
        return index < ClassicPalette.colors.count ? index : nil
    }
    private func pick(_ event: NSEvent, secondarySlot: Bool) {
        let point = convert(event.locationInWindow, from: nil)
        guard let index = index(at: point) else { return }
        onPick?(Fluent.color(ClassicPalette.colors[index]), secondarySlot)
    }
    override func mouseUp(with event: NSEvent) {
        if event.clickCount >= 2 { onEdit?(); return }
        pick(event, secondarySlot: false)
    }
    override func rightMouseDown(with event: NSEvent) { pick(event, secondarySlot: true) }

    override func draw(_ dirtyRect: NSRect) {
        Fluent.chrome.setFill()
        bounds.fill()
        Fluent.bevel(NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height), raised: true, thin: true)
        // Foreground / background indicator.
        let well = NSRect(x: 3, y: 4, width: 36, height: 34)
        Fluent.color(0xC0C0C0).setFill()
        well.fill()
        Fluent.bevel(well, raised: false)
        let back = NSRect(x: well.minX + 14, y: well.minY + 14, width: 16, height: 16)
        secondary.setFill(); back.fill(); Fluent.bevel(back, raised: false, thin: true)
        let front = NSRect(x: well.minX + 5, y: well.minY + 5, width: 16, height: 16)
        primary.setFill(); front.fill(); Fluent.bevel(front, raised: false, thin: true)
        // Swatch grid.
        for (index, hex) in ClassicPalette.colors.enumerated() {
            let column = index % 14, row = index / 14
            let rect = NSRect(x: gridOrigin.x + CGFloat(column) * ClassicPalette.swatch,
                              y: gridOrigin.y + CGFloat(row) * ClassicPalette.swatch,
                              width: ClassicPalette.swatch, height: ClassicPalette.swatch)
            Fluent.color(hex).setFill()
            rect.insetBy(dx: 2, dy: 2).fill()
            Fluent.bevel(rect.insetBy(dx: 1, dy: 1), raised: false, thin: true)
        }
    }
}

// MARK: - Windows XP menu bar

final class ClassicMenuBar: NSView {
    struct Entry { var title: String; var builder: () -> NSMenu }
    var entries: [Entry] = []
    private var hoverIndex = -1
    private var frames: [NSRect] = []

    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp, .inVisibleRect],
                                       owner: self))
    }
    private func layoutEntries() {
        frames.removeAll()
        var x: CGFloat = 2
        let font = Fluent.ui(12)
        for entry in entries {
            let width = Fluent.width(entry.title, font: font) + 16
            frames.append(NSRect(x: x, y: 1, width: width, height: bounds.height - 2))
            x += width
        }
    }
    private func index(at point: NSPoint) -> Int {
        for (index, rect) in frames.enumerated() where rect.contains(point) { return index }
        return -1
    }
    override func mouseMoved(with event: NSEvent) {
        hoverIndex = index(at: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }
    override func mouseExited(with event: NSEvent) { hoverIndex = -1; needsDisplay = true }
    override func mouseDown(with event: NSEvent) {
        let target = index(at: convert(event.locationInWindow, from: nil))
        guard target >= 0, target < entries.count else { return }
        let menu = entries[target].builder()
        menu.popUp(positioning: nil, at: NSPoint(x: frames[target].minX, y: bounds.maxY), in: self)
    }

    override func draw(_ dirtyRect: NSRect) {
        Fluent.chrome.setFill()
        bounds.fill()
        layoutEntries()
        let font = Fluent.ui(12)
        for (index, entry) in entries.enumerated() {
            let rect = frames[index]
            if index == hoverIndex {
                Fluent.color(0x316AC5).setFill()
                rect.fill()
            }
            Fluent.text(entry.title, in: rect, font: font,
                        color: index == hoverIndex ? .white : Fluent.ink)
        }
    }
}

// MARK: - Windows XP status bar

final class ClassicStatusBar: NSView {
    var hint = "如需說明，請按一下「說明」功能表中的「說明主題」。"
    var cursorText = ""
    var canvasText = ""

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        Fluent.chrome.setFill()
        bounds.fill()
        let font = Fluent.ui(11.5)
        let panes: [(NSRect, String)] = [
            (NSRect(x: 1, y: 1, width: max(40, bounds.width - 220), height: bounds.height - 2), hint),
            (NSRect(x: bounds.width - 218, y: 1, width: 108, height: bounds.height - 2), cursorText),
            (NSRect(x: bounds.width - 108, y: 1, width: 106, height: bounds.height - 2), canvasText)
        ]
        for (rect, text) in panes {
            Fluent.bevel(rect, raised: false, thin: true)
            Fluent.text(text, in: rect.insetBy(dx: 5, dy: 0), font: font,
                        color: Fluent.ink, alignment: .left)
        }
    }
}
