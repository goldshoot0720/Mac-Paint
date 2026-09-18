import AppKit

enum PaintTool: String, CaseIterable {
    case select = "選取項目"
    case pencil = "鉛筆"
    case brush = "筆刷"
    case marker = "螢光筆"
    case spray = "噴槍"
    case calligraphy = "書法筆"
    case eraser = "橡皮擦"
    case fill = "填入色彩"
    case picker = "色彩選擇器"
    case text = "文字"
    case magnifier = "放大鏡"
    case line = "直線"
    case curve = "曲線"
    case ellipse = "橢圓形"
    case rectangle = "矩形"
    case rounded = "圓角矩形"
    case triangle = "三角形"
    case rightTriangle = "直角三角形"
    case diamond = "菱形"
    case pentagon = "五邊形"
    case hexagon = "六邊形"
    case arrow = "右箭頭"
    case arrowLeft = "左箭頭"
    case arrowUp = "上箭頭"
    case arrowDown = "下箭頭"
    case star4 = "四角星"
    case star = "五角星"
    case star6 = "六角星"
    case calloutRect = "圓角矩形圖說文字"
    case calloutOval = "橢圓形圖說文字"
    case calloutCloud = "雲朵圖說文字"
    case heart = "心形"
    case lightning = "閃電"

    var glyph: Glyph {
        switch self {
        case .select: return .selectRect
        case .pencil: return .pencil
        case .brush: return .brush
        case .marker: return .marker
        case .spray: return .spray
        case .calligraphy: return .pen
        case .eraser: return .eraser
        case .fill: return .bucket
        case .picker: return .dropper
        case .text: return .letterA
        case .magnifier: return .magnifier
        case .line: return .line
        case .curve: return .curve
        case .ellipse: return .oval
        case .rectangle: return .rectangle
        case .rounded: return .roundRectangle
        case .triangle: return .triangle
        case .rightTriangle: return .rightTriangle
        case .diamond: return .diamond
        case .pentagon: return .pentagon
        case .hexagon: return .hexagon
        case .arrow: return .arrowRight
        case .arrowLeft: return .arrowLeft
        case .arrowUp: return .arrowUp
        case .arrowDown: return .arrowDown
        case .star4: return .star4
        case .star: return .star5
        case .star6: return .star6
        case .calloutRect: return .calloutRectangle
        case .calloutOval: return .calloutOval
        case .calloutCloud: return .calloutCloud
        case .heart: return .heart
        case .lightning: return .lightning
        }
    }
    static let brushes: [PaintTool] = [.brush, .calligraphy, .marker, .spray]
    static let shapes: [PaintTool] = [.line, .curve, .ellipse, .rectangle, .rounded,
                                      .triangle, .rightTriangle, .diamond, .pentagon, .hexagon,
                                      .arrow, .arrowLeft, .arrowUp, .arrowDown,
                                      .star4, .star, .star6,
                                      .calloutRect, .calloutOval, .calloutCloud, .heart, .lightning]
    var isStroke: Bool { [.pencil, .brush, .marker, .spray, .calligraphy, .eraser].contains(self) }
    var isShape: Bool { PaintTool.shapes.contains(self) }
    var usesSize: Bool { isStroke || isShape }
}
final class CanvasTextEditor: NSTextView {
    var finish: ((Bool) -> Void)?
    override func cancelOperation(_ sender: Any?) { finish?(false) }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 && event.modifierFlags.contains(.command) && !hasMarkedText() { finish?(true); return }
        super.keyDown(with:event)
    }
}
final class TextEditorHost: NSView {
    override var isFlipped: Bool { true }
}
final class CanvasView: NSView {
    var doc: PaintDocument
    var tool: PaintTool = .brush { didSet { cancelGesture(); finishText(); textAnchor = nil; selection = nil; needsDisplay = true; window?.invalidateCursorRects(for:self) } }
    var primary = NSColor.black { didSet { updateTextStyle() } }
    var secondary = NSColor.white
    var lineWidth: CGFloat = 5
    var shapeFill = 0 // outline, fill, both
    var opacity: CGFloat = 1
    var curveStage = 0
    var curveStart = CGPoint.zero, curveEnd = CGPoint.zero
    var curveControl1 = CGPoint.zero, curveControl2 = CGPoint.zero
    var zoomRequest: ((Bool) -> Void)?
    var fontName = "Helvetica" { didSet { updateTextStyle() } }
    var fontSize: CGFloat = 28 { didSet { updateTextStyle() } }
    var boldText = false { didSet { updateTextStyle() } }
    var zoom: CGFloat = 1
    var grid = false
    var textAnchor: CGPoint? { didSet { needsDisplay = true } }
    var selection: CGRect?
    var changed: (() -> Void)?
    var status: ((String) -> Void)?
    var picked: ((NSColor) -> Void)?
    private(set) var textEditor: CanvasTextEditor?
    private var textHost: TextEditorHost?
    private(set) var textRect: CGRect?
    private var textLayer = 0
    private var textDocument: PaintDocument?
    private var pendingTextRect: CGRect?
    private var start = CGPoint.zero, last = CGPoint.zero
    private var base: Raster?
    private var floating: Raster?
    private var initialSelection: CGRect?
    private var moving = false, drawing = false
    private var gestureSnapshot: Snapshot?
    private var gestureUndo = [Snapshot](), gestureRedo = [Snapshot]()
    private var cached: NSImage?
    private var strokeColor = NSColor.black
    init(document: PaintDocument) { doc = document; super.init(frame:NSRect(x:0,y:0,width:1000,height:700)); refresh() }
    required init?(coder:NSCoder) { fatalError() }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func resetCursorRects() { addCursorRect(bounds,cursor:tool == .text ? .iBeam : .crosshair) }
    func refresh() {
        cached = NSImage(cgImage:doc.composite().image,size:NSSize(width:doc.width,height:doc.height))
        setFrameSize(NSSize(width:CGFloat(doc.width)*zoom,height:CGFloat(doc.height)*zoom)); layoutTextEditor(); needsDisplay = true
    }
    override func draw(_ dirtyRect:NSRect) {
        NSColor.white.setFill(); bounds.fill()
        let tile: CGFloat = 12
        NSColor(calibratedWhite:0.90,alpha:1).setFill()
        let area = dirtyRect.intersection(bounds)
        if !area.isEmpty { for y in Int(area.minY/tile)...Int(area.maxY/tile) { for x in Int(area.minX/tile)...Int(area.maxX/tile) where (x+y)%2 == 0 { NSRect(x:CGFloat(x)*tile,y:CGFloat(y)*tile,width:tile,height:tile).fill() } } }
        cached?.draw(in:bounds,from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:[.interpolation:NSImageInterpolation.none.rawValue])
        if let float = floating, let rect = selection {
            NSImage(cgImage:float.image,size:rect.size).draw(in:scaled(rect),from:.zero,operation:.sourceOver,fraction:1,respectFlipped:true,hints:nil)
        }
        if grid && zoom >= 4 {
            NSColor.black.withAlphaComponent(0.12).setStroke()
            let path = NSBezierPath(); path.lineWidth = 0.5
            for x in stride(from:area.minX - area.minX.truncatingRemainder(dividingBy:zoom),through:area.maxX,by:zoom) { path.move(to:NSPoint(x:x,y:area.minY)); path.line(to:NSPoint(x:x,y:area.maxY)) }
            for y in stride(from:area.minY - area.minY.truncatingRemainder(dividingBy:zoom),through:area.maxY,by:zoom) { path.move(to:NSPoint(x:area.minX,y:y)); path.line(to:NSPoint(x:area.maxX,y:y)) }; path.stroke()
        }
        if let r = pendingTextRect ?? textRect {
            let outline = NSBezierPath(rect:scaled(r).insetBy(dx:-1,dy:-1))
            outline.lineWidth = 1; outline.setLineDash([4,3],count:2,phase:0)
            NSColor.systemBlue.setStroke(); outline.stroke()
        }
        if let p = textAnchor {
            let marker = NSBezierPath()
            let x = p.x*zoom, y = p.y*zoom
            marker.move(to:NSPoint(x:x,y:y)); marker.line(to:NSPoint(x:x,y:y+fontSize*zoom))
            marker.move(to:NSPoint(x:x-5,y:y)); marker.line(to:NSPoint(x:x+5,y:y))
            NSColor.systemBlue.setStroke(); marker.lineWidth = 2; marker.stroke()
        }
        if let r = selection {
            let path = NSBezierPath(rect:scaled(r)); path.lineWidth = 1
            NSColor.white.setStroke(); path.stroke(); NSColor.black.setStroke(); path.setLineDash([4,4],count:2,phase:0); path.stroke()
            NSColor.white.setFill(); NSColor.systemBlue.setStroke()
            for p in [r.origin,CGPoint(x:r.maxX,y:r.minY),CGPoint(x:r.minX,y:r.maxY),CGPoint(x:r.maxX,y:r.maxY)] {
                let handle = NSBezierPath(rect:NSRect(x:p.x*zoom-3,y:p.y*zoom-3,width:6,height:6)); handle.fill(); handle.stroke()
            }
        }
    }
    func scaled(_ r:CGRect)->CGRect { CGRect(x:r.minX*zoom,y:r.minY*zoom,width:r.width*zoom,height:r.height*zoom) }
    func point(_ e:NSEvent)->CGPoint { let p = convert(e.locationInWindow,from:nil); return CGPoint(x:max(0,min(CGFloat(doc.width)-0.01,p.x/zoom)),y:max(0,min(CGFloat(doc.height)-0.01,p.y/zoom))) }
    override func mouseDown(with event:NSEvent) { begin(event, color:primary) }
    override func rightMouseDown(with event:NSEvent) { begin(event,color:secondary) }
    func begin(_ event:NSEvent,color:NSColor) {
        if textEditor != nil { finishText(); return }
        window?.makeFirstResponder(self)
        guard doc.layers[doc.active].visible else { status?("請先顯示目前圖層，再進行編輯。"); NSSound.beep(); return }
        start = point(event); last = start; strokeColor = color
        if tool == .picker {
            let r = doc.composite(), i = (Int(start.y)*r.width+Int(start.x))*4
            let a = CGFloat(r.pixels[i+3])/255
            let c = NSColor(red:a > 0 ? CGFloat(r.pixels[i])/255/a : 0,green:a > 0 ? CGFloat(r.pixels[i+1])/255/a : 0,blue:a > 0 ? CGFloat(r.pixels[i+2])/255/a : 0,alpha:a)
            primary = c; picked?(c); return
        }
        if tool == .magnifier { zoomRequest?(color == primary); return }
        if tool == .text { textAnchor = start; pendingTextRect = nil; drawing = true; status?("拖出文字框，放開後直接輸入；Esc 取消"); return }
        if tool == .curve {
            if curveStage == 0 {
                gestureSnapshot = doc.snapshot; gestureUndo = doc.undoStack; gestureRedo = doc.redoStack
                selection = nil; doc.checkpoint(); base = doc.layers[doc.active].raster
                curveStart = start; curveEnd = start; curveControl1 = start; curveControl2 = start
                curveStage = 1
            }
            drawing = true
            status?("曲線 · 拖曳定義直線，再拖曳兩次調整弧度")
            return
        }
        gestureSnapshot = doc.snapshot; gestureUndo = doc.undoStack; gestureRedo = doc.redoStack
        if tool == .select {
            if let rect = selection, rect.contains(start) {
                moving = true; initialSelection = rect; floating = doc.layers[doc.active].raster.cropped(rect)
                doc.checkpoint(); doc.layers[doc.active].raster.clear(rect); refresh()
            } else { selection = nil; moving = false }
            drawing = true; return
        }
        selection = nil; doc.checkpoint(); drawing = true
        base = doc.layers[doc.active].raster
        if tool == .fill { doc.layers[doc.active].raster.flood(start,color:color); drawing = false; base = nil; clearGesture(); refresh(); changed?(); return }
        if tool.isStroke { stroke(from:start,to:start) }
        refresh(); changed?()
    }
    override func mouseDragged(with event:NSEvent) { drag(event) }
    override func rightMouseDragged(with event:NSEvent) { drag(event) }
    func drag(_ event:NSEvent) {
        guard drawing else { return }
        var p = point(event)
        if tool == .text { pendingTextRect = rect(start,p); needsDisplay = true; return }
        if tool == .curve {
            if let base { doc.layers[doc.active].raster = base }
            if curveStage <= 1 {
                curveEnd = p
                curveControl1 = CGPoint(x:curveStart.x+(p.x-curveStart.x)/3,y:curveStart.y+(p.y-curveStart.y)/3)
                curveControl2 = CGPoint(x:curveStart.x+(p.x-curveStart.x)*2/3,y:curveStart.y+(p.y-curveStart.y)*2/3)
            } else if curveStage == 2 { curveControl1 = p } else { curveControl2 = p }
            drawCurve(); last = p; refresh()
            status?("\(Int(p.x)), \(Int(p.y)) 像素")
            return
        }
        if tool == .select {
            if moving, let r = initialSelection { selection = r.offsetBy(dx:(p.x-start.x).rounded(),dy:(p.y-start.y).rounded()) }
            else { selection = rect(start,p).integral.intersection(CGRect(x:0,y:0,width:doc.width,height:doc.height)) }
        } else if tool.isStroke { stroke(from:last,to:p) }
        else if tool.isShape {
            if event.modifierFlags.contains(.shift) {
                let d = max(abs(p.x-start.x),abs(p.y-start.y)); p = CGPoint(x:start.x+(p.x >= start.x ? d : -d),y:start.y+(p.y >= start.y ? d : -d))
            }
            if let base { doc.layers[doc.active].raster = base }
            shape(from:start,to:p)
        }
        last = p; refresh()
        status?("\(Int(p.x)), \(Int(p.y)) px" + (selection.map { "   ·   選取 \(Int($0.width)) × \(Int($0.height))" } ?? ""))
    }
    override func mouseUp(with event:NSEvent) { end(event) }
    override func rightMouseUp(with event:NSEvent) { end(event) }
    func end(_ event:NSEvent) {
        guard drawing else { return }
        drag(event)
        if tool == .curve {
            drawing = false
            if curveStage >= 3 { curveStage = 0; base = nil; clearGesture(); refresh(); changed?() }
            else { curveStage += 1 }
            return
        }
        if tool == .text {
            drawing = false
            let proposed = pendingTextRect ?? .zero
            let box = proposed.width >= 8 && proposed.height >= 8 ? proposed : CGRect(x:start.x,y:start.y,width:320,height:max(100,fontSize*3))
            textAnchor = nil; pendingTextRect = nil; beginText(in:box); return
        }
        if moving, let floating, let selection { doc.layers[doc.active].raster.paste(floating,at:selection.origin) }
        floating = nil; moving = false; drawing = false; base = nil; clearGesture()
        if let r = selection, r.width < 1 || r.height < 1 { selection = nil }
        refresh(); changed?()
    }
    func rect(_ a:CGPoint,_ b:CGPoint)->CGRect { CGRect(x:min(a.x,b.x),y:min(a.y,b.y),width:abs(a.x-b.x),height:abs(a.y-b.y)) }
    func stroke(from a:CGPoint,to b:CGPoint) {
        let width = tool == .pencil ? min(lineWidth,3) : lineWidth
        let currentTool = tool, color = strokeColor, alpha = opacity
        doc.layers[doc.active].raster.drawTopLeft { ctx in
            ctx.setAlpha(alpha)
            ctx.setLineWidth(width); ctx.setLineCap(.round); ctx.setLineJoin(.round)
            ctx.setStrokeColor(color.cgColor); ctx.setFillColor(color.cgColor)
            if currentTool == .eraser { ctx.setBlendMode(.clear); ctx.setAlpha(1) }
            if currentTool == .calligraphy { ctx.setLineCap(.square); ctx.setLineWidth(width*1.3) }
            if currentTool == .marker { ctx.setAlpha(0.18*alpha); ctx.setLineWidth(width*3) }
            if currentTool == .spray {
                for _ in 0..<max(12,Int(width)*2) {
                    let theta = CGFloat.random(in:0...(.pi*2)), r = CGFloat.random(in:0...1).squareRoot()*width*2
                    ctx.fillEllipse(in:CGRect(x:b.x+cos(theta)*r,y:b.y+sin(theta)*r,width:1.5,height:1.5))
                }
            } else if a == b { ctx.fillEllipse(in:CGRect(x:a.x-width/2,y:a.y-width/2,width:width,height:width)) }
            else { ctx.move(to:a); ctx.addLine(to:b); ctx.strokePath() }
        }
    }
    func geometry(_ tool:PaintTool,_ r:CGRect,_ a:CGPoint,_ b:CGPoint)->CGPath {
        let path = CGMutablePath()
        func poly(_ points:[CGPoint]) { path.addLines(between:points); path.closeSubpath() }
        func star(_ count:Int,_ innerRatio:CGFloat) {
            var pts = [CGPoint]()
            for i in 0..<(count*2) {
                let angle = CGFloat(i)*CGFloat.pi/CGFloat(count)-CGFloat.pi/2
                let f:CGFloat = i%2 == 0 ? 0.5 : innerRatio
                pts.append(CGPoint(x:r.midX+cos(angle)*r.width*f,y:r.midY+sin(angle)*r.height*f))
            }
            poly(pts)
        }
        func regular(_ sides:Int,_ rotation:CGFloat) {
            var pts = [CGPoint]()
            for i in 0..<sides {
                let angle = rotation+CGFloat(i)*2*CGFloat.pi/CGFloat(sides)
                pts.append(CGPoint(x:r.midX+cos(angle)*r.width/2,y:r.midY+sin(angle)*r.height/2))
            }
            poly(pts)
        }
        func x(_ f:CGFloat)->CGFloat { r.minX+r.width*f }
        func y(_ f:CGFloat)->CGFloat { r.minY+r.height*f }
        switch tool {
        case .line, .curve: path.move(to:a); path.addLine(to:b)
        case .rectangle: path.addRect(r)
        case .rounded: path.addRoundedRect(in:r,cornerWidth:min(18,r.width/5),cornerHeight:min(18,r.height/5))
        case .ellipse: path.addEllipse(in:r)
        case .triangle: poly([CGPoint(x:r.midX,y:r.minY),CGPoint(x:r.maxX,y:r.maxY),CGPoint(x:r.minX,y:r.maxY)])
        case .rightTriangle: poly([CGPoint(x:r.minX,y:r.minY),CGPoint(x:r.maxX,y:r.maxY),CGPoint(x:r.minX,y:r.maxY)])
        case .diamond: poly([CGPoint(x:r.midX,y:r.minY),CGPoint(x:r.maxX,y:r.midY),CGPoint(x:r.midX,y:r.maxY),CGPoint(x:r.minX,y:r.midY)])
        case .pentagon: regular(5,-CGFloat.pi/2)
        case .hexagon: regular(6,0)
        case .arrow: poly([CGPoint(x:x(0),y:y(0.3)),CGPoint(x:x(0.6),y:y(0.3)),CGPoint(x:x(0.6),y:y(0)),CGPoint(x:x(1),y:y(0.5)),CGPoint(x:x(0.6),y:y(1)),CGPoint(x:x(0.6),y:y(0.7)),CGPoint(x:x(0),y:y(0.7))])
        case .arrowLeft: poly([CGPoint(x:x(1),y:y(0.3)),CGPoint(x:x(0.4),y:y(0.3)),CGPoint(x:x(0.4),y:y(0)),CGPoint(x:x(0),y:y(0.5)),CGPoint(x:x(0.4),y:y(1)),CGPoint(x:x(0.4),y:y(0.7)),CGPoint(x:x(1),y:y(0.7))])
        case .arrowUp: poly([CGPoint(x:x(0.3),y:y(1)),CGPoint(x:x(0.3),y:y(0.4)),CGPoint(x:x(0),y:y(0.4)),CGPoint(x:x(0.5),y:y(0)),CGPoint(x:x(1),y:y(0.4)),CGPoint(x:x(0.7),y:y(0.4)),CGPoint(x:x(0.7),y:y(1))])
        case .arrowDown: poly([CGPoint(x:x(0.3),y:y(0)),CGPoint(x:x(0.3),y:y(0.6)),CGPoint(x:x(0),y:y(0.6)),CGPoint(x:x(0.5),y:y(1)),CGPoint(x:x(1),y:y(0.6)),CGPoint(x:x(0.7),y:y(0.6)),CGPoint(x:x(0.7),y:y(0))])
        case .star4: star(4,0.17)
        case .star: star(5,0.21)
        case .star6: star(6,0.27)
        case .calloutRect:
            let body = CGRect(x:r.minX,y:r.minY,width:r.width,height:r.height*0.74)
            path.addRoundedRect(in:body,cornerWidth:min(16,body.width/6),cornerHeight:min(16,body.height/4))
            path.move(to:CGPoint(x:x(0.24),y:body.maxY-1))
            path.addLine(to:CGPoint(x:x(0.18),y:r.maxY))
            path.addLine(to:CGPoint(x:x(0.46),y:body.maxY-1))
            path.closeSubpath()
        case .calloutOval:
            let body = CGRect(x:r.minX,y:r.minY,width:r.width,height:r.height*0.74)
            path.addEllipse(in:body)
            path.move(to:CGPoint(x:x(0.26),y:body.maxY-body.height*0.08))
            path.addLine(to:CGPoint(x:x(0.18),y:r.maxY))
            path.addLine(to:CGPoint(x:x(0.46),y:body.maxY-body.height*0.02))
            path.closeSubpath()
        case .calloutCloud:
            path.addEllipse(in:CGRect(x:x(0),y:y(0.22),width:r.width*0.44,height:r.height*0.42))
            path.addEllipse(in:CGRect(x:x(0.24),y:y(0.02),width:r.width*0.48,height:r.height*0.48))
            path.addEllipse(in:CGRect(x:x(0.54),y:y(0.2),width:r.width*0.46,height:r.height*0.44))
            path.addEllipse(in:CGRect(x:x(0.3),y:y(0.36),width:r.width*0.42,height:r.height*0.34))
            path.addEllipse(in:CGRect(x:x(0.2),y:y(0.72),width:r.width*0.13,height:r.height*0.14))
            path.addEllipse(in:CGRect(x:x(0.11),y:y(0.86),width:r.width*0.09,height:r.height*0.1))
        case .heart:
            path.move(to:CGPoint(x:r.midX,y:r.maxY))
            path.addCurve(to:CGPoint(x:r.minX,y:y(0.3)),control1:CGPoint(x:x(0.12),y:y(0.78)),control2:CGPoint(x:r.minX,y:y(0.54)))
            path.addCurve(to:CGPoint(x:r.midX,y:y(0.22)),control1:CGPoint(x:r.minX,y:y(0.02)),control2:CGPoint(x:x(0.36),y:y(0.0)))
            path.addCurve(to:CGPoint(x:r.maxX,y:y(0.3)),control1:CGPoint(x:x(0.64),y:y(0.0)),control2:CGPoint(x:r.maxX,y:y(0.02)))
            path.addCurve(to:CGPoint(x:r.midX,y:r.maxY),control1:CGPoint(x:r.maxX,y:y(0.54)),control2:CGPoint(x:x(0.88),y:y(0.78)))
            path.closeSubpath()
        case .lightning:
            poly([CGPoint(x:x(0.62),y:y(0)),CGPoint(x:x(0.16),y:y(0.52)),CGPoint(x:x(0.46),y:y(0.52)),CGPoint(x:x(0.36),y:y(1)),CGPoint(x:x(0.84),y:y(0.44)),CGPoint(x:x(0.54),y:y(0.44))])
        default: break
        }
        return path
    }
    func shape(from a:CGPoint,to b:CGPoint) {
        let r = rect(a,b)
        let path = geometry(tool,r,a,b)
        paint(path,closed:tool != .line && tool != .curve)
    }
    func paint(_ path:CGPath,closed:Bool) {
        let width = lineWidth, alpha = opacity, mode = shapeFill, stroke = strokeColor, back = secondary
        doc.layers[doc.active].raster.drawTopLeft { ctx in
            ctx.setAlpha(alpha)
            ctx.addPath(path)
            ctx.setLineWidth(width); ctx.setLineJoin(.round); ctx.setLineCap(.round)
            ctx.setStrokeColor(stroke.cgColor); ctx.setFillColor(back.cgColor)
            ctx.drawPath(using: !closed || mode == 0 ? .stroke : mode == 1 ? .fill : .fillStroke)
        }
    }
    // Windows Paint curves: drag the line, then drag up to two bends before it commits.
    func drawCurve() {
        let path = CGMutablePath()
        path.move(to:curveStart)
        path.addCurve(to:curveEnd,control1:curveControl1,control2:curveControl2)
        paint(path,closed:false)
    }
    func beginText(in proposed: CGRect) {
        finishText()
        let r = proposed.intersection(CGRect(x:0,y:0,width:doc.width,height:doc.height))
        guard !r.isNull, r.width >= 1, r.height >= 1, doc.layers[doc.active].visible else { return }
        selection = nil; textRect = r; textLayer = doc.active; textDocument = doc
        let host = TextEditorHost(frame:scaled(r))
        let editor = CanvasTextEditor(frame:CGRect(origin:.zero,size:r.size))
        editor.isRichText = false; editor.drawsBackground = false; editor.allowsUndo = true
        editor.isHorizontallyResizable = false; editor.isVerticallyResizable = false
        editor.textContainerInset = .zero; editor.textContainer?.lineFragmentPadding = 0
        editor.textContainer?.containerSize = r.size
        editor.textContainer?.widthTracksTextView = true
        editor.setAccessibilityLabel("畫布文字框")
        editor.finish = { [weak self] commit in self?.finishText(commit:commit) }
        host.addSubview(editor); addSubview(host)
        textHost = host; textEditor = editor; layoutTextEditor(); updateTextStyle()
        window?.makeFirstResponder(editor); needsDisplay = true
        status?("直接輸入文字 · Enter 換行 · 點框外或 ⌘Enter 完成 · Esc 取消")
    }
    func layoutTextEditor() {
        guard let r = textRect, let host = textHost else { return }
        host.frame = scaled(r); host.bounds = CGRect(origin:.zero,size:r.size)
    }
    func updateTextStyle() {
        guard let editor = textEditor else { return }
        let base = NSFont(name:fontName,size:fontSize) ?? .systemFont(ofSize:fontSize)
        editor.font = boldText ? NSFontManager.shared.convert(base,toHaveTrait:.boldFontMask) : base
        editor.textColor = primary; editor.insertionPointColor = primary
    }
    func finishText(commit: Bool = true) {
        guard let editor = textEditor, let r = textRect else { return }
        // Render the same text layout used on screen, preserving line wrapping and position.
        let target = textDocument
        let canvasWidth = doc.width
        let canvasHeight = doc.height
        textEditor = nil; textRect = nil; textDocument = nil
        if commit, !editor.string.isEmpty, let target, target === doc, target.layers.indices.contains(textLayer),
           let manager = editor.layoutManager, let container = editor.textContainer {
            manager.ensureLayout(for:container)
            let glyphs = manager.glyphRange(for:container)
            let image = NSImage(size:NSSize(width:canvasWidth,height:canvasHeight))
            image.lockFocusFlipped(true)
            NSGraphicsContext.saveGraphicsState(); NSBezierPath(rect:r).addClip()
            manager.drawBackground(forGlyphRange:glyphs,at:r.origin)
            manager.drawGlyphs(forGlyphRange:glyphs,at:r.origin)
            NSGraphicsContext.restoreGraphicsState(); image.unlockFocus()
            if let cg = image.cgImage(forProposedRect:nil,context:nil,hints:nil) {
                doc.checkpoint()
                let destination = CGRect(x:0,y:0,width:canvasWidth,height:canvasHeight)
                var raster = doc.layers[textLayer].raster
                raster.draw { $0.draw(cg,in:destination) }
                doc.layers[textLayer].raster = raster
            }
        }
        textHost?.removeFromSuperview(); textHost = nil
        window?.makeFirstResponder(self); refresh(); changed?()
        status?("文字 · 點選位置或拖出文字框")
    }
    func addText(_ text:String,at p:CGPoint) {
        guard !text.isEmpty else { return }; doc.checkpoint()
        let base = NSFont(name:fontName,size:fontSize) ?? .systemFont(ofSize:fontSize)
        let font = boldText ? NSFontManager.shared.convert(base,toHaveTrait:.boldFontMask) : base
        let attr = NSAttributedString(string:text,attributes:[.font:font,.foregroundColor:primary])
        let textBounds = NSRect(x:p.x,y:p.y,width:CGFloat(doc.width)-p.x,height:CGFloat(doc.height)-p.y)
        let textImage = NSImage(size:NSSize(width:doc.width,height:doc.height))
        textImage.lockFocusFlipped(true)
        attr.draw(in:textBounds)
        textImage.unlockFocus()
        if let cg = textImage.cgImage(forProposedRect:nil,context:nil,hints:nil) {
            let destination = CGRect(x:0,y:0,width:doc.width,height:doc.height)
            doc.layers[doc.active].raster.draw { $0.draw(cg,in:destination) }
        }
        refresh(); changed?()
    }
    private func clearGesture() {
        gestureSnapshot = nil; gestureUndo.removeAll(); gestureRedo.removeAll()
    }
    func cancelGesture() {
        if drawing || curveStage > 0, let snapshot = gestureSnapshot {
            doc.restore(snapshot); doc.undoStack = gestureUndo; doc.redoStack = gestureRedo
        }
        clearGesture(); drawing = false; moving = false; floating = nil; base = nil
        curveStage = 0
        initialSelection = nil; textAnchor = nil; pendingTextRect = nil; selection = nil
        refresh(); changed?()
    }
    override func keyDown(with event:NSEvent) {
        if event.keyCode == 53 { cancelGesture(); return }
        if event.keyCode == 51 || event.keyCode == 117 { deleteSelection(); return }
        super.keyDown(with:event)
    }
    func deleteSelection() {
        guard let r = selection else { return }; doc.checkpoint(); doc.layers[doc.active].raster.clear(r); selection = nil; refresh(); changed?()
    }
}
