import AppKit

// Composite chrome pieces that mirror the Windows 11 Paint toolbar.

final class LayoutView: NSView {
    var background: NSColor?
    var onLayout: (() -> Void)?
    override var isFlipped: Bool { true }
    override func layout() {
        super.layout()
        onLayout?()
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let background else { return }
        background.setFill()
        bounds.fill()
    }
}

// The scrollable shape picker shown inside the 形狀 group.
final class ShapeGallery: NSView {
    private let scroll = NSScrollView()
    private let content = LayoutView()
    private(set) var buttons: [PaintTool: RibbonButton] = [:]
    var onSelect: ((PaintTool) -> Void)?
    let columns = 5
    let cell: CGFloat = 26

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let tools = PaintTool.shapes
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.scrollerStyle = .overlay
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        content.background = nil
        for tool in tools {
            let button = RibbonButton(tool.glyph, kind: .grid, width: cell, height: cell)
            button.glyphSize = 15
            button.toolTip = tool.rawValue
            button.onClick = { [weak self] in self?.onSelect?(tool) }
            buttons[tool] = button
            content.addSubview(button)
        }
        content.onLayout = { [weak self] in self?.layoutCells() }
        scroll.documentView = content
        addSubview(scroll)
    }
    required init?(coder: NSCoder) { fatalError() }

    var orderedTools: [PaintTool] { PaintTool.shapes.filter { buttons[$0] != nil } }

    private func layoutCells() {
        let tools = orderedTools
        for (index, tool) in tools.enumerated() {
            let row = index / columns, column = index % columns
            buttons[tool]?.setFrameOrigin(NSPoint(x: CGFloat(column) * cell + 3,
                                                  y: CGFloat(row) * cell + 3))
        }
    }

    override func layout() {
        super.layout()
        scroll.frame = bounds.insetBy(dx: 1, dy: 1)
        let rows = (orderedTools.count + columns - 1) / columns
        content.setFrameSize(NSSize(width: scroll.contentSize.width,
                                    height: CGFloat(rows) * cell + 6))
        content.needsLayout = true
        layoutCells()
    }

    override func draw(_ dirtyRect: NSRect) {
        Fluent.fill(bounds, radius: 6, color: Fluent.chrome)
        Fluent.stroke(bounds, radius: 6, color: Fluent.fieldBorder)
    }

    func select(_ tool: PaintTool) {
        for (candidate, button) in buttons { button.isChecked = candidate == tool }
    }
}

// 色彩 group: colour 1 / colour 2 wells, the standard palette and recent slots.
final class ColorGroup: NSView {
    private(set) var primaryWell = ColorDot(.black, diameter: 34)
    private(set) var secondaryWell = ColorDot(.white, diameter: 28)
    private(set) var recent: [ColorDot] = []
    private var swatches: [ColorDot] = []
    let editButton = RibbonButton(nil, kind: .grid, width: 36, height: 36)
    var onPick: ((NSColor, Bool) -> Void)?
    var onSelectWell: ((Bool) -> Void)?

