import AppKit

// Chrome used by the Windows 10 / Windows 7 ribbon skins and by the
// Windows XP classic skin.

// MARK: - Ribbon tab strip (Windows 10 / Windows 7)

final class TabStrip: NSView {
    var tabs: [String] = ["常用", "檢視"]
    var activeIndex = 0
    var onSelect: ((Int) -> Void)?
    var onFile: (() -> Void)?
    private var hoverIndex = -1
    private let fileWidth: CGFloat = 54
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
        if Fluent.skin == .win7 {
            NSBezierPath(roundedRect: file.insetBy(dx: 2, dy: 2), xRadius: 3, yRadius: 3).fill()
        } else {
            file.fill()
        }
        Fluent.text("檔案", in: file, font: Fluent.ui(13), color: .white)
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
    var onSelect: ((PaintTool) -> Void)?
    var onWidth: ((CGFloat) -> Void)?
    var activeTool: PaintTool = .pencil { didSet { needsDisplay = true } }
    var activeWidth: CGFloat = 3 { didSet { needsDisplay = true } }

    // Classic Paint toolbox order. The first slot is free-form select, which
    // this build does not implement, so it is shown disabled.
    static let slots: [PaintTool?] = [
        nil, .select,
        .eraser, .fill,
        .picker, .magnifier,
        .pencil, .brush,
        .spray, .text,
        .line, .curve,
        .rectangle, .polygon,
        .ellipse, .rounded
    ]
    static let widths: [CGFloat] = [1, 2, 3, 5, 8]
    static let cell = NSSize(width: 25, height: 24)
    static let preferredWidth: CGFloat = 56
    static var gridHeight: CGFloat { cell.height * 8 + 4 }

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let disabled = RibbonButton(.freeSelect, kind: .grid,
                                    width: ToolboxView.cell.width, height: ToolboxView.cell.height)
        disabled.glyphSize = 16
        disabled.isEnabledControl = false
        disabled.toolTip = "任意選取（此版本尚未實作）"
        addSubview(disabled)
        for slot in ToolboxView.slots {
            guard let tool = slot else { continue }
            let button = RibbonButton(tool.glyph, kind: .grid,
                                      width: ToolboxView.cell.width, height: ToolboxView.cell.height)
            button.glyphSize = 16
            button.toolTip = tool.rawValue
            button.onClick = { [weak self] in self?.onSelect?(tool) }
            buttons[tool] = button
            addSubview(button)
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        var disabledPlaced = false
        for (index, slot) in ToolboxView.slots.enumerated() {
            let origin = NSPoint(x: 3 + CGFloat(index % 2) * ToolboxView.cell.width,
                                 y: 2 + CGFloat(index / 2) * ToolboxView.cell.height)
            if let tool = slot {
                buttons[tool]?.setFrameOrigin(origin)
            } else if !disabledPlaced {
                disabledPlaced = true
                subviews.first?.setFrameOrigin(origin)
            }
        }
    }

    func select(_ tool: PaintTool) {
        activeTool = tool
        for (candidate, button) in buttons { button.isChecked = candidate == tool }
    }

    private var optionsRect: NSRect {
        NSRect(x: 3, y: ToolboxView.gridHeight + 6,
               width: ToolboxView.cell.width * 2, height: 74)
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let box = optionsRect
        guard activeTool.usesSize, box.contains(point) else { return }
        let row = Int((point.y - box.minY - 4) / 14)
        guard row >= 0, row < ToolboxView.widths.count else { return }
        activeWidth = ToolboxView.widths[row]
        onWidth?(activeWidth)
    }

    override func draw(_ dirtyRect: NSRect) {
        Fluent.chrome.setFill()
        bounds.fill()
        let box = optionsRect
        guard activeTool.usesSize else { return }
        Fluent.color(0xFFFFFF).setFill()
        box.fill()
        Fluent.bevel(box, raised: false)
        for (index, width) in ToolboxView.widths.enumerated() {
            let row = NSRect(x: box.minX + 2, y: box.minY + 4 + CGFloat(index) * 14,
                             width: box.width - 4, height: 13)
            if abs(width - activeWidth) < 0.01 {
                Fluent.color(0x316AC5).setFill()
                row.fill()
                NSColor.white.setFill()
            } else {
                NSColor.black.setFill()
            }
            NSRect(x: row.minX + 5, y: row.midY - width / 2, width: row.width - 10, height: width).fill()
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
