import AppKit

var checks = 0
func check(_ condition:@autoclosure ()->Bool,_ message:String) {
    guard condition() else { fputs("FAIL: \(message)\n",stderr); exit(1) }
    checks += 1; print("PASS: \(message)")
}
let root = URL(fileURLWithPath:CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/paint-tests")
try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
var r = Raster(4,3)
r.pixels[0..<4] = [255,0,0,255][...]
r.pixels[(2*4+3)*4..<(2*4+3)*4+4] = [0,0,255,255][...]
try r.write(root.appendingPathComponent("corners.png"))
let loaded = try Raster.load(root.appendingPathComponent("corners.png"))
check(loaded.pixels == r.pixels,"PNG preserves pixel orientation and alpha")
let rotated = r.transformed("rotate")
check(rotated.width == 3 && rotated.height == 4,"90 degree rotation swaps dimensions")
check(Array(rotated.pixels[8..<12]) == [255,0,0,255],"90 degree rotation maps top-left to top-right")
check(r.transformed("horizontal").transformed("horizontal").pixels == r.pixels,"horizontal flip round trip")
check(r.transformed("vertical").transformed("vertical").pixels == r.pixels,"vertical flip round trip")
check(r.transformed("rotate").transformed("rotate").transformed("rotate").transformed("rotate").pixels == r.pixels,"four rotations preserve pixels")
var fill = Raster(5,5,white:true)
for y in 0..<5 { let i = (y*5+2)*4; fill.pixels[i..<i+4] = [0,0,0,255][...] }
fill.flood(CGPoint(x:0,y:0),color:.red)
check(Array(fill.pixels[0..<4]) == [255,0,0,255],"flood fill changes connected region")
check(Array(fill.pixels[16..<20]) == [255,255,255,255],"flood fill respects boundary")
var overlay = Raster(1,1); overlay.pixels = [128,0,0,128]
var bottom = Raster(1,1,white:true); bottom.paste(overlay,at:.zero)
check(bottom.pixels == [255,127,127,255],"premultiplied alpha composition")
let crop = r.cropped(CGRect(x:2,y:1,width:2,height:2))
check(crop.width == 2 && crop.height == 2 && Array(crop.pixels[12..<16]) == [0,0,255,255],"crop coordinates and dimensions")
var cleared = r; cleared.clear(CGRect(x:0,y:0,width:1,height:1))
check(Array(cleared.pixels[0..<4]) == [0,0,0,0],"erasing clears alpha")
let bigger = r.resized(8,6,scale:true)
check(Array(bigger.pixels[0..<4]) == [255,0,0,255] && Array(bigger.pixels[4..<8]) == [255,0,0,255],"nearest pixel resize preserves content")
let doc = PaintDocument(); doc.layers = [PaintLayer(name:"Test",raster:r)]
let initial = doc.revision
doc.checkpoint(); doc.layers[0].raster = rotated
check(doc.dirty,"editing marks document dirty")
doc.undo(); check(doc.width == 4 && doc.height == 3 && doc.revision == initial && !doc.dirty,"undo restores size and saved state")
doc.redo(); check(doc.width == 3 && doc.height == 4 && doc.dirty,"redo restores edit")
doc.layers.append(PaintLayer(name:"Overlay",visible:false,opacity:0.4,raster:Raster(3,4))); doc.active = 1
let project = root.appendingPathComponent("roundtrip.paintmac"); try doc.saveProject(project)
let reopened = PaintDocument(); try reopened.openProject(project)
check(reopened.layers.count == 2 && reopened.active == 1 && !reopened.layers[1].visible && reopened.layers[1].opacity == 0.4,"project preserves layers and metadata")
check(reopened.layers[0].raster.pixels == rotated.pixels,"project preserves exact pixels")
for ext in ["jpg","bmp","tiff"] {
    let url = root.appendingPathComponent("export.\(ext)"); try r.write(url); let image = try Raster.load(url)
    check(image.width == 4 && image.height == 3,"\(ext) export opens successfully")
}
let bad = root.appendingPathComponent("invalid.paintmac"); try Data("not a project".utf8).write(to:bad)
do { try reopened.openProject(bad); check(false,"invalid project rejected") } catch { check(true,"invalid project rejected") }
let app = NSApplication.shared
let textDoc = PaintDocument(); textDoc.layers = [PaintLayer(name:"Text",raster:Raster(200,100))]
let canvas = CanvasView(document:textDoc); canvas.fontSize = 24; canvas.addText("Paint",at:CGPoint(x:10,y:10))
let ink = textDoc.layers[0].raster.pixels.enumerated().filter { $0.offset % 4 == 3 && $0.element > 0 }
check(!ink.isEmpty,"native text renders to raster")
let inkRows = ink.map { $0.offset / 4 / 200 }
check((inkRows.min() ?? 100) < 40 && (inkRows.max() ?? 0) < 60,"text uses top-left canvas coordinates")
try textDoc.composite().write(root.appendingPathComponent("text.png"))
let strokeDoc = PaintDocument(); strokeDoc.layers = [PaintLayer(name:"Stroke",raster:Raster(200,100))]
let strokeCanvas = CanvasView(document:strokeDoc); strokeCanvas.lineWidth = 6
strokeCanvas.stroke(from:CGPoint(x:20,y:15),to:CGPoint(x:80,y:15))
func alpha(_ r:Raster,_ x:Int,_ y:Int)->UInt8 { r.pixels[(y*r.width+x)*4+3] }
check(alpha(strokeDoc.layers[0].raster,50,15) > 200,"brush lands at cursor y coordinate")
check(alpha(strokeDoc.layers[0].raster,50,85) == 0,"brush is not vertically mirrored")
strokeCanvas.tool = .rectangle; strokeCanvas.shape(from:CGPoint(x:20,y:25),to:CGPoint(x:60,y:40))
check(alpha(strokeDoc.layers[0].raster,40,25) > 200,"shape outline uses top-left coordinates")
strokeCanvas.tool = .eraser; strokeCanvas.stroke(from:CGPoint(x:40,y:15),to:CGPoint(x:60,y:15))
check(alpha(strokeDoc.layers[0].raster,50,15) == 0,"eraser clears at cursor position")
let inlineDoc = PaintDocument(); inlineDoc.layers = [PaintLayer(name:"Inline",raster:Raster(400,300))]
let inlineCanvas = CanvasView(document:inlineDoc)
inlineCanvas.tool = .text; inlineCanvas.zoom = 2
inlineCanvas.beginText(in:CGRect(x:45,y:65,width:150,height:120))
check(inlineCanvas.textEditor != nil && inlineDoc.undoStack.isEmpty,"choosing text position does not paint pixels")
inlineCanvas.textEditor?.string = "Hello\nPaint"
inlineCanvas.fontSize = 24
check(inlineCanvas.textEditor?.font?.pointSize == 24,"font size updates the live editor")
inlineCanvas.finishText()
let inlineInk = inlineDoc.layers[0].raster.pixels.enumerated().filter { $0.offset % 4 == 3 && $0.element > 0 }.map { $0.offset / 4 }
check(!inlineInk.isEmpty && inlineInk.allSatisfy { $0 % 400 >= 45 && $0 % 400 < 195 && $0 / 400 >= 65 && $0 / 400 < 185 },"inline text commits inside selected bounds regardless of zoom")
check((inlineInk.map { $0 / 400 }.max() ?? 0) > 95,"inline editor commits multiple lines")
check(inlineDoc.undoStack.count == 1 && inlineCanvas.textEditor == nil,"committing text creates one undo step and closes editor")
inlineDoc.undo()
check(inlineDoc.layers[0].raster.pixels.allSatisfy { $0 == 0 },"undo removes the complete text insertion")
inlineCanvas.beginText(in:CGRect(x:20,y:20,width:100,height:100)); inlineCanvas.textEditor?.string = "Cancel"
inlineCanvas.finishText(commit:false)
check(inlineDoc.layers[0].raster.pixels.allSatisfy { $0 == 0 } && inlineDoc.undoStack.isEmpty,"cancel leaves the document unchanged")
inlineCanvas.beginText(in:CGRect(x:20,y:20,width:100,height:100)); inlineCanvas.textEditor?.string = "Switch"
inlineCanvas.tool = .brush
check(inlineCanvas.textEditor == nil && inlineDoc.undoStack.count == 1,"switching tools commits pending text")
// Cancelling a drag must restore both the pixels and the existing undo/redo history.
let moveDoc = PaintDocument(); moveDoc.layers = [PaintLayer(name:"Move",raster:Raster(100,100,white:true))]
moveDoc.checkpoint(); moveDoc.layers[0].raster.clear(CGRect(x:80,y:80,width:10,height:10)); moveDoc.undo()
let beforeMove = moveDoc.snapshot, redoCount = moveDoc.redoStack.count
let moveCanvas = CanvasView(document:moveDoc); moveCanvas.tool = .select
moveCanvas.selection = CGRect(x:10,y:10,width:30,height:30)
func mouse(_ type:NSEvent.EventType,_ x:CGFloat,_ y:CGFloat)->NSEvent {
    NSEvent.mouseEvent(with:type,location:CGPoint(x:x,y:y),modifierFlags:[],timestamp:0,windowNumber:0,context:nil,eventNumber:0,clickCount:1,pressure:1)!
}
moveCanvas.mouseDown(with:mouse(.leftMouseDown,20,20))
moveCanvas.mouseDragged(with:mouse(.leftMouseDragged,40,40))
moveCanvas.cancelGesture()
check(moveDoc.layers[0].raster.pixels == beforeMove.layers[0].raster.pixels && moveDoc.revision == beforeMove.revision,"cancel selection move restores pixels and saved state")
check(moveDoc.undoStack.isEmpty && moveDoc.redoStack.count == redoCount,"cancel drag preserves undo and redo history")
moveCanvas.tool = .brush
moveCanvas.mouseDown(with:mouse(.leftMouseDown,20,20))
moveCanvas.mouseDragged(with:mouse(.leftMouseDragged,40,40))
moveCanvas.cancelGesture()
check(moveDoc.layers[0].raster.pixels == beforeMove.layers[0].raster.pixels,"cancel brush stroke restores original pixels")
let unsupported = root.appendingPathComponent("unsupported.gif")
do { try r.write(unsupported); check(false,"unsupported output rejected") } catch { check(!FileManager.default.fileExists(atPath:unsupported.path),"unsupported output rejected without creating a mislabeled file") }
print("PAINT_TESTS_OK \(checks) checks")