    static let standard: [UInt32] = [
        0x000000, 0x7F7F7F, 0x880015, 0xED1C24, 0xFF7F27, 0xFFF200, 0x22B14C, 0x00A2E8, 0x3F48CC, 0xA349A4,
        0xFFFFFF, 0xC3C3C3, 0xB97A57, 0xFFAEC9, 0xFFC90E, 0xEFE4B0, 0xB5E61D, 0x99D9EA, 0x7092BE, 0xC8BFE7
    ]

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        primaryWell.isChecked = true
        primaryWell.toolTip = "色彩 1（前景）"
        secondaryWell.toolTip = "色彩 2（背景）"
        primaryWell.onPick = { [weak self] _, _ in self?.onSelectWell?(true) }
        secondaryWell.onPick = { [weak self] _, _ in self?.onSelectWell?(false) }
        addSubview(primaryWell)
        addSubview(secondaryWell)
        for hex in ColorGroup.standard {
            let dot = ColorDot(Fluent.color(hex), diameter: 21)
            dot.onPick = { [weak self] color, secondary in self?.onPick?(color, secondary) }
            swatches.append(dot)
            addSubview(dot)
        }
        for _ in 0..<10 {
            let dot = ColorDot(.clear, diameter: 21, empty: true)
            dot.onPick = { [weak self] color, secondary in
                guard !dot.isEmptySlot else { return }
                self?.onPick?(color, secondary)
            }
            recent.append(dot)
            addSubview(dot)
        }
        editButton.toolTip = "編輯色彩"
        addSubview(editButton)
    }
    required init?(coder: NSCoder) { fatalError() }

    func remember(_ color: NSColor) {
        guard !ColorGroup.standard.contains(where: { Fluent.color($0).rgba == color.rgba }) else { return }
        if let existing = recent.firstIndex(where: { !$0.isEmptySlot && $0.color.rgba == color.rgba }) {
            recent.remove(at: existing).removeFromSuperview()
        } else if let last = recent.last {
            recent.removeLast()
            last.removeFromSuperview()
        }
        let dot = ColorDot(color, diameter: 21)
        dot.onPick = { [weak self] color, secondary in self?.onPick?(color, secondary) }
        addSubview(dot)
        recent.insert(dot, at: 0)
        while recent.count > 10 {
            recent.removeLast().removeFromSuperview()
        }
        needsLayout = true
        layoutContents()
    }

    func layoutContents() {
        let step: CGFloat = 22
        primaryWell.setFrameOrigin(NSPoint(x: 2, y: 2))
        secondaryWell.setFrameOrigin(NSPoint(x: 5, y: 44))
        let gridX: CGFloat = 42
        for (index, dot) in swatches.enumerated() {
            let row = index / 10, column = index % 10
            dot.setFrameOrigin(NSPoint(x: gridX + CGFloat(column) * step, y: 3 + CGFloat(row) * step))
        }
        for (index, dot) in recent.enumerated() {
            dot.setFrameOrigin(NSPoint(x: gridX + CGFloat(index) * step, y: 3 + 2 * step))
        }
        editButton.setFrameOrigin(NSPoint(x: gridX + 10 * step + 6, y: 16))
    }

    override func layout() {
        super.layout()
        layoutContents()
    }

    static var intrinsicWidth: CGFloat { 42 + 10 * 22 + 6 + 36 }

    func draw(wheelIn rect: NSRect) {
        let segments = 36
        for i in 0..<segments {
            let start = CGFloat(i) / CGFloat(segments) * 360
            let path = NSBezierPath()
            path.move(to: NSPoint(x: rect.midX, y: rect.midY))
            path.appendArc(withCenter: NSPoint(x: rect.midX, y: rect.midY),
                           radius: rect.width / 2,
                           startAngle: start, endAngle: start + 11)
            path.close()
            NSColor(calibratedHue: CGFloat(i) / CGFloat(segments), saturation: 0.85,
                    brightness: 1, alpha: 1).setFill()
            path.fill()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let wheel = NSRect(x: editButton.frame.minX + 4, y: editButton.frame.minY + 4,
                           width: 24, height: 24)
        draw(wheelIn: wheel)
        Fluent.color(0x000000, 0.18).setStroke()
        let ring = NSBezierPath(ovalIn: wheel)
        ring.lineWidth = 1
        ring.stroke()
        let badge = NSRect(x: wheel.maxX - 9, y: wheel.minY - 2, width: 12, height: 12)
        Fluent.chrome.setFill()
        NSBezierPath(ovalIn: badge.insetBy(dx: -1, dy: -1)).fill()
        Fluent.accent.setFill()
        NSBezierPath(ovalIn: badge).fill()
        GlyphPainter.draw(.plus, in: badge.insetBy(dx: 2.5, dy: 2.5), tint: .white, accent: .white)
    }
}

