import AppKit
import UniformTypeIdentifiers
import Vision
import CoreImage

final class StageView: NSView { override var isFlipped: Bool { true } }

final class PaintController: NSWindowController, NSWindowDelegate {

    // MARK: Model

    var doc = PaintDocument()
    var canvas: CanvasView!
    var observer: NSObjectProtocol?
    var activeSavePanel: NSSavePanel?
    var editingPrimary = true

    // MARK: Chrome

    let root = LayoutView()
    let menuRow = FlippedView()
    let ribbon = FlippedView()
    let workspace = LayoutView()
    let statusBar = StatusBarView(frame: .zero)
    let scroll = NSScrollView()
    let stage = StageView()
    let dock = SliderDock(frame: .zero)
    let colors = ColorGroup(frame: .zero)
    let gallery = ShapeGallery(frame: .zero)
    let layerPanel = FlippedView()
    let layerStack = LayoutView()
    let layerScroll = NSScrollView()
    let layerOpacity = FluentSlider(vertical: false, min: 0, max: 100, value: 100)
    let tabStrip = TabStrip(frame: .zero)
    let toolbox = ToolboxView(frame: .zero)
    let classicPalette = ClassicPalette(frame: .zero)
    let classicMenu = ClassicMenuBar(frame: .zero)
    let classicStatus = ClassicStatusBar(frame: .zero)
    let textBar = TextFormatBar(frame: .zero)
    let rulerH = RulerView(frame: .zero)
    let rulerV = RulerView(frame: .zero)
    let thumbnail = ThumbnailView(frame: .zero)
    let backdropWell = ColorDot(.white, diameter: 22)
    var ribbonTab = 0
    var showRulers = false
    var showStatus = true
    var showThumbnail = false
    var showToolbox = true
    var showPalette = true
    var showTextBar = false
    var viewingBitmap = false
    var pickingBackdrop = false

    var groups: [RibbonGroup] = []
    var toolButtons: [PaintTool: RibbonButton] = [:]
    var brushButton: RibbonButton!
    var selectButton: RibbonButton!
    var layersButton: RibbonButton!
    var outlineButton: RibbonButton!
    var fillButton: RibbonButton!
    var undoButton: RibbonButton!
    var redoButton: RibbonButton!
    var activeBrush: PaintTool = .brush

    static let ribbonHeight: CGFloat = 104
    static let menuHeight: CGFloat = 40
    static let statusHeight: CGFloat = 28
    static let layerWidth: CGFloat = 236

