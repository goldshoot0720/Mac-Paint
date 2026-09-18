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
        window.title = "未命名 - 小畫家"
        window.minSize = NSSize(width: 1160, height: 700)
        window.appearance = NSAppearance(named: .aqua)
        window.titlebarAppearsTransparent = true
        window.backgroundColor = Fluent.chrome
        window.delegate = self
        window.center()

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

    func buildChrome() {
        guard let content = window?.contentView else { return }
        root.background = Fluent.chrome
        root.frame = content.bounds
        root.autoresizingMask = [.width, .height]
        content.addSubview(root)

        menuRow.background = Fluent.chrome
        ribbon.background = Fluent.chrome
        ribbon.bottomBorder = Fluent.chromeBorder
        workspace.background = Fluent.workspace
        root.addSubview(menuRow)
        root.addSubview(ribbon)
        root.addSubview(workspace)
        root.addSubview(statusBar)

        buildMenuRow()
        buildRibbon()
        buildWorkspace()
        buildStatusBar()
        root.onLayout = { [weak self] in self?.layoutChrome() }
    }

    // MARK: Menu row

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
            x += button.frame.width + (button.kind == .text ? 2 : 2)
            if button.caption == "檢視" { x += 10 }
        }
    }

    // MARK: Ribbon

    func buildRibbon() {
        // 選取項目
        selectButton = RibbonButton(.selectRect, kind: .tall, chevron: true, width: 46, height: 52)
        selectButton.glyphSize = 22
        selectButton.toolTip = "選取項目"
        selectButton.onClick = { [weak self] in self?.selectTool(.select) }
        selectButton.setFrameOrigin(NSPoint(x: 8, y: 10))
        toolButtons[.select] = selectButton
        _ = group("選取項目", 62, [selectButton])

        // 影像
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

        // 工具
        var toolViews: [NSView] = []
        let toolGrid: [PaintTool] = [.pencil, .fill, .text, .eraser, .picker, .magnifier]
        for (index, tool) in toolGrid.enumerated() {
            let button = RibbonButton(tool.glyph, kind: .grid, width: 34, height: 34)
            button.glyphSize = 18
            button.toolTip = tool.rawValue
            button.onClick = { [weak self] in self?.selectTool(tool) }
            button.setFrameOrigin(NSPoint(x: 8 + CGFloat(index % 3) * 35, y: 6 + CGFloat(index / 3) * 36))
            toolButtons[tool] = button
            toolViews.append(button)
        }
        _ = group("工具", 119, toolViews)

        // 筆刷
        brushButton = RibbonButton(PaintTool.brush.glyph, kind: .tall, chevron: false, width: 46, height: 46)
        brushButton.glyphSize = 22
        brushButton.toolTip = "筆刷"
        brushButton.onClick = { [weak self] in guard let self else { return }; self.selectTool(self.activeBrush) }
        brushButton.setFrameOrigin(NSPoint(x: 8, y: 8))
        let brushChevron = RibbonButton(.chevron, kind: .grid, width: 46, height: 18)
        brushChevron.glyphSize = 11
        brushChevron.toolTip = "選擇筆刷"
        brushChevron.menuBuilder = { [weak self] in self?.brushMenu() ?? NSMenu() }
        brushChevron.setFrameOrigin(NSPoint(x: 8, y: 54))
        _ = group("筆刷", 62, [brushButton, brushChevron])

        // 形狀
        gallery.frame = NSRect(x: 8, y: 6, width: 138, height: 72)
        gallery.onSelect = { [weak self] tool in self?.selectTool(tool) }
        outlineButton = iconButton(.outline, "外框", 46, 34, chevron: true) {}
        outlineButton.menuBuilder = { [weak self] in self?.outlineMenu() ?? NSMenu() }
        outlineButton.setFrameOrigin(NSPoint(x: 152, y: 6))
        fillButton = iconButton(.fillStyle, "填滿", 46, 34, chevron: true) {}
        fillButton.menuBuilder = { [weak self] in self?.fillMenu() ?? NSMenu() }
        fillButton.setFrameOrigin(NSPoint(x: 152, y: 42))
        _ = group("形狀", 206, [gallery, outlineButton, fillButton])

        // 色彩
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

        // Copilot 與圖層
        let copilot = RibbonButton(.copilot, caption: "Copilot", kind: .tall, chevron: false, width: 54, height: 62)
        copilot.glyphSize = 24
        copilot.toolTip = "AI 工具"
        copilot.onClick = { [weak self] in self?.copilotAction(nil) }
        copilot.setFrameOrigin(NSPoint(x: 8, y: 8))
        let copilotGroup = group("", 70, [copilot])
        copilotGroup.showsSeparator = true

        layersButton = RibbonButton(.layers, caption: "圖層", kind: .tall, chevron: false, width: 54, height: 62)
        layersButton.glyphSize = 24
        layersButton.onClick = { [weak self] in self?.toggleLayers(nil) }
        layersButton.setFrameOrigin(NSPoint(x: 8, y: 8))
        let layerGroup = group("", 70, [layersButton])
        layerGroup.showsSeparator = false
    }

    func layoutRibbon() {
        var x: CGFloat = 6
        for container in groups {
            container.setFrameOrigin(NSPoint(x: x, y: 0))
            x += container.frame.width
        }
    }

    // MARK: Workspace

    func buildWorkspace() {
        scroll.hasHorizontalScroller = true
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = Fluent.workspace
        scroll.contentView.postsBoundsChangedNotifications = true
        stage.addSubview(canvas)
        scroll.documentView = stage
        canvas.wantsLayer = true
        canvas.layer?.shadowColor = NSColor.black.cgColor
        canvas.layer?.shadowOpacity = 0.18
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
        workspace.addSubview(dock)

        layerPanel.background = Fluent.chrome
        layerPanel.isHidden = true
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
            control.identifier = control.identifier ?? NSUserInterfaceItemIdentifier("layer-tool")
            layerPanel.addSubview(control)
        }
        layerOpacity.onChange = { [weak self] value in self?.setLayerOpacity(value) }
        layerPanel.addSubview(layerOpacity)
        workspace.addSubview(layerPanel)
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
        menuRow.frame = NSRect(x: 0, y: 0, width: size.width, height: PaintController.menuHeight)
        ribbon.frame = NSRect(x: 0, y: PaintController.menuHeight,
                              width: size.width, height: PaintController.ribbonHeight)
        let workTop = PaintController.menuHeight + PaintController.ribbonHeight
        let workHeight = max(120, size.height - workTop - PaintController.statusHeight)
        workspace.frame = NSRect(x: 0, y: workTop, width: size.width, height: workHeight)
        statusBar.frame = NSRect(x: 0, y: workTop + workHeight,
                                 width: size.width, height: PaintController.statusHeight)
        layoutMenuRow()
        layoutRibbon()

        let panelWidth = layerPanel.isHidden ? 0 : PaintController.layerWidth
        scroll.frame = NSRect(x: 0, y: 0, width: workspace.bounds.width - panelWidth,
                              height: workspace.bounds.height)
        layerPanel.frame = NSRect(x: workspace.bounds.width - panelWidth, y: 0,
                                  width: panelWidth, height: workspace.bounds.height)
        layoutLayerPanel()
        let dockHeight = min(260, max(150, workspace.bounds.height - 80))
        dock.frame = NSRect(x: 14, y: (workspace.bounds.height - dockHeight) / 2,
                            width: SliderDock.preferredWidth, height: dockHeight)
        layoutStage()
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
        // Bottom row of layer commands, then the opacity slider above it.
        let commands = tools.filter { $0.identifier?.rawValue != "layer-add" }
        var x: CGFloat = 12
        for button in commands {
            button.setFrameOrigin(NSPoint(x: x, y: bottom - 26))
            x += 32
        }
        bottom -= 34
        layerOpacity.frame = NSRect(x: 12, y: bottom - 22, width: width - 24, height: 20)
        bottom -= 30
        if let add = tools.first(where: { $0.identifier?.rawValue == "layer-add" }) {
            add.setFrameOrigin(NSPoint(x: width - 40, y: 10))
        }
        layerScroll.frame = NSRect(x: 8, y: 44, width: width - 16, height: max(60, bottom - 52))
        layerStack.setFrameSize(NSSize(width: layerScroll.contentSize.width,
                                       height: max(layerScroll.contentSize.height,
                                                   CGFloat(doc.layers.count) * 128 + 8)))
        layoutLayerRows()
    }

    func layoutStage() {
        let viewport = scroll.contentSize
        let size = NSSize(width: max(viewport.width, canvas.frame.width + 72),
                          height: max(viewport.height, canvas.frame.height + 72))
        if stage.frame.size != size { stage.setFrameSize(size) }
        canvas.setFrameOrigin(NSPoint(x: max(36, ((size.width - canvas.frame.width) / 2).rounded()),
                                      y: max(36, ((size.height - canvas.frame.height) / 2).rounded())))
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
        canvas.refresh()
        layoutStage()
        rebuildLayers()
    }

    func selectTool(_ tool: PaintTool) {
        canvas.tool = tool
        if PaintTool.brushes.contains(tool) {
            activeBrush = tool
            brushButton.glyph = tool.glyph
            brushButton.needsDisplay = true
        }
        for (candidate, button) in toolButtons { button.isChecked = candidate == tool }
        brushButton.isChecked = PaintTool.brushes.contains(tool)
        gallery.select(tool)
        dock.isHidden = !tool.usesSize
        outlineButton.isEnabledControl = tool.isShape
        fillButton.isEnabledControl = tool.isShape
        statusBar.cursorText = tool.rawValue
        statusBar.needsDisplay = true
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
    }

    // MARK: Menus in the ribbon

    func item(_ menu: NSMenu, _ title: String, _ handler: @escaping () -> Void, checked: Bool = false) {
        let entry = BlockMenuItem(title: title, handler: handler)
        entry.state = checked ? .on : .off
        menu.addItem(entry)
    }

    func fileMenu() -> NSMenu {
        let menu = NSMenu()
        item(menu, "新增") { [weak self] in self?.newDocument(nil) }
        item(menu, "開啟…") { [weak self] in self?.openDocument(nil) }
        menu.addItem(.separator())
        item(menu, "儲存") { [weak self] in _ = self?.save() }
        item(menu, "另存專案…") { [weak self] in _ = self?.save(asNew: true) }
        item(menu, "匯出圖片…") { [weak self] in self?.exportImage(nil) }
        menu.addItem(.separator())
        item(menu, "列印…") { [weak self] in self?.printAction(nil) }
        item(menu, "影像內容…") { [weak self] in self?.resizeAction(nil) }
        return menu
    }

    func editMenu() -> NSMenu {
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

    func viewMenu() -> NSMenu {
        let menu = NSMenu()
        item(menu, "放大") { [weak self] in self?.setZoom((self?.canvas.zoom ?? 1) * 1.25) }
        item(menu, "縮小") { [weak self] in self?.setZoom((self?.canvas.zoom ?? 1) / 1.25) }
        item(menu, "100%") { [weak self] in self?.setZoom(1) }
        item(menu, "符合視窗") { [weak self] in self?.fitCanvas(nil) }
        menu.addItem(.separator())
        item(menu, "格線", { [weak self] in self?.gridAction(nil) }, checked: canvas.grid)
        item(menu, "圖層面板", { [weak self] in self?.toggleLayers(nil) }, checked: !layerPanel.isHidden)
        menu.addItem(.separator())
        item(menu, "全螢幕") { [weak self] in self?.window?.toggleFullScreen(nil) }
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
        layerPanel.isHidden.toggle()
        layersButton.isChecked = !layerPanel.isHidden
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

    // MARK: Colour

    @objc func editColor(_ sender: Any?) {
        let panel = NSColorPanel.shared
        panel.setTarget(self)
        panel.setAction(#selector(colorPanelChanged))
        panel.color = editingPrimary ? canvas.primary : canvas.secondary
        panel.makeKeyAndOrderFront(nil)
    }
    @objc func colorPanelChanged(_ sender: NSColorPanel) {
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
        fitCanvas(nil)
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
            doc = next
            canvas.doc = next
            canvas.selection = nil
            update()
            fitCanvas(nil)
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
        alert.messageText = "小畫家設定"
        alert.informativeText = "此版本使用系統的淺色外觀，並以本機運算處理所有影像。"
        alert.addButton(withTitle: "好")
        alert.runModal()
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
        canvas.selection = CGRect(x: 0, y: 0, width: doc.width, height: doc.height)
        canvas.needsDisplay = true
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
        fitCanvas(nil)
    }

    @objc func resizeAction(_ sender: Any?) {
        canvas.finishText()
        let width = NSTextField(string: String(doc.width))
        let height = NSTextField(string: String(doc.height))
        width.frame = NSRect(x: 40, y: 64, width: 96, height: 24)
        height.frame = NSRect(x: 190, y: 64, width: 96, height: 24)
        let widthLabel = NSTextField(labelWithString: "水平")
        widthLabel.frame = NSRect(x: 0, y: 68, width: 38, height: 18)
        let heightLabel = NSTextField(labelWithString: "垂直")
        heightLabel.frame = NSRect(x: 148, y: 68, width: 38, height: 18)
        let ratio = NSButton(checkboxWithTitle: "維持外觀比例", target: nil, action: nil)
        ratio.frame = NSRect(x: 0, y: 36, width: 300, height: 20)
        ratio.state = .on
        let scale = NSButton(checkboxWithTitle: "縮放影像內容（取消則只改畫布大小）", target: nil, action: nil)
        scale.frame = NSRect(x: 0, y: 10, width: 320, height: 20)
        scale.state = .on
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 330, height: 96))
        for view in [widthLabel, width, heightLabel, height, ratio, scale] { container.addSubview(view) }
        let alert = NSAlert()
        alert.messageText = "調整大小和扭曲"
        alert.informativeText = "每邊 1–8192 像素，最多 2,400 萬像素。"
        alert.accessoryView = container
        alert.addButton(withTitle: "確定")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let newWidth = width.integerValue
        let newHeight = ratio.state == .on
            ? Int((Double(newWidth) * Double(doc.height) / Double(doc.width)).rounded())
            : height.integerValue
        guard newWidth > 0, newHeight > 0, newWidth <= 8192, newHeight <= 8192,
              newWidth * newHeight <= 24_000_000 else {
            showError(PaintError.message("請輸入有效尺寸。")); return
        }
        doc.checkpoint()
        for index in doc.layers.indices {
            doc.layers[index].raster = doc.layers[index].raster.resized(newWidth, newHeight, scale: scale.state == .on)
        }
        canvas.selection = nil
        update()
        fitCanvas(nil)
    }

    func transform(_ kind: String) {
        canvas.finishText()
        doc.checkpoint()
        for index in doc.layers.indices { doc.layers[index].raster = doc.layers[index].raster.transformed(kind) }
        canvas.selection = nil
        update()
        fitCanvas(nil)
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
        controller.fitCanvas(nil)
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