// Floating size / opacity sliders pinned to the left edge of the canvas area.
final class SliderDock: NSView {
    let sizeCard = CardView()
    let opacityCard = CardView()
    let sizeSlider = FluentSlider(vertical: true, min: 1, max: 100, value: 8)
    let opacitySlider = FluentSlider(vertical: true, min: 1, max: 100, value: 100)

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        for card in [sizeCard, opacityCard] {
            card.radius = 18
            card.dropsShadow = true
            addSubview(card)
        }
        sizeCard.addSubview(sizeSlider)
        opacityCard.addSubview(opacitySlider)
        sizeCard.toolTip = "大小"
        opacityCard.toolTip = "不透明度"
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let cardWidth: CGFloat = 36
        sizeCard.frame = NSRect(x: 0, y: 0, width: cardWidth, height: bounds.height)
        opacityCard.frame = NSRect(x: cardWidth + 8, y: 0, width: cardWidth, height: bounds.height)
        for (card, slider) in [(sizeCard, sizeSlider), (opacityCard, opacitySlider)] {
            slider.frame = NSRect(x: 0, y: 30, width: cardWidth, height: card.bounds.height - 42)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        GlyphPainter.draw(.thickness, in: NSRect(x: 9, y: 10, width: 18, height: 18))
        GlyphPainter.draw(.opacity, in: NSRect(x: 53, y: 10, width: 18, height: 18))
    }

    static let preferredWidth: CGFloat = 80
}

// The Win11 status bar: pointer position, selection size, canvas size and zoom.
final class StatusBarView: NSView {
    var cursorText = "0, 0 像素"
    var selectionText = "—"
    var canvasText = "1000 × 700 像素"
    var zoomText = "100%"

    let fitButton = RibbonButton(.fitWindow, kind: .grid, width: 26, height: 22)
    let gridButton = RibbonButton(.grid, kind: .grid, width: 26, height: 22)
    let zoomOut = RibbonButton(.zoomOut, kind: .grid, width: 26, height: 22)
    let zoomIn = RibbonButton(.zoomIn, kind: .grid, width: 26, height: 22)
    let zoomSlider = FluentSlider(vertical: false, min: 10, max: 800, value: 100)
    let zoomPopup = RibbonButton(nil, caption: "100%", kind: .text, chevron: true, width: 66, height: 22)

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        for view in [fitButton, gridButton, zoomOut, zoomIn, zoomPopup] { addSubview(view) }
        addSubview(zoomSlider)
        fitButton.toolTip = "符合視窗"
        gridButton.toolTip = "格線"
        zoomOut.toolTip = "縮小"
        zoomIn.toolTip = "放大"
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        var x = bounds.width - 10
        func place(_ view: NSView, _ width: CGFloat, _ height: CGFloat) {
            x -= width
            view.frame = NSRect(x: x, y: ((bounds.height - height) / 2).rounded(),
                                width: width, height: height)
            x -= 4
        }
        place(zoomIn, 26, 22)
        place(zoomSlider, 112, 18)
        place(zoomOut, 26, 22)
        place(zoomPopup, 66, 22)
        place(gridButton, 26, 22)
        place(fitButton, 26, 22)
    }

    override func draw(_ dirtyRect: NSRect) {
        Fluent.statusFill.setFill()
        bounds.fill()
        Fluent.chromeBorder.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
        let font = Fluent.ui(11.5)
        var x: CGFloat = 12
        func segment(_ glyph: Glyph, _ text: String) {
            GlyphPainter.draw(glyph, in: NSRect(x: x, y: (bounds.height - 13) / 2, width: 13, height: 13),
                              tint: Fluent.inkSoft, accent: Fluent.inkSoft)
            x += 18
            let width = Fluent.width(text, font: font)
            Fluent.text(text, in: NSRect(x: x, y: 0, width: width + 4, height: bounds.height),
                        font: font, color: Fluent.ink, alignment: .left)
            x += width + 16
            Fluent.divider.setFill()
            NSRect(x: x - 8, y: 5, width: 1, height: bounds.height - 11).fill()
        }
        segment(.cursor, cursorText)
        segment(.marquee, selectionText)
        segment(.canvasSize, canvasText)
    }
}