    // MARK: Setup

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1400, height: 940),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        super.init(window: window)
        if let saved = UserDefaults.standard.string(forKey: "paint.skin"),
           let restored = Skin(rawValue: saved) { Fluent.skin = restored }
        window.title = "未命名 - 小畫家"
        window.minSize = NSSize(width: 1160, height: 700)
        window.appearance = NSAppearance(named: .aqua)
        window.titlebarAppearsTransparent = true
        window.backgroundColor = Fluent.chrome
        window.acceptsMouseMovedEvents = true
        window.delegate = self
        window.center()
        layerPanel.isHidden = true

        canvas = CanvasView(document: doc)
        buildChrome()
        buildMenu()

        canvas.changed = { [weak self] in self?.update() }
        canvas.status = { [weak self] text in
            guard let self else { return }
            self.statusBar.cursorText = text
            self.statusBar.selectionText = self.canvas.selection
                .map { "\(Int($0.width)) × \(Int($0.height)) 像素" } ?? "—"
            self.statusBar.needsDisplay = true
        }
        canvas.picked = { [weak self] color in self?.apply(color: color, secondary: false) }
        canvas.pointer = { [weak self] x, y in
            guard let self else { return }
            self.statusBar.cursorText = "\(x), \(y) 像素"
            self.classicStatus.cursorText = "\(x), \(y)"
            self.statusBar.needsDisplay = true
            self.classicStatus.needsDisplay = true
        }
        canvas.pointerExited = { [weak self] in
            self?.classicStatus.cursorText = ""
            self?.classicStatus.needsDisplay = true
        }
        canvas.textChromeChanged = { [weak self] in self?.syncTextChrome() }
        canvas.consumeClick = { [weak self] in
            guard let self, self.viewingBitmap else { return false }
            self.viewingBitmap = false
            self.layoutChrome()
            return true
        }
        canvas.zoomRequest = { [weak self] zoomIn in
            guard let self else { return }
            self.setZoom(zoomIn ? self.canvas.zoom * 1.5 : self.canvas.zoom / 1.5)
        }
        update()
        selectTool(.brush)
        observer = NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification,
                                                          object: scroll.contentView, queue: .main) { [weak self] _ in
            self?.layoutStage()
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    private func iconButton(_ glyph: Glyph, _ tip: String, _ width: CGFloat = 34,
                            _ height: CGFloat = 30, chevron: Bool = false,
                            action: @escaping () -> Void) -> RibbonButton {
        let button = RibbonButton(glyph, kind: .grid, chevron: chevron, width: width, height: height)
        button.toolTip = tip
        button.onClick = action
        return button
    }

    private func group(_ caption: String, _ width: CGFloat, _ children: [NSView]) -> RibbonGroup {
        let container = RibbonGroup(caption: caption)
        container.setFrameSize(NSSize(width: width, height: PaintController.ribbonHeight))
        for child in children { container.addSubview(child) }
        groups.append(container)
        ribbon.addSubview(container)
        return container
    }

    // MARK: Chrome assembly

    func buildChrome() {
        guard let content = window?.contentView else { return }
        if root.superview == nil {
            root.frame = content.bounds
            root.autoresizingMask = [.width, .height]
            content.addSubview(root)
        }
        for view in root.subviews { view.removeFromSuperview() }
        for view in ribbon.subviews { view.removeFromSuperview() }
        for view in menuRow.subviews { view.removeFromSuperview() }
        for view in workspace.subviews { view.removeFromSuperview() }
        for view in layerPanel.subviews { view.removeFromSuperview() }
        for view in tabStrip.subviews { view.removeFromSuperview() }
        groups.removeAll()
        toolButtons.removeAll()

        root.background = Fluent.chrome
        menuRow.background = Fluent.chrome
        menuRow.bottomBorder = nil
        ribbon.background = Fluent.chrome
        ribbon.bottomBorder = Fluent.chromeBorder
        if Fluent.skin == .win10 || Fluent.skin == .win7 {
            workspace.background = nil
            workspace.gradientTop = Fluent.t.workspaceTop
            workspace.gradientBottom = Fluent.t.workspaceBottom
        } else {
            workspace.gradientTop = nil
            workspace.gradientBottom = nil
            workspace.background = Fluent.workspace
        }
        if Fluent.skin != .win11 { layerPanel.isHidden = true }
        viewingBitmap = false

        switch Fluent.skin.layout {
        case .fluent:
            root.addSubview(menuRow)
            root.addSubview(ribbon)
            root.addSubview(textBar)
            root.addSubview(workspace)
            root.addSubview(statusBar)
            buildMenuRow()
            buildRibbon()
            buildWorkspace()
            buildStatusBar()
        case .ribbon:
            root.addSubview(tabStrip)
            root.addSubview(ribbon)
            root.addSubview(workspace)
            root.addSubview(statusBar)
            buildTabStrip()
            buildRibbon()
            buildWorkspace()
            buildStatusBar()
        case .classic:
            root.addSubview(classicMenu)
            root.addSubview(textBar)
            root.addSubview(workspace)
            root.addSubview(classicPalette)
            root.addSubview(classicStatus)
            buildClassicMenu()
            buildWorkspace()
            buildClassicExtras()
        }
        wireTextBar()
        root.onLayout = { [weak self] in self?.layoutChrome() }
        root.needsLayout = true
        root.needsDisplay = true
    }

    func applySkin(_ skin: Skin) {
        guard skin != Fluent.skin else { return }
        canvas.finishText()
        Fluent.skin = skin
        UserDefaults.standard.set(skin.rawValue, forKey: "paint.skin")
        buildChrome()
        buildMenu()
        update()
        selectTool(canvas.tool)
        layoutChrome()
    }

    // MARK: Windows 11 menu row

    func buildMenuRow() {
        func textButton(_ title: String, _ builder: @escaping () -> NSMenu) -> RibbonButton {
            let button = RibbonButton(nil, caption: title, kind: .text, height: 30)
            button.menuBuilder = builder
            return button
        }
        let file = textButton("檔案") { [weak self] in self?.fileMenu() ?? NSMenu() }
        let edit = textButton("編輯") { [weak self] in self?.editMenu() ?? NSMenu() }
        let view = textButton("檢視") { [weak self] in self?.viewMenu() ?? NSMenu() }
        let save = iconButton(.save, "儲存 (⌘S)") { [weak self] in _ = self?.save() }
        let share = iconButton(.share, "分享") { [weak self] in self?.shareAction(nil) }
        undoButton = iconButton(.undo, "復原 (⌘Z)") { [weak self] in self?.undoAction(nil) }
        redoButton = iconButton(.redo, "重做 (⇧⌘Z)") { [weak self] in self?.redoAction(nil) }
        let settings = iconButton(.settings, "設定") { [weak self] in self?.settingsAction(nil) }
        settings.identifier = NSUserInterfaceItemIdentifier("settings")
        for button in [file, edit, view, save, share, undoButton!, redoButton!, settings] {
            menuRow.addSubview(button)
        }
    }

    func layoutMenuRow() {
        var x: CGFloat = 10
        for subview in menuRow.subviews {
            guard let button = subview as? RibbonButton else { continue }
            if button.identifier?.rawValue == "settings" {
                button.setFrameOrigin(NSPoint(x: menuRow.bounds.width - button.frame.width - 12, y: 5))
                continue
            }
            button.setFrameOrigin(NSPoint(x: x, y: 5))
            x += button.frame.width + 2
            if button.caption == "檢視" { x += 10 }
        }
    }

    // MARK: Windows 10 / 7 tab strip

    func buildTabStrip() {
        tabStrip.tabs = ["常用", "檢視"]
        tabStrip.paintButton = Fluent.skin == .win7
        tabStrip.activeIndex = ribbonTab
        tabStrip.toolTip = Fluent.skin == .win7 ? "小畫家" : "檔案"
        tabStrip.onFile = { [weak self] in
            guard let self else { return }
            self.fileMenu().popUp(positioning: nil, at: NSPoint(x: 2, y: self.tabStrip.bounds.maxY),
                                  in: self.tabStrip)
        }
        tabStrip.onSelect = { [weak self] index in
            guard let self else { return }
            self.ribbonTab = index
            for view in self.ribbon.subviews { view.removeFromSuperview() }
            self.groups.removeAll()
            self.toolButtons.removeAll()
            self.buildRibbon()
            self.selectTool(self.canvas.tool)
            self.layoutChrome()
        }
        undoButton = iconButton(.undo, "復原 (⌘Z)", 28, 24) { [weak self] in self?.undoAction(nil) }
        redoButton = iconButton(.redo, "重做 (⇧⌘Z)", 28, 24) { [weak self] in self?.redoAction(nil) }
        let save = iconButton(.save, "儲存 (⌘S)", 28, 24) { [weak self] in _ = self?.save() }
        let share = iconButton(.share, "分享", 28, 24) { [weak self] in self?.shareAction(nil) }
        let settings = iconButton(.settings, "外觀設定", 28, 24) { [weak self] in self?.settingsAction(nil) }
        for button in [save, share, undoButton!, redoButton!, settings] { tabStrip.addSubview(button) }
    }

    func layoutTabStrip() {
        var x = tabStrip.bounds.width - 8
        for subview in tabStrip.subviews.reversed() {
            guard let button = subview as? RibbonButton else { continue }
            x -= button.frame.width
            button.setFrameOrigin(NSPoint(x: x, y: (tabStrip.bounds.height - button.frame.height) / 2))
            x -= 2
        }
    }

    // MARK: Ribbon groups

    func buildRibbon() {
        brushButton = nil
        if Fluent.skin.layout == .ribbon && ribbonTab == 2 { buildTextTab(); return }
        if Fluent.skin.layout == .ribbon && ribbonTab == 1 { buildViewTab(); return }
        if Fluent.skin.layout == .ribbon { buildClipboardGroup() }
        buildImageGroup()
        buildToolsGroup()
        buildBrushGroup()
        buildShapesGroup()
        if Fluent.skin.layout == .ribbon { buildSizeGroup() }
        buildColorGroup()
        if Fluent.skin.layout == .fluent { buildCopilotGroup(); buildLayersGroup() }
    }

    func buildClipboardGroup() {
        let paste = RibbonButton(.duplicate, caption: "貼上", kind: .tall, chevron: true, width: 48, height: 60)
        paste.glyphSize = 24
        paste.onClick = { [weak self] in self?.pasteAction(nil) }
        paste.setFrameOrigin(NSPoint(x: 8, y: 4))
        let cut = RibbonButton(.crop, caption: "剪下", kind: .labelled, width: 62, height: 24)
        cut.onClick = { [weak self] in self?.cutAction(nil) }
        cut.setFrameOrigin(NSPoint(x: 58, y: 10))
        let copy = RibbonButton(.duplicate, caption: "複製", kind: .labelled, width: 62, height: 24)
        copy.onClick = { [weak self] in self?.copyAction(nil) }
        copy.setFrameOrigin(NSPoint(x: 58, y: 38))
        _ = group("剪貼簿", 130, [paste, cut, copy])
    }

    func buildImageGroup() {
        selectButton = RibbonButton(.selectRect, caption: Fluent.skin.layout == .fluent ? "" : "選取",
                                    kind: .tall, chevron: true, width: 48, height: 60)
        selectButton.glyphSize = 22
        selectButton.toolTip = "選取項目"
        selectButton.menuOnChevronOnly = true
        selectButton.menuBuilder = { [weak self] in self?.selectionMenu() ?? NSMenu() }
        selectButton.onClick = { [weak self] in
            self?.canvas.freeSelect = false
            self?.selectTool(.select)
        }
        selectButton.setFrameOrigin(NSPoint(x: 8, y: 4))
        toolButtons[.select] = selectButton

        if Fluent.skin.layout == .fluent {
            _ = group("選取項目", 64, [selectButton])
            let crop = iconButton(.crop, "裁剪") { [weak self] in self?.cropAction(nil) }
            crop.setFrameOrigin(NSPoint(x: 8, y: 6))
            let resize = iconButton(.resize, "調整大小和扭曲") { [weak self] in self?.resizeAction(nil) }
            resize.setFrameOrigin(NSPoint(x: 8, y: 42))
            let rotate = iconButton(.rotate, "旋轉", 46, 34, chevron: true) {}
            rotate.menuBuilder = { [weak self] in self?.rotateMenu() ?? NSMenu() }
            rotate.setFrameOrigin(NSPoint(x: 46, y: 6))
            let flip = iconButton(.flip, "翻轉", 46, 34, chevron: true) {}
            flip.menuBuilder = { [weak self] in self?.flipMenu() ?? NSMenu() }
            flip.setFrameOrigin(NSPoint(x: 46, y: 42))
            let cutout = iconButton(.removeBackground, "移除背景", 40, 40) { [weak self] in self?.removeBackground(nil) }
            cutout.glyphSize = 22
            cutout.setFrameOrigin(NSPoint(x: 98, y: 20))
            _ = group("影像", 146, [crop, resize, rotate, flip, cutout])
            return
        }
        let crop = RibbonButton(.crop, caption: "裁剪", kind: .labelled, width: 92, height: 22)
        crop.onClick = { [weak self] in self?.cropAction(nil) }
        crop.setFrameOrigin(NSPoint(x: 58, y: 6))
        let resize = RibbonButton(.resize, caption: "調整大小", kind: .labelled, width: 92, height: 22)
        resize.onClick = { [weak self] in self?.resizeAction(nil) }
        resize.setFrameOrigin(NSPoint(x: 58, y: 30))
        let rotate = RibbonButton(.rotate, caption: "旋轉", kind: .labelled, chevron: true, width: 92, height: 22)
        rotate.menuBuilder = { [weak self] in self?.rotateFlipMenu() ?? NSMenu() }
        rotate.setFrameOrigin(NSPoint(x: 58, y: 54))
        _ = group("影像", 158, [selectButton, crop, resize, rotate])
    }

    func buildToolsGroup() {
        var views: [NSView] = []
        let grid: [PaintTool] = [.pencil, .fill, .text, .eraser, .picker, .magnifier]
        for (index, tool) in grid.enumerated() {
            let button = RibbonButton(tool.glyph, kind: .grid, width: 34, height: 34)
            button.glyphSize = 18
            button.toolTip = tool.rawValue
            button.onClick = { [weak self] in self?.selectTool(tool) }
            button.setFrameOrigin(NSPoint(x: 8 + CGFloat(index % 3) * 35, y: 6 + CGFloat(index / 3) * 36))
            toolButtons[tool] = button
            views.append(button)
        }
        _ = group("工具", 119, views)
    }

    func buildBrushGroup() {
        if Fluent.skin.layout == .ribbon {
            var views: [NSView] = []
            for (index, tool) in PaintTool.brushes.enumerated() {
                let button = RibbonButton(tool.glyph, kind: .grid, width: 34, height: 34)
                button.glyphSize = 18
                button.toolTip = tool.rawValue
                button.onClick = { [weak self] in self?.selectTool(tool) }
                button.setFrameOrigin(NSPoint(x: 8 + CGFloat(index % 2) * 36, y: 6 + CGFloat(index / 2) * 36))
                toolButtons[tool] = button
                views.append(button)
            }
            _ = group("筆刷", 86, views)
            return
        }
        brushButton = RibbonButton(activeBrush.glyph, kind: .tall, chevron: false, width: 46, height: 46)
        brushButton.glyphSize = 22
        brushButton.toolTip = "筆刷"
        brushButton.onClick = { [weak self] in guard let self else { return }; self.selectTool(self.activeBrush) }
        brushButton.setFrameOrigin(NSPoint(x: 8, y: 8))
        let chevron = RibbonButton(.chevron, kind: .grid, width: 46, height: 18)
        chevron.glyphSize = 11
        chevron.toolTip = "選擇筆刷"
        chevron.menuBuilder = { [weak self] in self?.brushMenu() ?? NSMenu() }
        chevron.setFrameOrigin(NSPoint(x: 8, y: 54))
        _ = group("筆刷", 62, [brushButton, chevron])
    }

    func buildShapesGroup() {
        gallery.frame = NSRect(x: 8, y: 6, width: 138, height: 72)
        gallery.onSelect = { [weak self] tool in self?.selectTool(tool) }
        outlineButton = iconButton(.outline, "外框", 46, 34, chevron: true) {}
        outlineButton.menuBuilder = { [weak self] in self?.outlineMenu() ?? NSMenu() }
        outlineButton.setFrameOrigin(NSPoint(x: 152, y: 6))
        fillButton = iconButton(.fillStyle, "填滿", 46, 34, chevron: true) {}
        fillButton.menuBuilder = { [weak self] in self?.fillMenu() ?? NSMenu() }
        fillButton.setFrameOrigin(NSPoint(x: 152, y: 42))
        _ = group("形狀", 206, [gallery, outlineButton, fillButton])
    }

    func buildSizeGroup() {
        let size = RibbonButton(.thickness, caption: "大小", kind: .tall, chevron: true, width: 46, height: 60)
        size.glyphSize = 22
        size.menuBuilder = { [weak self] in self?.sizeMenu() ?? NSMenu() }
        size.setFrameOrigin(NSPoint(x: 8, y: 4))
        _ = group("", 62, [size])
    }

    func buildColorGroup() {
        colors.showsRecent = Fluent.skin == .win11
        colors.showsEditorWheel = Fluent.skin == .win11
        colors.frame = NSRect(x: 8, y: 4, width: ColorGroup.intrinsicWidth, height: 74)
        colors.onPick = { [weak self] color, secondary in self?.apply(color: color, secondary: secondary) }
        colors.onSelectWell = { [weak self] primary in
            guard let self else { return }
            self.editingPrimary = primary
            self.colors.primaryWell.isChecked = primary
            self.colors.secondaryWell.isChecked = !primary
            self.colors.needsDisplay = true
        }
        colors.editButton.onClick = { [weak self] in self?.editColor(nil) }
        _ = group("色彩", ColorGroup.intrinsicWidth + 16, [colors])
    }

    func buildCopilotGroup() {
        let copilot = RibbonButton(.copilot, caption: "Copilot", kind: .tall, chevron: true, width: 54, height: 62)
        copilot.glyphSize = 24
        copilot.toolTip = "Copilot"
        copilot.menuBuilder = { [weak self] in self?.copilotMenu() ?? NSMenu() }
        copilot.setFrameOrigin(NSPoint(x: 8, y: 8))
        _ = group("", 70, [copilot])
    }

    func buildLayersGroup() {
        layersButton = RibbonButton(.layers, caption: "圖層", kind: .tall, chevron: false, width: 54, height: 62)
        layersButton.glyphSize = 24
        layersButton.isChecked = !layerPanel.isHidden
        layersButton.onClick = { [weak self] in self?.toggleLayers(nil) }
        layersButton.setFrameOrigin(NSPoint(x: 8, y: 8))
        let container = group("", 70, [layersButton])
        container.showsSeparator = false
    }

    func buildViewTab() {
        func tall(_ glyph: Glyph, _ caption: String, _ action: @escaping () -> Void) -> RibbonButton {
            let button = RibbonButton(glyph, caption: caption, kind: .tall, width: 60, height: 62)
            button.glyphSize = 24
            button.onClick = action
            button.setFrameOrigin(NSPoint(x: 0, y: 8))
            return button
        }
        let zoomIn = tall(.zoomIn, "放大") { [weak self] in self?.setZoom((self?.canvas.zoom ?? 1) * 1.25) }
        let zoomOut = tall(.zoomOut, "縮小") { [weak self] in self?.setZoom((self?.canvas.zoom ?? 1) / 1.25) }
        let actual = tall(.canvasSize, "100%") { [weak self] in self?.setZoom(1) }
        zoomIn.setFrameOrigin(NSPoint(x: 8, y: 8))
        zoomOut.setFrameOrigin(NSPoint(x: 70, y: 8))
        actual.setFrameOrigin(NSPoint(x: 132, y: 8))
        _ = group("縮放", 200, [zoomIn, zoomOut, actual])

        let rulers = tall(.thickness, "尺規") { [weak self] in self?.toggleRulers() }
        rulers.isChecked = showRulers
        rulers.setFrameOrigin(NSPoint(x: 8, y: 8))
        let grid = tall(.grid, "格線") { [weak self] in self?.gridAction(nil) }
        grid.isChecked = canvas.grid
        grid.setFrameOrigin(NSPoint(x: 70, y: 8))
        let status = tall(.canvasSize, "狀態列") { [weak self] in self?.toggleStatusBar() }
        status.isChecked = showStatus
        status.setFrameOrigin(NSPoint(x: 132, y: 8))
        _ = group("顯示或隱藏", 200, [rulers, grid, status])

        let full = tall(.fitWindow, "全螢幕") { [weak self] in self?.window?.toggleFullScreen(nil) }
        full.setFrameOrigin(NSPoint(x: 8, y: 8))
        let thumb = tall(.duplicate, "縮圖") { [weak self] in self?.toggleThumbnail() }
        thumb.isChecked = showThumbnail
        thumb.setFrameOrigin(NSPoint(x: 70, y: 8))
        let container = group("顯示", 140, [full, thumb])
        container.showsSeparator = false
    }

    func buildTextTab() {
        textBar.sync(name: canvas.fontName, size: canvas.fontSize, bold: canvas.boldText,
                     italic: canvas.italicText, underline: canvas.underlineText)
        textBar.frame = NSRect(x: 8, y: 8, width: 420, height: 70)
        let container = group("字型", 440, [textBar])
        container.showsSeparator = false
    }

    func layoutRibbon() {
        var x: CGFloat = 6
        for container in groups {
            container.setFrameSize(NSSize(width: container.frame.width, height: ribbon.bounds.height))
            container.setFrameOrigin(NSPoint(x: x, y: 0))
            x += container.frame.width
        }
    }

    // MARK: Windows XP chrome

    func buildClassicMenu() {
        classicMenu.entries = [
            ClassicMenuBar.Entry(title: "檔案(F)") { [weak self] in self?.fileMenu() ?? NSMenu() },
            ClassicMenuBar.Entry(title: "編輯(E)") { [weak self] in self?.editMenu() ?? NSMenu() },
            ClassicMenuBar.Entry(title: "檢視(V)") { [weak self] in self?.viewMenu() ?? NSMenu() },
            ClassicMenuBar.Entry(title: "影像(I)") { [weak self] in self?.imageMenu() ?? NSMenu() },
            ClassicMenuBar.Entry(title: "色彩(C)") { [weak self] in self?.colorMenu() ?? NSMenu() },
            ClassicMenuBar.Entry(title: "說明(H)") { [weak self] in self?.helpMenu() ?? NSMenu() }
        ]
        classicMenu.needsDisplay = true
    }

    func buildClassicExtras() {
        toolbox.onSelect = { [weak self] tool, free in
            guard let self else { return }
            self.canvas.freeSelect = free
            self.selectTool(tool)
        }
        toolbox.onWidth = { [weak self] width in
            guard let self else { return }
            self.canvas.lineWidth = width
            self.dock.sizeSlider.value = Double(width)
        }
        toolbox.onZoom = { [weak self] level in
            self?.toolbox.zoomLevel = level
            self?.setZoom(level)
        }
        toolbox.onShapeStyle = { [weak self] style in self?.setShapeStyle(style) }
        toolbox.onTransparent = { [weak self] transparent in
            self?.canvas.drawOpaque = !transparent
            self?.toolbox.transparent = transparent
        }
        toolbox.onBrushTip = { [weak self] tip, width in
            guard let self else { return }
            self.canvas.brushTip = tip
            self.canvas.lineWidth = width
            self.dock.sizeSlider.value = Double(width)
        }
        workspace.addSubview(toolbox)
        classicPalette.onPick = { [weak self] color, secondary in self?.apply(color: color, secondary: secondary) }
        classicPalette.onEdit = { [weak self] in self?.editColor(nil) }
        classicPalette.primary = canvas.primary
        classicPalette.secondary = canvas.secondary
    }

    // MARK: Workspace

    func buildWorkspace() {
        scroll.hasHorizontalScroller = true
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = Fluent.workspace
        scroll.contentView.postsBoundsChangedNotifications = true
        if canvas.superview !== stage { stage.addSubview(canvas) }
        scroll.documentView = stage
        canvas.wantsLayer = true
        canvas.layer?.shadowColor = NSColor.black.cgColor
        canvas.layer?.shadowOpacity = Fluent.skin == .winxp ? 0 : 0.18
        canvas.layer?.shadowRadius = 4
        canvas.layer?.shadowOffset = CGSize(width: 0, height: -1)
        workspace.addSubview(scroll)

        dock.sizeSlider.onChange = { [weak self] value in
            guard let self else { return }
            self.canvas.lineWidth = CGFloat(value)
            self.dock.sizeCard.toolTip = "大小：\(Int(value)) 像素"
        }
        dock.opacitySlider.onChange = { [weak self] value in
            guard let self else { return }
            self.canvas.opacity = CGFloat(value / 100)
            self.dock.opacityCard.toolTip = "不透明度：\(Int(value))%"
        }
        if Fluent.skin.layout == .fluent { workspace.addSubview(dock) }

        layerPanel.background = Fluent.chrome
        layerScroll.drawsBackground = false
        layerScroll.hasVerticalScroller = true
        layerStack.background = nil
        layerScroll.documentView = layerStack
        layerPanel.addSubview(layerScroll)

        let add = iconButton(.plus, "新增圖層", 28, 26) { [weak self] in self?.addLayer(nil) }
        add.identifier = NSUserInterfaceItemIdentifier("layer-add")
        let up = iconButton(.moveUp, "上移", 28, 26) { [weak self] in self?.reorderLayer(1) }
        let down = iconButton(.moveDown, "下移", 28, 26) { [weak self] in self?.reorderLayer(-1) }
        let copy = iconButton(.duplicate, "複製圖層", 28, 26) { [weak self] in self?.duplicateLayer() }
        let merge = iconButton(.merge, "向下合併", 28, 26) { [weak self] in self?.mergeLayer() }
        let remove = iconButton(.trash, "刪除圖層", 28, 26) { [weak self] in self?.deleteLayer() }
        for control in [add, up, down, copy, merge, remove] {
            if control.identifier == nil { control.identifier = NSUserInterfaceItemIdentifier("layer-tool") }
            layerPanel.addSubview(control)
        }
        layerOpacity.onChange = { [weak self] value in self?.setLayerOpacity(value) }
        layerPanel.addSubview(layerOpacity)
        backdropWell.toolTip = "畫布底色"
        backdropWell.onPick = { [weak self] _, _ in self?.pickBackdrop() }
        layerPanel.addSubview(backdropWell)
        workspace.addSubview(layerPanel)
        rulerH.horizontal = true
        rulerV.horizontal = false
        workspace.addSubview(rulerH)
        workspace.addSubview(rulerV)
        workspace.addSubview(thumbnail)
    }

    func wireTextBar() {
        textBar.onFont = { [weak self] name in
            self?.canvas.fontName = name
            self?.textBar.fontName = name
        }
        textBar.onSize = { [weak self] size in
            self?.canvas.fontSize = size
            self?.textBar.fontSize = size
        }
        textBar.onToggle = { [weak self] which in
            guard let self else { return }
            switch which {
            case "bold": self.canvas.boldText.toggle()
            case "italic": self.canvas.italicText.toggle()
            case "underline": self.canvas.underlineText.toggle()
            default: break
            }
            self.textBar.sync(name: self.canvas.fontName, size: self.canvas.fontSize,
                              bold: self.canvas.boldText, italic: self.canvas.italicText,
                              underline: self.canvas.underlineText)
        }
    }

    func wantsTextStrip() -> Bool {
        let editing = canvas.tool == .text || canvas.textEditor != nil
        if Fluent.skin == .win11 { return editing }
        if Fluent.skin == .winxp { return showTextBar }
        return false
    }

    var syncingText = false
    func syncTextChrome() {
        if syncingText { return }
        syncingText = true
        defer { syncingText = false }
        let editing = canvas.tool == .text || canvas.textEditor != nil
        if Fluent.skin == .winxp && editing { showTextBar = true }
        if Fluent.skin.layout == .ribbon {
            let tabs = editing ? ["常用", "檢視", "文字"] : ["常用", "檢視"]
            let changed = tabStrip.tabs != tabs || (editing && ribbonTab != 2) || (!editing && ribbonTab > 1)
            tabStrip.tabs = tabs
            if editing { ribbonTab = 2 } else if ribbonTab > 1 { ribbonTab = 0 }
            if changed {
                for view in ribbon.subviews { view.removeFromSuperview() }
                groups.removeAll()
                toolButtons.removeAll()
                buildRibbon()
                applyToolChecks()
            }
            tabStrip.activeIndex = ribbonTab
            tabStrip.needsDisplay = true
        }
        textBar.sync(name: canvas.fontName, size: canvas.fontSize, bold: canvas.boldText,
                     italic: canvas.italicText, underline: canvas.underlineText)
        root.needsLayout = true
        layoutChrome()
    }

    func buildStatusBar() {
        statusBar.fitButton.onClick = { [weak self] in self?.fitCanvas(nil) }
        statusBar.gridButton.onClick = { [weak self] in self?.gridAction(nil) }
        statusBar.zoomOut.onClick = { [weak self] in self?.setZoom((self?.canvas.zoom ?? 1) / 1.25) }
        statusBar.zoomIn.onClick = { [weak self] in self?.setZoom((self?.canvas.zoom ?? 1) * 1.25) }
        statusBar.zoomSlider.onChange = { [weak self] value in self?.setZoom(CGFloat(value / 100)) }
        statusBar.zoomPopup.menuBuilder = { [weak self] in self?.zoomMenu() ?? NSMenu() }
    }

    // MARK: Layout

    func layoutChrome() {
        let size = root.bounds.size
        let tokens = Fluent.t
        if Fluent.skin != .win11 { layerPanel.isHidden = true }
        let statusHeight = showStatus && !viewingBitmap ? tokens.statusHeight : 0
        statusBar.isHidden = statusHeight == 0 || Fluent.skin == .winxp
        classicStatus.isHidden = statusHeight == 0 || Fluent.skin != .winxp
        if viewingBitmap {
            classicMenu.isHidden = true
            menuRow.isHidden = true
            tabStrip.isHidden = true
            ribbon.isHidden = true
            textBar.isHidden = true
            classicPalette.isHidden = true
            toolbox.isHidden = true
            workspace.frame = NSRect(x: 0, y: 0, width: size.width, height: size.height)
            scroll.frame = workspace.bounds
            rulerH.isHidden = true
            rulerV.isHidden = true
            thumbnail.isHidden = true
            layerPanel.isHidden = true
            dock.isHidden = true
            layoutStage()
            return
        }
        classicMenu.isHidden = false
        menuRow.isHidden = false
        tabStrip.isHidden = false
        ribbon.isHidden = false
        switch Fluent.skin.layout {
        case .classic:
            let textHeight: CGFloat = wantsTextStrip() ? 32 : 0
            textBar.isHidden = textHeight == 0
            textBar.frame = NSRect(x: 0, y: tokens.menuHeight, width: size.width, height: textHeight)
            classicMenu.frame = NSRect(x: 0, y: 0, width: size.width, height: tokens.menuHeight)
            let paletteHeight = showPalette ? ClassicPalette.preferredHeight : 0
            classicPalette.isHidden = paletteHeight == 0
            let workTop = tokens.menuHeight + textHeight
            let workHeight = max(120, size.height - workTop - paletteHeight - statusHeight)
            workspace.frame = NSRect(x: 0, y: workTop, width: size.width, height: workHeight)
            classicPalette.frame = NSRect(x: 0, y: workTop + workHeight, width: size.width, height: paletteHeight)
            classicStatus.frame = NSRect(x: 0, y: size.height - statusHeight, width: size.width, height: statusHeight)
            let toolWidth = showToolbox ? ToolboxView.preferredWidth : 0
            toolbox.isHidden = toolWidth == 0
            toolbox.frame = NSRect(x: 0, y: 0, width: toolWidth, height: workHeight)
            scroll.frame = NSRect(x: toolWidth, y: 0, width: max(80, size.width - toolWidth), height: workHeight)
            layerPanel.frame = .zero
        default:
            textBar.isHidden = Fluent.skin != .win11 || !wantsTextStrip()
            let topHeight = tokens.menuHeight
            if Fluent.skin.layout == .fluent {
                menuRow.frame = NSRect(x: 0, y: 0, width: size.width, height: topHeight)
                layoutMenuRow()
            } else {
                tabStrip.frame = NSRect(x: 0, y: 0, width: size.width, height: topHeight)
                layoutTabStrip()
            }
            ribbon.frame = NSRect(x: 0, y: topHeight, width: size.width, height: tokens.ribbonHeight)
            let textHeight: CGFloat = textBar.isHidden ? 0 : 34
            textBar.frame = NSRect(x: 0, y: topHeight + tokens.ribbonHeight, width: size.width, height: textHeight)
            let workTop = topHeight + tokens.ribbonHeight + textHeight
            let workHeight = max(120, size.height - workTop - statusHeight)
            workspace.frame = NSRect(x: 0, y: workTop, width: size.width, height: workHeight)
            statusBar.frame = NSRect(x: 0, y: workTop + workHeight, width: size.width, height: statusHeight)
            layoutRibbon()
            let panelWidth = layerPanel.isHidden ? 0 : PaintController.layerWidth
            let ruler = showRulers ? 18.0 : 0
            rulerH.isHidden = !showRulers
            rulerV.isHidden = !showRulers
            rulerH.frame = NSRect(x: ruler, y: 0, width: max(0, size.width - panelWidth - ruler), height: ruler)
            rulerV.frame = NSRect(x: 0, y: ruler, width: ruler, height: max(0, workHeight - ruler))
            scroll.frame = NSRect(x: ruler, y: ruler,
                                  width: max(80, size.width - panelWidth - ruler),
                                  height: max(80, workHeight - ruler))
            layerPanel.frame = NSRect(x: size.width - panelWidth, y: 0, width: panelWidth, height: workHeight)
            if Fluent.skin.layout == .fluent {
                let dockHeight = min(260, max(150, workHeight - 80))
                dock.frame = NSRect(x: 14 + ruler, y: (workHeight - dockHeight) / 2,
                                    width: SliderDock.preferredWidth, height: dockHeight)
                dock.isHidden = !canvas.tool.usesSize
            }
        }
        thumbnail.isHidden = !showThumbnail
        thumbnail.frame = NSRect(x: scroll.frame.maxX - 168, y: scroll.frame.maxY - 128, width: 160, height: 120)
        scroll.drawsBackground = Fluent.skin == .winxp || Fluent.skin == .win11
        scroll.backgroundColor = Fluent.workspace
        updateRulers()
        layoutLayerPanel()
        layoutStage()
    }

    func updateRulers() {
        guard showRulers else { return }
        rulerH.scale = canvas.zoom
        rulerV.scale = canvas.zoom
        let origin = scroll.contentView.bounds.origin
        rulerH.origin = origin.x / max(canvas.zoom, 0.01) - canvas.frame.minX / max(canvas.zoom, 0.01)
        rulerV.origin = origin.y / max(canvas.zoom, 0.01) - canvas.frame.minY / max(canvas.zoom, 0.01)
        rulerH.needsDisplay = true
        rulerV.needsDisplay = true
    }

    func layoutLayerPanel() {
        guard !layerPanel.isHidden else { return }
        let width = layerPanel.bounds.width
        var bottom = layerPanel.bounds.height - 12
        var tools: [RibbonButton] = []
        for subview in layerPanel.subviews {
            guard let button = subview as? RibbonButton else { continue }
            tools.append(button)
        }
        let commands = tools.filter { $0.identifier?.rawValue != "layer-add" }
        var x: CGFloat = 12
        for button in commands {
            button.setFrameOrigin(NSPoint(x: x, y: bottom - 26))
            x += 32
        }
        bottom -= 34
        layerOpacity.frame = NSRect(x: 12, y: bottom - 22, width: max(40, width - 24), height: 20)
        bottom -= 30
        if let add = tools.first(where: { $0.identifier?.rawValue == "layer-add" }) {
            add.setFrameOrigin(NSPoint(x: max(8, width - 40), y: 36))
        }
        backdropWell.setFrameOrigin(NSPoint(x: 12, y: 8))
        layerScroll.frame = NSRect(x: 8, y: 44, width: max(40, width - 16), height: max(60, bottom - 52))
        layoutLayerRows()
    }

    func layoutStage() {
        let viewport = scroll.contentSize
        let margin: CGFloat = Fluent.skin == .winxp ? 6 : 36
        let size = NSSize(width: max(viewport.width, canvas.frame.width + margin * 2),
                          height: max(viewport.height, canvas.frame.height + margin * 2))
        if stage.frame.size != size { stage.setFrameSize(size) }
        if Fluent.skin == .winxp {
            canvas.setFrameOrigin(NSPoint(x: margin, y: margin))
        } else {
            canvas.setFrameOrigin(NSPoint(x: max(margin, ((size.width - canvas.frame.width) / 2).rounded()),
                                          y: max(margin, ((size.height - canvas.frame.height) / 2).rounded())))
        }
    }

    func windowDidResize(_ notification: Notification) { root.needsLayout = true }

    // MARK: State

    func update() {
        window?.title = "\(doc.url?.deletingPathExtension().lastPathComponent ?? "未命名") - 小畫家"
        window?.isDocumentEdited = doc.dirty
        statusBar.canvasText = "\(doc.width) × \(doc.height) 像素"
        statusBar.selectionText = canvas.selection.map { "\(Int($0.width)) × \(Int($0.height)) 像素" } ?? "—"
        statusBar.zoomText = "\(Int((canvas.zoom * 100).rounded()))%"
        statusBar.zoomPopup.caption = statusBar.zoomText
        statusBar.zoomSlider.value = Double(canvas.zoom * 100)
        statusBar.needsDisplay = true
        statusBar.zoomPopup.needsDisplay = true
        undoButton?.isEnabledControl = !doc.undoStack.isEmpty
        redoButton?.isEnabledControl = !doc.redoStack.isEmpty
        classicStatus.canvasText = "\(doc.width) × \(doc.height)"
        classicStatus.needsDisplay = true
        canvas.refresh()
        thumbnail.image = NSImage(cgImage: doc.composite().image,
                                  size: NSSize(width: doc.width, height: doc.height))
        layoutStage()
        updateRulers()
        rebuildLayers()
    }

    func applyToolChecks() {
        for (candidate, button) in toolButtons { button.isChecked = candidate == canvas.tool }
        brushButton?.isChecked = PaintTool.brushes.contains(canvas.tool)
        gallery.select(canvas.tool)
        toolbox.select(canvas.tool, free: canvas.freeSelect)
        toolbox.shapeStyle = canvas.shapeFill
        toolbox.transparent = !canvas.drawOpaque
        if canvas.brushTip >= 0 { toolbox.brushTip = canvas.brushTip }
    }

    func selectTool(_ tool: PaintTool) {
        canvas.tool = tool
        if PaintTool.brushes.contains(tool) {
            activeBrush = tool
            brushButton?.glyph = tool.glyph
            brushButton?.needsDisplay = true
            if tool != .brush { canvas.brushTip = -1 }
        }
        applyToolChecks()
        dock.isHidden = !tool.usesSize
        outlineButton?.isEnabledControl = tool.isShape
        fillButton?.isEnabledControl = tool.isShape
        statusBar.cursorText = tool.rawValue
        statusBar.needsDisplay = true
        syncTextChrome()
        window?.makeFirstResponder(canvas)
    }

    func apply(color: NSColor, secondary: Bool) {
        let targetSecondary = secondary || !editingPrimary
        if targetSecondary {
            canvas.secondary = color
            colors.secondaryWell.color = color
        } else {
            canvas.primary = color
            colors.primaryWell.color = color
        }
        colors.remember(color)
        colors.needsDisplay = true
        classicPalette.primary = canvas.primary
        classicPalette.secondary = canvas.secondary
    }

    // MARK: Menus in the ribbon

    func item(_ menu: NSMenu, _ title: String, _ handler: @escaping () -> Void, checked: Bool = false) {
        let entry = BlockMenuItem(title: title, handler: handler)
        entry.state = checked ? .on : .off
        menu.addItem(entry)
    }

    func fileMenu() -> NSMenu {
        if Fluent.skin == .winxp { return classicFileMenu() }
        let menu = NSMenu()
        item(menu, "新增") { [weak self] in self?.newDocument(nil) }
        item(menu, "開啟…") { [weak self] in self?.openDocument(nil) }
        menu.addItem(.separator())
        item(menu, "儲存") { [weak self] in _ = self?.save() }
        item(menu, "另存專案…") { [weak self] in _ = self?.save(asNew: true) }
        item(menu, "匯出圖片…") { [weak self] in self?.exportImage(nil) }
        menu.addItem(.separator())
        item(menu, "列印…") { [weak self] in self?.printAction(nil) }
        item(menu, "調整大小和扭曲…") { [weak self] in self?.resizeAction(nil) }
        return menu
    }

    func classicFileMenu() -> NSMenu {
        let menu = NSMenu()
        item(menu, "開新檔案(N)") { [weak self] in self?.newDocument(nil) }
        item(menu, "開啟舊檔(O)") { [weak self] in self?.openDocument(nil) }
        item(menu, "存檔(S)") { [weak self] in _ = self?.save() }
        item(menu, "另存新檔(A)") { [weak self] in _ = self?.save(asNew: true) }
        menu.addItem(.separator())
        let scan = NSMenuItem(title: "從掃描器或照相機…", action: nil, keyEquivalent: "")
        scan.isEnabled = false
        menu.addItem(scan)
        menu.addItem(.separator())
        item(menu, "預覽列印(V)") { [weak self] in self?.printAction(nil) }
        item(menu, "列印設定(U)") { NSPageLayout().runModal() }
        item(menu, "列印(P)") { [weak self] in self?.printAction(nil) }
        menu.addItem(.separator())
        item(menu, "傳送到(D)") { [weak self] in self?.shareAction(nil) }
        let wall = NSMenuItem(title: "設定成桌布(B)", action: nil, keyEquivalent: "")
        let wallMenu = NSMenu()
        wall.submenu = wallMenu
        wallMenu.addItem(BlockMenuItem(title: "並排(T)") { [weak self] in self?.setWallpaper(.scaleProportionallyUpOrDown) })
        wallMenu.addItem(BlockMenuItem(title: "置中(C)") { [weak self] in self?.setWallpaper(.scaleNone) })
        wallMenu.addItem(BlockMenuItem(title: "延伸(S)") { [weak self] in self?.setWallpaper(.scaleAxesIndependently) })
        menu.addItem(wall)
        let recent = UserDefaults.standard.stringArray(forKey: "paint.recent") ?? []
        if !recent.isEmpty {
            menu.addItem(.separator())
            for path in recent.prefix(4) {
                let name = URL(fileURLWithPath: path).lastPathComponent
                item(menu, name) { [weak self] in self?.open(URL(fileURLWithPath: path)) }
            }
        }
        menu.addItem(.separator())
        item(menu, "結束(X)") { NSApp.terminate(nil) }
        return menu
    }

    func editMenu() -> NSMenu {
        if Fluent.skin == .winxp { return classicEditMenu() }
        let menu = NSMenu()
        item(menu, "復原") { [weak self] in self?.undoAction(nil) }
        item(menu, "重做") { [weak self] in self?.redoAction(nil) }
        menu.addItem(.separator())
        item(menu, "剪下") { [weak self] in self?.cutAction(nil) }
        item(menu, "複製") { [weak self] in self?.copyAction(nil) }
        item(menu, "貼上") { [weak self] in self?.pasteAction(nil) }
        menu.addItem(.separator())
        item(menu, "全選") { [weak self] in self?.selectAllAction(nil) }
        item(menu, "刪除選取範圍") { [weak self] in self?.clearAction(nil) }
        return menu
    }

    func classicEditMenu() -> NSMenu {
        let menu = NSMenu()
        item(menu, "復原(U)") { [weak self] in self?.undoAction(nil) }
        item(menu, "重複(R)") { [weak self] in self?.redoAction(nil) }
        menu.addItem(.separator())
        item(menu, "剪下(T)") { [weak self] in self?.cutAction(nil) }
        item(menu, "複製(C)") { [weak self] in self?.copyAction(nil) }
        item(menu, "貼上(P)") { [weak self] in self?.pasteAction(nil) }
        item(menu, "清除選取範圍(L)") { [weak self] in self?.clearAction(nil) }
        item(menu, "全選(A)") { [weak self] in self?.selectAllAction(nil) }
        menu.addItem(.separator())
        item(menu, "複製到(O)…") { [weak self] in self?.copyToFile() }
        item(menu, "貼上來源(F)…") { [weak self] in self?.pasteFromFile() }
        return menu
    }

    func viewMenu() -> NSMenu {
        if Fluent.skin == .winxp { return classicViewMenu() }
        let menu = NSMenu()
        item(menu, "放大") { [weak self] in self?.setZoom((self?.canvas.zoom ?? 1) * 1.25) }
        item(menu, "縮小") { [weak self] in self?.setZoom((self?.canvas.zoom ?? 1) / 1.25) }
        item(menu, "100%") { [weak self] in self?.setZoom(1) }
        item(menu, "符合視窗") { [weak self] in self?.fitCanvas(nil) }
        menu.addItem(.separator())
        item(menu, "格線", { [weak self] in self?.gridAction(nil) }, checked: canvas.grid)
        if Fluent.skin == .win11 {
            item(menu, "圖層面板", { [weak self] in self?.toggleLayers(nil) }, checked: !layerPanel.isHidden)
        }
        menu.addItem(.separator())
        let appearance = NSMenuItem(title: "外觀", action: nil, keyEquivalent: "")
        appearance.submenu = skinMenu()
        menu.addItem(appearance)
        menu.addItem(.separator())
        item(menu, "全螢幕") { [weak self] in self?.window?.toggleFullScreen(nil) }
        return menu
    }

    func classicViewMenu() -> NSMenu {
        let menu = NSMenu()
        item(menu, "工具箱(T)", { [weak self] in self?.toggleToolbox() }, checked: showToolbox)
        item(menu, "調色盤(C)", { [weak self] in self?.togglePalette() }, checked: showPalette)
        item(menu, "狀態列(S)", { [weak self] in self?.toggleStatusBar() }, checked: showStatus)
        item(menu, "文字工具列(E)", { [weak self] in self?.toggleTextBar() }, checked: showTextBar)
        menu.addItem(.separator())
        let zoom = NSMenuItem(title: "縮放(Z)", action: nil, keyEquivalent: "")
        let zoomMenu = NSMenu()
        zoom.submenu = zoomMenu
        zoomMenu.addItem(BlockMenuItem(title: "一般大小(N)") { [weak self] in self?.setZoom(1) })
        zoomMenu.addItem(BlockMenuItem(title: "大尺寸(L)") { [weak self] in self?.setZoom(4) })
        zoomMenu.addItem(BlockMenuItem(title: "自訂(U)…") { [weak self] in self?.customZoom() })
        zoomMenu.addItem(.separator())
        zoomMenu.addItem(BlockMenuItem(title: "顯示格線(G)") { [weak self] in self?.gridAction(nil) })
        zoomMenu.addItem(BlockMenuItem(title: "顯示縮圖(T)") { [weak self] in self?.toggleThumbnail() })
        menu.addItem(zoom)
        item(menu, "檢視點陣圖(V)") { [weak self] in self?.toggleBitmapView() }
        menu.addItem(.separator())
        let appearance = NSMenuItem(title: "外觀", action: nil, keyEquivalent: "")
        appearance.submenu = skinMenu()
        menu.addItem(appearance)
        return menu
    }

    func selectionMenu() -> NSMenu {
        let menu = NSMenu()
        item(menu, "矩形選取", { [weak self] in
            self?.canvas.freeSelect = false
            self?.selectTool(.select)
        }, checked: canvas.tool == .select && !canvas.freeSelect)
        item(menu, "任意選取", { [weak self] in
            self?.canvas.freeSelect = true
            self?.selectTool(.select)
        }, checked: canvas.tool == .select && canvas.freeSelect)
        menu.addItem(.separator())
        item(menu, "全選") { [weak self] in self?.selectAllAction(nil) }
        item(menu, "反轉選取") { [weak self] in self?.canvas.invertSelection(); self?.update() }
        item(menu, "刪除") { [weak self] in self?.clearAction(nil) }
        menu.addItem(.separator())
        item(menu, "透明選取", { [weak self] in
            guard let self else { return }
            self.canvas.drawOpaque.toggle()
            self.toolbox.transparent = !self.canvas.drawOpaque
        }, checked: !canvas.drawOpaque)
        return menu
    }

    func copilotMenu() -> NSMenu {
        let menu = NSMenu()
        item(menu, "影像建立") { [weak self] in self?.unavailableAI("影像建立") }
        item(menu, "生成擦除") { [weak self] in self?.unavailableAI("生成擦除") }
        item(menu, "移除背景") { [weak self] in self?.removeBackground(nil) }
        item(menu, "Cocreator") { [weak self] in self?.unavailableAI("Cocreator") }
        return menu
    }

    func rotateMenu() -> NSMenu {
        let menu = NSMenu()
        item(menu, "向右旋轉 90°") { [weak self] in self?.transform("rotate") }
        item(menu, "向左旋轉 90°") { [weak self] in
            self?.transform("rotate"); self?.transform("rotate"); self?.transform("rotate")
        }
        item(menu, "旋轉 180°") { [weak self] in self?.transform("rotate"); self?.transform("rotate") }
        return menu
    }

    func flipMenu() -> NSMenu {
        let menu = NSMenu()
        item(menu, "水平翻轉") { [weak self] in self?.transform("horizontal") }
        item(menu, "垂直翻轉") { [weak self] in self?.transform("vertical") }
        return menu
    }

    func brushMenu() -> NSMenu {
        let menu = NSMenu()
        for tool in PaintTool.brushes {
            item(menu, tool.rawValue, { [weak self] in self?.selectTool(tool) }, checked: tool == canvas.tool)
        }
        return menu
    }

    func outlineMenu() -> NSMenu {
        let menu = NSMenu()
        let current = canvas.shapeFill
        item(menu, "無外框", { [weak self] in self?.setShapeStyle(1) }, checked: current == 1)
        item(menu, "實心色彩", { [weak self] in self?.setShapeStyle(current == 1 ? 2 : current) },
             checked: current != 1)
        menu.addItem(.separator())
        for width in [1, 3, 5, 8, 12, 20] {
            item(menu, "線條粗細 \(width) 像素", { [weak self] in
                self?.dock.sizeSlider.value = Double(width)
                self?.canvas.lineWidth = CGFloat(width)
            }, checked: Int(canvas.lineWidth) == width)
        }
        return menu
    }

    func fillMenu() -> NSMenu {
        let menu = NSMenu()
        item(menu, "無填滿", { [weak self] in self?.setShapeStyle(0) }, checked: canvas.shapeFill == 0)
        item(menu, "實心色彩", { [weak self] in self?.setShapeStyle(2) }, checked: canvas.shapeFill == 2)
        item(menu, "僅填滿", { [weak self] in self?.setShapeStyle(1) }, checked: canvas.shapeFill == 1)
        return menu
    }

    func rotateFlipMenu() -> NSMenu {
        let menu = NSMenu()
        item(menu, "向右旋轉 90°") { [weak self] in self?.transform("rotate") }
        item(menu, "向左旋轉 90°") { [weak self] in
            self?.transform("rotate"); self?.transform("rotate"); self?.transform("rotate")
        }
        item(menu, "旋轉 180°") { [weak self] in self?.transform("rotate"); self?.transform("rotate") }
        menu.addItem(.separator())
        item(menu, "水平翻轉") { [weak self] in self?.transform("horizontal") }
        item(menu, "垂直翻轉") { [weak self] in self?.transform("vertical") }
        return menu
    }

    func sizeMenu() -> NSMenu {
        let menu = NSMenu()
        for width in [1, 3, 5, 8, 12, 20, 32] {
            item(menu, "\(width) 像素", { [weak self] in
                self?.canvas.lineWidth = CGFloat(width)
                self?.dock.sizeSlider.value = Double(width)
                self?.toolbox.activeWidth = CGFloat(width)
            }, checked: Int(canvas.lineWidth) == width)
        }
        return menu
    }

    func imageMenu() -> NSMenu {
        let menu = NSMenu()
        item(menu, "翻轉/旋轉(F)…") { [weak self] in self?.flipRotateDialog() }
        item(menu, "延展/扭曲(S)…") { [weak self] in self?.stretchDialog() }
        item(menu, "反轉色彩(I)") { [weak self] in self?.invertColors() }
        item(menu, "屬性(A)…") { [weak self] in self?.attributesDialog() }
        item(menu, "清除影像(C)") { [weak self] in self?.clearImage() }
        item(menu, "繪製不透明(D)", { [weak self] in
            guard let self else { return }
            self.canvas.drawOpaque.toggle()
            self.toolbox.transparent = !self.canvas.drawOpaque
        }, checked: canvas.drawOpaque)
        return menu
    }

    func colorMenu() -> NSMenu {
        let menu = NSMenu()
        item(menu, "編輯色彩…") { [weak self] in self?.editColor(nil) }
        return menu
    }

    func helpMenu() -> NSMenu {
        let menu = NSMenu()
        item(menu, "說明主題(H)") { [weak self] in self?.helpTopic() }
        item(menu, "關於小畫家(A)") { NSApp.orderFrontStandardAboutPanel(nil) }
        return menu
    }

    func zoomMenu() -> NSMenu {
        let menu = NSMenu()
        for percent in [12, 25, 50, 100, 200, 400, 800] {
            item(menu, "\(percent)%", { [weak self] in self?.setZoom(CGFloat(percent) / 100) },
                 checked: Int((canvas.zoom * 100).rounded()) == percent)
        }
        menu.addItem(.separator())
        item(menu, "符合視窗") { [weak self] in self?.fitCanvas(nil) }
        return menu
    }

    func setShapeStyle(_ style: Int) {
        canvas.shapeFill = max(0, min(2, style))
        outlineButton.needsDisplay = true
        fillButton.needsDisplay = true
    }

    // MARK: Layers

    func rebuildLayers() {
        guard !layerPanel.isHidden else { return }
        for view in layerStack.subviews { view.removeFromSuperview() }
        for index in doc.layers.indices.reversed() {
            let layer = doc.layers[index]
            let row = LayerRow(frame: .zero)
            row.title = layer.name
            row.thumbnail = NSImage(cgImage: layer.raster.image,
                                    size: NSSize(width: layer.raster.width, height: layer.raster.height))
            row.isVisibleLayer = layer.visible
            row.isActiveLayer = index == doc.active
            row.onSelect = { [weak self] in
                guard let self else { return }
                self.canvas.finishText(); self.canvas.selection = nil; self.doc.active = index; self.update()
            }
            row.onToggle = { [weak self] in
                guard let self else { return }
                self.canvas.finishText(); self.doc.checkpoint()
                self.doc.layers[index].visible.toggle(); self.update()
            }
            layerStack.addSubview(row)
        }
        layerOpacity.value = doc.layers[doc.active].opacity * 100
        layoutLayerRows()
    }

    func layoutLayerRows() {
        let width = max(140, layerScroll.contentSize.width)
        layerStack.setFrameSize(NSSize(width: width,
                                       height: max(layerScroll.contentSize.height,
                                                   CGFloat(layerStack.subviews.count) * 122 + 8)))
        for (index, view) in layerStack.subviews.enumerated() {
            view.frame = NSRect(x: 4, y: 6 + CGFloat(index) * 122, width: width - 8, height: 114)
        }
    }

    func setLayerOpacity(_ value: Double) {
        canvas.finishText()
        doc.checkpoint()
        doc.layers[doc.active].opacity = max(0, min(1, value / 100))
        update()
    }

    @objc func addLayer(_ sender: Any?) {
        canvas.finishText()
        guard doc.layers.count < 32 else { showError(PaintError.message("最多支援 32 個圖層。")); return }
        doc.checkpoint()
        doc.layers.insert(PaintLayer(name: "圖層 \(doc.layers.count + 1)", raster: Raster(doc.width, doc.height)),
                          at: doc.active + 1)
        doc.active += 1
        canvas.selection = nil
        update()
    }
    func duplicateLayer() {
        canvas.finishText()
        guard doc.layers.count < 32 else { return }
        doc.checkpoint()
        var layer = doc.layers[doc.active]
        layer.name += " 複本"
        doc.layers.insert(layer, at: doc.active + 1)
        doc.active += 1
        update()
    }
    func deleteLayer() {
        canvas.finishText()
        guard doc.layers.count > 1 else { NSSound.beep(); return }
        doc.checkpoint()
        doc.layers.remove(at: doc.active)
        doc.active = min(doc.active, doc.layers.count - 1)
        canvas.selection = nil
        update()
    }
    func reorderLayer(_ offset: Int) {
        canvas.finishText()
        let next = doc.active + offset
        guard doc.layers.indices.contains(next) else { return }
        doc.checkpoint()
        doc.layers.swapAt(doc.active, next)
        doc.active = next
        update()
    }
    func mergeLayer() {
        canvas.finishText()
        let index = doc.active
        guard index > 0 else { return }
        doc.checkpoint()
        var merged = Raster(doc.width, doc.height)
        for layer in [doc.layers[index - 1], doc.layers[index]] where layer.visible {
            var raster = layer.raster
            for position in raster.pixels.indices {
                raster.pixels[position] = UInt8(Double(raster.pixels[position]) * layer.opacity)
            }
            merged.paste(raster, at: .zero)
        }
        doc.layers[index - 1].raster = merged
        doc.layers[index - 1].visible = true
        doc.layers[index - 1].opacity = 1
        doc.layers.remove(at: index)
        doc.active -= 1
        update()
    }
    @objc func renameLayer(_ sender: Any?) {
        let field = NSTextField(string: doc.layers[doc.active].name)
        field.frame = NSRect(x: 0, y: 0, width: 260, height: 26)
        let alert = NSAlert()
        alert.messageText = "重新命名圖層"
        alert.accessoryView = field
        alert.addButton(withTitle: "確定")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty {
            doc.checkpoint()
            doc.layers[doc.active].name = field.stringValue
            update()
        }
    }
    @objc func toggleLayers(_ sender: Any?) {
        guard Fluent.skin == .win11 else { return }
        layerPanel.isHidden.toggle()
        layersButton?.isChecked = !layerPanel.isHidden
        root.needsLayout = true
        layoutChrome()
        rebuildLayers()
    }

    // MARK: Zoom

    func setZoom(_ value: CGFloat) {
        canvas.zoom = max(0.1, min(8, value))
        canvas.refresh()
        statusBar.zoomText = "\(Int((canvas.zoom * 100).rounded()))%"
        statusBar.zoomPopup.caption = statusBar.zoomText
        statusBar.zoomSlider.value = Double(canvas.zoom * 100)
        statusBar.zoomPopup.needsDisplay = true
        statusBar.needsDisplay = true
        layoutStage()
    }
    @objc func fitCanvas(_ sender: Any?) {
        let available = scroll.contentSize
        guard doc.width > 0, doc.height > 0 else { return }
        setZoom(min((available.width - 72) / CGFloat(doc.width), (available.height - 72) / CGFloat(doc.height)))
    }
    @objc func actualSize(_ sender: Any?) { setZoom(1) }
    @objc func gridAction(_ sender: Any?) {
        canvas.grid.toggle()
        statusBar.gridButton.isChecked = canvas.grid
        canvas.needsDisplay = true
    }

    // MARK: Skins

    func skinMenu() -> NSMenu {
        let menu = NSMenu()
        for candidate in Skin.allCases {
            item(menu, candidate.title, { [weak self] in self?.applySkin(candidate) },
                 checked: candidate == Fluent.skin)
        }
        return menu
    }
    @objc func chooseWin11(_ sender: Any?) { applySkin(.win11) }
    @objc func chooseWin10(_ sender: Any?) { applySkin(.win10) }
    @objc func chooseWin7(_ sender: Any?) { applySkin(.win7) }
    @objc func chooseWinXP(_ sender: Any?) { applySkin(.winxp) }

    // MARK: Colour

    @objc func editColor(_ sender: Any?) {
        pickingBackdrop = false
        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelChanged))
        panel.color = editingPrimary ? canvas.primary : canvas.secondary
        panel.makeKeyAndOrderFront(nil)
    }
    @objc func colorPanelChanged(_ sender: NSColorPanel) {
        if pickingBackdrop {
            canvas.backdrop = sender.color
            backdropWell.color = sender.color
            canvas.needsDisplay = true
            return
        }
        apply(color: sender.color, secondary: !editingPrimary)
    }

    // MARK: File actions

    func showError(_ error: Error) { NSAlert(error: error).runModal() }

    func confirmDiscard() -> Bool {
        canvas.finishText()
        guard doc.dirty else { return true }
        let alert = NSAlert()
        alert.messageText = "要儲存變更嗎？"
        alert.informativeText = "未儲存的繪圖內容將會遺失。"
        alert.addButton(withTitle: "儲存")
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "不要儲存")
        let response = alert.runModal()
        return response == .alertFirstButtonReturn ? save() : response == .alertThirdButtonReturn
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { confirmDiscard() }

    @objc func newDocument(_ sender: Any?) {
        guard confirmDiscard() else { return }
        doc = PaintDocument()
        canvas.doc = doc
        canvas.selection = nil
        update()
        setZoom(1)
    }
    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .bmp, .tiff, .gif,
                                     UTType(filenameExtension: "paintmac") ?? .data]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }
    func open(_ url: URL) {
        guard confirmDiscard() else { return }
        do {
            let next = PaintDocument()
            if url.pathExtension.lowercased() == "paintmac" { try next.openProject(url) }
            else { next.layers = [PaintLayer(name: "背景", raster: try Raster.load(url))] }
            next.url = url
            next.savedRevision = next.revision
            rememberRecent(url)
            doc = next
            canvas.doc = next
            canvas.selection = nil
            update()
            setZoom(1)
        } catch { showError(error) }
    }
    @objc func saveAction(_ sender: Any?) { _ = save() }
    @objc func saveAsAction(_ sender: Any?) { _ = save(asNew: true) }

    func save(asNew: Bool = false) -> Bool {
        canvas.finishText()
        var target = asNew ? nil : doc.url
        if let ext = target?.pathExtension.lowercased(), ext != "paintmac",
           doc.layers.count > 1 || !["png", "jpg", "jpeg", "bmp", "tif", "tiff"].contains(ext) {
            target = nil
        }
        if target == nil {
            let panel = NSSavePanel()
            panel.title = "儲存小畫家專案"
            panel.nameFieldStringValue = (doc.url?.deletingPathExtension().lastPathComponent ?? "未命名") + ".paintmac"
            panel.allowedContentTypes = [UTType(filenameExtension: "paintmac") ?? .data]
            guard panel.runModal() == .OK, let url = panel.url else { return false }
            target = url
        }
        guard let url = target else { return false }
        do {
            if url.pathExtension.lowercased() == "paintmac" { try doc.saveProject(url) }
            else { try doc.composite().write(url) }
            doc.url = url
            doc.savedRevision = doc.revision
            rememberRecent(url)
            update()
            return true
        } catch { showError(error); return false }
    }

    @objc func exportImage(_ sender: Any?) {
        canvas.finishText()
        let panel = NSSavePanel()
        panel.title = "匯出圖片"
        panel.nameFieldStringValue = "未命名.png"
        panel.allowedContentTypes = [.png]
        panel.canSelectHiddenExtension = true
        let format = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 240, height: 28))
        format.addItems(withTitles: ["PNG — 保留透明度", "JPEG — 白色背景", "BMP — 白色背景", "TIFF — 保留透明度"])
        format.target = self
        format.action = #selector(exportFormatChanged)
        activeSavePanel = panel
        panel.accessoryView = format
        if panel.runModal() == .OK, let url = panel.url {
            do { try doc.composite().write(url) } catch { showError(error) }
        }
        activeSavePanel = nil
    }
    @objc func exportFormatChanged(_ sender: NSPopUpButton) {
        let types: [UTType] = [.png, .jpeg, .bmp, .tiff]
        let extensions = ["png", "jpg", "bmp", "tiff"]
        activeSavePanel?.allowedContentTypes = [types[sender.indexOfSelectedItem]]
        if let panel = activeSavePanel {
            panel.nameFieldStringValue = (panel.nameFieldStringValue as NSString).deletingPathExtension
                + "." + extensions[sender.indexOfSelectedItem]
        }
    }

    @objc func printAction(_ sender: Any?) {
        canvas.finishText()
        let raster = doc.composite()
        let image = NSImage(cgImage: raster.image, size: NSSize(width: raster.width, height: raster.height))
        let view = NSImageView(frame: NSRect(origin: .zero, size: image.size))
        view.image = image
        view.imageScaling = .scaleProportionallyUpOrDown
        NSPrintOperation(view: view).run()
    }

    @objc func shareAction(_ sender: Any?) {
        canvas.finishText()
        let raster = doc.composite()
        let image = NSImage(cgImage: raster.image, size: NSSize(width: raster.width, height: raster.height))
        let picker = NSSharingServicePicker(items: [image])
        let anchor = menuRow.subviews.first { ($0 as? RibbonButton)?.toolTip == "分享" } ?? menuRow
        picker.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxY)
    }

    @objc func settingsAction(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "外觀"
        alert.informativeText = "選擇要模擬的 Windows 小畫家版本。設定會記住，下次開啟沿用。"
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 220, height: 26))
        popup.addItems(withTitles: Skin.allCases.map { $0.title })
        popup.selectItem(at: Skin.allCases.firstIndex(of: Fluent.skin) ?? 0)
        alert.accessoryView = popup
        alert.addButton(withTitle: "套用")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let index = popup.indexOfSelectedItem
        if index >= 0 && index < Skin.allCases.count { applySkin(Skin.allCases[index]) }
    }

    @objc func copilotAction(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "AI 工具"
        alert.informativeText = "此版本只提供本機的「移除背景」，不包含 Microsoft 雲端生圖與 Cocreator。"
        alert.addButton(withTitle: "移除背景")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn { removeBackground(nil) }
    }

    // MARK: Edit actions

    @objc func undoAction(_ sender: Any?) {
        if let text = NSApp.keyWindow?.firstResponder as? NSTextView { text.undoManager?.undo(); return }
        doc.undo(); canvas.selection = nil; update()
    }
    @objc func redoAction(_ sender: Any?) {
        if let text = NSApp.keyWindow?.firstResponder as? NSTextView { text.undoManager?.redo(); return }
        doc.redo(); canvas.selection = nil; update()
    }
    @objc func selectAllAction(_ sender: Any?) {
        if let text = NSApp.keyWindow?.firstResponder as? NSTextView { text.selectAll(sender); return }
        selectTool(.select)
        canvas.freeSelect = false
        canvas.selectAll()
        update()
    }
    @objc func copyAction(_ sender: Any?) {
        if let text = NSApp.keyWindow?.firstResponder as? NSTextView { text.copy(sender); return }
        let raster = doc.layers[doc.active].raster
            .cropped(canvas.selection ?? CGRect(x: 0, y: 0, width: doc.width, height: doc.height))
        let image = NSImage(cgImage: raster.image, size: NSSize(width: raster.width, height: raster.height))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }
    @objc func cutAction(_ sender: Any?) {
        if let text = NSApp.keyWindow?.firstResponder as? NSTextView { text.cut(sender); return }
        if canvas.selection == nil { selectAllAction(nil) }
        copyAction(nil)
        canvas.deleteSelection()
    }
    @objc func pasteAction(_ sender: Any?) {
        if let text = NSApp.keyWindow?.firstResponder as? NSTextView { text.paste(sender); return }
        guard let image = NSImage(pasteboard: NSPasteboard.general),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              cg.width <= 8192, cg.height <= 8192, cg.width * cg.height <= 24_000_000 else { NSSound.beep(); return }
        var raster = Raster(cg.width, cg.height)
        raster.draw { $0.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height)) }
        guard doc.layers.count < 32 else { return }
        doc.checkpoint()
        if raster.width > doc.width || raster.height > doc.height {
            let width = max(raster.width, doc.width), height = max(raster.height, doc.height)
            guard width * height <= 24_000_000 else {
                doc.undo(); showError(PaintError.message("貼上後畫布尺寸超過上限。")); return
            }
            for index in doc.layers.indices {
                doc.layers[index].raster = doc.layers[index].raster.resized(width, height, scale: false)
            }
        }
        var layer = Raster(doc.width, doc.height)
        layer.paste(raster, at: .zero)
        doc.layers.insert(PaintLayer(name: "貼上的圖片", raster: layer), at: doc.active + 1)
        doc.active += 1
        selectTool(.select)
        canvas.selection = CGRect(x: 0, y: 0, width: raster.width, height: raster.height)
        update()
    }
    @objc func clearAction(_ sender: Any?) { canvas.deleteSelection() }

    // MARK: Image actions

    @objc func cropAction(_ sender: Any?) {
        canvas.finishText()
        guard let rect = canvas.selection, rect.width > 0, rect.height > 0,
              rect.intersects(CGRect(x: 0, y: 0, width: doc.width, height: doc.height)) else {
            statusBar.cursorText = "請先框選裁剪範圍"
            statusBar.needsDisplay = true
            return
        }
        doc.checkpoint()
        for index in doc.layers.indices { doc.layers[index].raster = doc.layers[index].raster.cropped(rect) }
        canvas.selection = nil
        update()
    }

    @objc func resizeAction(_ sender: Any?) {
        canvas.finishText()
        let mode = NSPopUpButton(frame: NSRect(x: 0, y: 108, width: 140, height: 26))
        mode.addItems(withTitles: ["百分比", "像素"])
        mode.selectItem(at: 1)
        let width = NSTextField(string: String(doc.width))
        let height = NSTextField(string: String(doc.height))
        width.frame = NSRect(x: 48, y: 72, width: 90, height: 24)
        height.frame = NSRect(x: 200, y: 72, width: 90, height: 24)
        let widthLabel = NSTextField(labelWithString: "水平")
        widthLabel.frame = NSRect(x: 0, y: 76, width: 44, height: 18)
        let heightLabel = NSTextField(labelWithString: "垂直")
        heightLabel.frame = NSRect(x: 152, y: 76, width: 44, height: 18)
        let skewX = NSTextField(string: "0")
        let skewY = NSTextField(string: "0")
        skewX.frame = NSRect(x: 48, y: 40, width: 90, height: 24)
        skewY.frame = NSRect(x: 200, y: 40, width: 90, height: 24)
        let skewXLabel = NSTextField(labelWithString: "水平扭曲")
        skewXLabel.frame = NSRect(x: 0, y: 44, width: 48, height: 18)
        let skewYLabel = NSTextField(labelWithString: "垂直扭曲")
        skewYLabel.frame = NSRect(x: 148, y: 44, width: 52, height: 18)
        let ratio = NSButton(checkboxWithTitle: "維持外觀比例", target: nil, action: nil)
        ratio.frame = NSRect(x: 0, y: 8, width: 160, height: 20)
        ratio.state = .on
        let scale = NSButton(checkboxWithTitle: "縮放影像內容", target: nil, action: nil)
        scale.frame = NSRect(x: 168, y: 8, width: 140, height: 20)
        scale.state = .on
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 140))
        for view in [mode, widthLabel, width, heightLabel, height, skewXLabel, skewX, skewYLabel, skewY, ratio, scale] {
            container.addSubview(view)
        }
        guard modal("調整大小和扭曲", "每邊 1–8192 像素，最多 2,400 萬像素。扭曲單位是度。", container) else { return }
        let percent = mode.indexOfSelectedItem == 0
        var newWidth = width.integerValue
        var newHeight = height.integerValue
        if percent {
            newWidth = Int((Double(doc.width) * Double(newWidth) / 100).rounded())
            newHeight = Int((Double(doc.height) * Double(newHeight) / 100).rounded())
        }
        if ratio.state == .on {
            newHeight = percent
                ? Int((Double(doc.height) * Double(width.integerValue) / 100).rounded())
                : Int((Double(newWidth) * Double(doc.height) / Double(max(doc.width, 1))).rounded())
        }
        guard newWidth > 0, newHeight > 0, newWidth <= 8192, newHeight <= 8192,
              newWidth * newHeight <= 24_000_000 else {
            showError(PaintError.message("請輸入有效尺寸。")); return
        }
        doc.checkpoint()
        for index in doc.layers.indices {
            var raster = doc.layers[index].raster.resized(newWidth, newHeight, scale: scale.state == .on)
            raster = raster.skewed(horizontal: skewX.doubleValue, vertical: skewY.doubleValue)
            doc.layers[index].raster = raster
        }
        canvas.selection = nil
        update()
    }

    func stretchDialog() {
        canvas.finishText()
        let width = NSTextField(string: "100")
        let height = NSTextField(string: "100")
        let skewX = NSTextField(string: "0")
        let skewY = NSTextField(string: "0")
        width.frame = NSRect(x: 90, y: 78, width: 70, height: 24)
        height.frame = NSRect(x: 90, y: 48, width: 70, height: 24)
        skewX.frame = NSRect(x: 230, y: 78, width: 70, height: 24)
        skewY.frame = NSRect(x: 230, y: 48, width: 70, height: 24)
        let labels = [("水平 (%)", NSRect(x: 0, y: 82, width: 84, height: 18)),
                      ("垂直 (%)", NSRect(x: 0, y: 52, width: 84, height: 18)),
                      ("水平扭曲", NSRect(x: 170, y: 82, width: 58, height: 18)),
                      ("垂直扭曲", NSRect(x: 170, y: 52, width: 58, height: 18))]
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 310, height: 112))
        for (title, frame) in labels {
            let label = NSTextField(labelWithString: title)
            label.frame = frame
            container.addSubview(label)
        }
        for field in [width, height, skewX, skewY] { container.addSubview(field) }
        guard modal("延展/扭曲", "延展以百分比計算，扭曲以度計算。", container) else { return }
        let newWidth = Int((Double(doc.width) * width.doubleValue / 100).rounded())
        let newHeight = Int((Double(doc.height) * height.doubleValue / 100).rounded())
        guard newWidth > 0, newHeight > 0, newWidth <= 8192, newHeight <= 8192,
              newWidth * newHeight <= 24_000_000 else {
            showError(PaintError.message("請輸入有效尺寸。")); return
        }
        doc.checkpoint()
        for index in doc.layers.indices {
            var raster = doc.layers[index].raster.resized(newWidth, newHeight, scale: true)
            raster = raster.skewed(horizontal: skewX.doubleValue, vertical: skewY.doubleValue)
            doc.layers[index].raster = raster
        }
        canvas.selection = nil
        update()
    }

    func flipRotateDialog() {
        canvas.finishText()
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 180, height: 26))
        popup.addItems(withTitles: ["水平翻轉", "垂直翻轉", "向右旋轉 90°", "旋轉 180°", "向左旋轉 90°"])
        guard modal("翻轉/旋轉", "選擇要套用到整個影像的方向。", popup) else { return }
        let selected = popup.indexOfSelectedItem
        switch selected {
        case 0: transform("horizontal")
        case 1: transform("vertical")
        case 2: transform("rotate")
        case 3: transform("rotate"); transform("rotate")
        default:
            transform("rotate"); transform("rotate"); transform("rotate")
        }
    }

    func attributesDialog() {
        canvas.finishText()
        let units = NSPopUpButton(frame: NSRect(x: 70, y: 78, width: 120, height: 26))
        units.addItems(withTitles: ["像素", "英吋", "公分"])
        let width = NSTextField(string: String(doc.width))
        let height = NSTextField(string: String(doc.height))
        width.frame = NSRect(x: 70, y: 46, width: 80, height: 24)
        height.frame = NSRect(x: 70, y: 16, width: 80, height: 24)
        let mono = NSButton(checkboxWithTitle: "黑白", target: nil, action: nil)
        mono.frame = NSRect(x: 170, y: 46, width: 80, height: 20)
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 110))
        for (title, frame) in [("單位", NSRect(x: 8, y: 82, width: 50, height: 18)),
                               ("寬度", NSRect(x: 8, y: 50, width: 50, height: 18)),
                               ("高度", NSRect(x: 8, y: 20, width: 50, height: 18))] {
            let label = NSTextField(labelWithString: title)
            label.frame = frame
            container.addSubview(label)
        }
        for view in [units, width, height, mono] { container.addSubview(view) }
        guard modal("屬性", "變更畫布大小。不會縮放既有內容。96 DPI。", container) else { return }
        let factor = units.indexOfSelectedItem == 1 ? 96.0 : units.indexOfSelectedItem == 2 ? 96.0 / 2.54 : 1
        let newWidth = Int((width.doubleValue * factor).rounded())
        let newHeight = Int((height.doubleValue * factor).rounded())
        guard newWidth > 0, newHeight > 0, newWidth <= 8192, newHeight <= 8192,
              newWidth * newHeight <= 24_000_000 else {
            showError(PaintError.message("請輸入有效尺寸。")); return
        }
        doc.checkpoint()
        for index in doc.layers.indices {
            var raster = doc.layers[index].raster.resized(newWidth, newHeight, scale: false)
            if mono.state == .on { raster = raster.grayscale() }
            doc.layers[index].raster = raster
        }
        canvas.selection = nil
        update()
    }

    func invertColors() {
        canvas.finishText()
        doc.checkpoint()
        doc.layers[doc.active].raster = doc.layers[doc.active].raster.inverted()
        update()
    }

    func clearImage() {
        canvas.finishText()
        doc.checkpoint()
        doc.layers[doc.active].raster = Raster(doc.width, doc.height, white: true)
        canvas.selection = nil
        update()
    }

    func modal(_ title: String, _ info: String, _ view: NSView) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = info
        alert.accessoryView = view
        alert.addButton(withTitle: "確定")
        alert.addButton(withTitle: "取消")
        return alert.runModal() == .alertFirstButtonReturn
    }

    func toggleRulers() { showRulers.toggle(); layoutChrome() }
    func toggleStatusBar() { showStatus.toggle(); layoutChrome() }
    func toggleThumbnail() { showThumbnail.toggle(); update(); layoutChrome() }
    func toggleToolbox() { showToolbox.toggle(); layoutChrome() }
    func togglePalette() { showPalette.toggle(); layoutChrome() }
    func toggleTextBar() { showTextBar.toggle(); layoutChrome() }
    func toggleBitmapView() { viewingBitmap = true; layoutChrome() }

    func customZoom() {
        let field = NSTextField(string: "\(Int((canvas.zoom * 100).rounded()))")
        field.frame = NSRect(x: 0, y: 0, width: 120, height: 24)
        guard modal("自訂縮放", "輸入 10 到 800 的百分比。", field) else { return }
        setZoom(CGFloat(field.integerValue) / 100)
    }

    func helpTopic() {
        let alert = NSAlert()
        alert.messageText = "說明主題"
        alert.informativeText = "如需說明，請按一下「說明」功能表中的「說明主題」。\n\n左側工具箱由上到下是選取、橡皮擦、填色、放大鏡、鉛筆、筆刷、噴槍、文字與圖形。工具選項框會跟著目前工具改變。底部調色盤以滑鼠左鍵選前景色、右鍵選背景色，點兩下可編輯色彩。"
        alert.addButton(withTitle: "確定")
        alert.runModal()
    }

    func unavailableAI(_ name: String) {
        let alert = NSAlert()
        alert.messageText = name
        alert.informativeText = "這是 Microsoft 的雲端或 NPU 功能，這個 Mac 版本沒有代為連線。本機可用的是「移除背景」。"
        alert.addButton(withTitle: "確定")
        alert.runModal()
    }

    func rememberRecent(_ url: URL) {
        var list = UserDefaults.standard.stringArray(forKey: "paint.recent") ?? []
        list.removeAll { $0 == url.path }
        list.insert(url.path, at: 0)
        UserDefaults.standard.set(Array(list.prefix(4)), forKey: "paint.recent")
    }

    func setWallpaper(_ scaling: NSImageScaling) {
        let alert = NSAlert()
        alert.messageText = "設定成桌布"
        alert.informativeText = "要將目前影像設為這台 Mac 的桌面背景嗎？"
        alert.addButton(withTitle: "設定")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn, let screen = NSScreen.main else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("paint-wallpaper.png")
        do {
            try doc.composite().write(url)
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [.imageScaling: scaling.rawValue])
        } catch { showError(error) }
    }

    func copyToFile() {
        canvas.finishText()
        let panel = NSSavePanel()
        panel.title = "複製到"
        panel.nameFieldStringValue = "選取.png"
        panel.allowedContentTypes = [.png]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let raster = doc.layers[doc.active].raster.cropped(canvas.selection ?? CGRect(x: 0, y: 0, width: doc.width, height: doc.height))
        do { try raster.write(url) } catch { showError(error) }
    }

    func pasteFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .bmp, .tiff, .gif]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let raster = try Raster.load(url)
            let image = NSImage(cgImage: raster.image, size: NSSize(width: raster.width, height: raster.height))
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([image])
            pasteAction(nil)
        } catch { showError(error) }
    }

    func pickBackdrop() {
        pickingBackdrop = true
        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelChanged))
        panel.color = canvas.backdrop ?? .white
        panel.makeKeyAndOrderFront(nil)
    }

    func transform(_ kind: String) {
        canvas.finishText()
        doc.checkpoint()
        for index in doc.layers.indices { doc.layers[index].raster = doc.layers[index].raster.transformed(kind) }
        canvas.selection = nil
        update()
    }
    @objc func rotateAction(_ sender: Any?) { transform("rotate") }
    @objc func flipAction(_ sender: Any?) { transform("horizontal") }
    @objc func flipVertical(_ sender: Any?) { transform("vertical") }

    @objc func removeBackground(_ sender: Any?) {
        canvas.finishText()
        guard #available(macOS 14.0, *) else {
            showError(PaintError.message("自動移除背景需要 macOS 14 或更新版本。")); return
        }
        let sourceDocument = doc, revision = doc.revision, index = doc.active
        let image = doc.layers[index].raster.image
        statusBar.cursorText = "正在分析前景…"
        statusBar.needsDisplay = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                let request = VNGenerateForegroundInstanceMaskRequest()
                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                try handler.perform([request])
                guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
                    throw PaintError.message("找不到明確的前景物件。請選擇包含人物或物品的圖層。")
                }
                let buffer = try observation.generateMaskedImage(ofInstances: observation.allInstances,
                                                                 from: handler, croppedToInstancesExtent: false)
                let ci = CIImage(cvPixelBuffer: buffer)
                guard let cg = CIContext().createCGImage(ci, from: ci.extent) else {
                    throw PaintError.message("無法產生去背圖片。")
                }
                var raster = Raster(image.width, image.height)
                raster.draw { $0.draw(cg, in: CGRect(x: 0, y: 0, width: image.width, height: image.height)) }
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard self.doc === sourceDocument, self.doc.revision == revision else {
                        self.statusBar.cursorText = "畫布已變更，請重新執行"
                        self.statusBar.needsDisplay = true
                        return
                    }
                    self.doc.checkpoint()
                    self.doc.layers[index].raster = raster
                    self.update()
                }
            } catch {
                DispatchQueue.main.async { self?.showError(error) }
            }
        }
    }

    // MARK: Application menu bar

    func buildMenu() {
        let bar = NSMenu()
        NSApp.mainMenu = bar
        func submenu(_ title: String) -> NSMenu {
            let holder = NSMenuItem()
            holder.title = title
            let menu = NSMenu(title: title)
            holder.submenu = menu
            bar.addItem(holder)
            return menu
        }
        func entry(_ menu: NSMenu, _ title: String, _ selector: Selector,
                   _ key: String = "", _ modifiers: NSEvent.ModifierFlags = .command) {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            item.target = self
            item.keyEquivalentModifierMask = modifiers
            menu.addItem(item)
        }
        let app = submenu("小畫家")
        let about = NSMenuItem(title: "關於小畫家", action: #selector(AppDelegate.about), keyEquivalent: "")
        about.target = NSApp.delegate
        app.addItem(about)
        app.addItem(.separator())
        app.addItem(withTitle: "隱藏小畫家", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        app.addItem(withTitle: "結束小畫家", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let file = submenu("檔案")
        entry(file, "新增", #selector(newDocument), "n")
        entry(file, "開啟…", #selector(openDocument), "o")
        entry(file, "儲存", #selector(saveAction), "s")
        entry(file, "另存專案…", #selector(saveAsAction), "s", [.command, .shift])
        entry(file, "匯出圖片…", #selector(exportImage), "e", [.command, .shift])
        file.addItem(.separator())
        entry(file, "列印…", #selector(printAction), "p")

        let edit = submenu("編輯")
        entry(edit, "復原", #selector(undoAction), "z")
        entry(edit, "重做", #selector(redoAction), "z", [.command, .shift])
        edit.addItem(.separator())
        entry(edit, "剪下", #selector(cutAction), "x")
        entry(edit, "複製", #selector(copyAction), "c")
        entry(edit, "貼上", #selector(pasteAction), "v")
        entry(edit, "全選", #selector(selectAllAction), "a")
        entry(edit, "刪除選取範圍", #selector(clearAction))

        let image = submenu("影像")
        entry(image, "裁剪", #selector(cropAction), "k", [.command, .shift])
        entry(image, "調整大小和扭曲…", #selector(resizeAction), "r", [.command, .shift])
        entry(image, "向右旋轉 90°", #selector(rotateAction))
        entry(image, "水平翻轉", #selector(flipAction))
        entry(image, "垂直翻轉", #selector(flipVertical))
        entry(image, "移除背景", #selector(removeBackground))

        let layer = submenu("圖層")
        entry(layer, "新增圖層", #selector(addLayer), "n", [.command, .shift])
        entry(layer, "重新命名…", #selector(renameLayer))
        entry(layer, "圖層面板", #selector(toggleLayers), "l", [.command, .shift])

        let view = submenu("檢視")
        entry(view, "實際大小", #selector(actualSize), "0")
        entry(view, "符合視窗", #selector(fitCanvas), "1")
        entry(view, "格線", #selector(gridAction), "g")
        view.addItem(.separator())
        let appearance = NSMenuItem(title: "外觀", action: nil, keyEquivalent: "")
        let appearanceMenu = NSMenu(title: "外觀")
        let selectors: [Selector] = [#selector(chooseWin11), #selector(chooseWin10),
                                     #selector(chooseWin7), #selector(chooseWinXP)]
        for (index, candidate) in Skin.allCases.enumerated() {
            let entryItem = NSMenuItem(title: candidate.title, action: selectors[index], keyEquivalent: "")
            entryItem.target = self
            entryItem.state = candidate == Fluent.skin ? .on : .off
            appearanceMenu.addItem(entryItem)
        }
        appearance.submenu = appearanceMenu
        view.addItem(appearance)
    }
}

// A menu item that runs a Swift closure.
final class BlockMenuItem: NSMenuItem {
    private let handler: () -> Void
    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }
    required init(coder: NSCoder) { fatalError() }
    @objc private func fire() { handler() }
}

// A single row in the 圖層 panel.
final class LayerRow: NSView {
    var title = ""
    var thumbnail: NSImage?
    var isVisibleLayer = true
    var isActiveLayer = false
    var onSelect: (() -> Void)?
    var onToggle: (() -> Void)?
    private var hovering = false

    override var isFlipped: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
                                       owner: self))
    }
    override func mouseEntered(with event: NSEvent) { hovering = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovering = false; needsDisplay = true }

    private var eyeRect: NSRect { NSRect(x: bounds.maxX - 30, y: bounds.maxY - 26, width: 22, height: 22) }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if eyeRect.contains(point) { onToggle?() } else if bounds.contains(point) { onSelect?() }
    }

    override func draw(_ dirtyRect: NSRect) {
        let card = bounds.insetBy(dx: 2, dy: 2)
        Fluent.fill(card, radius: 6, color: isActiveLayer ? Fluent.checkedFill : (hovering ? Fluent.hoverFill : Fluent.chrome))
        Fluent.stroke(card, radius: 6, color: isActiveLayer ? Fluent.accent : Fluent.fieldBorder)
        let preview = NSRect(x: card.minX + 8, y: card.minY + 6, width: card.width - 16, height: card.height - 32)
        NSColor.white.setFill()
        NSBezierPath(rect: preview).fill()
        thumbnail?.draw(in: preview, from: .zero, operation: .sourceOver, fraction: isVisibleLayer ? 1 : 0.35,
                        respectFlipped: true, hints: [.interpolation: NSImageInterpolation.medium.rawValue])
        Fluent.fieldBorder.setStroke()
        let border = NSBezierPath(rect: preview)
        border.lineWidth = 1
        border.stroke()
        Fluent.text(title, in: NSRect(x: card.minX + 8, y: card.maxY - 24, width: card.width - 44, height: 20),
                    font: Fluent.ui(11.5), color: Fluent.ink, alignment: .left)
        GlyphPainter.draw(isVisibleLayer ? .eye : .eyeOff, in: eyeRect.insetBy(dx: 3, dy: 3),
                          tint: Fluent.inkSoft, accent: Fluent.inkSoft)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: PaintController!
    func applicationDidFinishLaunching(_ notification: Notification) {
        if controller == nil { controller = PaintController() }
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        controller.setZoom(1)
        controller.window?.makeFirstResponder(controller.canvas)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        controller == nil || controller.confirmDiscard() ? .terminateNow : .terminateCancel
    }
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        if controller == nil { controller = PaintController(); controller.showWindow(nil) }
        if let first = filenames.first { controller.open(URL(fileURLWithPath: first)) }
        sender.reply(toOpenOrPrint: .success)
    }
    @objc func about() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "小畫家 for Mac",
            .applicationVersion: "2.0.0",
            .credits: NSAttributedString(string: "以 Swift / AppKit 打造的原生繪圖工具，介面參考 Windows 11 小畫家。\n獨立開發，非 Microsoft 官方產品。")
        ])
    }
}
