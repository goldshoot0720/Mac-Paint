import AppKit
let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath:destination,withIntermediateDirectories:true)
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let px = size*scale
        let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:px,pixelsHigh:px,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:rep)
        let ctx = NSGraphicsContext.current!.cgContext; ctx.scaleBy(x:CGFloat(px)/512,y:CGFloat(px)/512)
        let outline = NSBezierPath(roundedRect:NSRect(x:24,y:24,width:464,height:464),xRadius:100,yRadius:100)
        NSColor(calibratedRed:0.15,green:0.46,blue:0.94,alpha:1).setFill(); outline.fill()
        let paper = NSBezierPath(roundedRect:NSRect(x:102,y:107,width:308,height:302),xRadius:24,yRadius:24)
        NSColor.white.setFill(); paper.fill()
        let stroke = NSBezierPath(); stroke.move(to:NSPoint(x:146,y:184)); stroke.curve(to:NSPoint(x:335,y:210),controlPoint1:NSPoint(x:205,y:293),controlPoint2:NSPoint(x:232,y:104)); stroke.lineWidth = 25; stroke.lineCapStyle = .round
        NSColor(calibratedRed:0.19,green:0.62,blue:0.95,alpha:1).setStroke(); stroke.stroke()
        for (index,color) in [NSColor.systemRed,.systemOrange,.systemGreen,.systemBlue].enumerated() { color.setFill(); NSBezierPath(ovalIn:NSRect(x:135+index*62,y:334,width:36,height:36)).fill() }
        let brush = NSBezierPath(); brush.move(to:NSPoint(x:297,y:226)); brush.line(to:NSPoint(x:365,y:313)); brush.lineWidth = 30; brush.lineCapStyle = .round; NSColor(calibratedRed:0.27,green:0.20,blue:0.46,alpha:1).setStroke(); brush.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)x\(size)" + (scale == 2 ? "@2x" : "") + ".png"
        try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:destination).appendingPathComponent(name))
    }
}
