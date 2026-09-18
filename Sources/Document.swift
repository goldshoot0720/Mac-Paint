import AppKit
import UniformTypeIdentifiers

struct Raster {
    var width: Int
    var height: Int
    var pixels: [UInt8]
    init(_ width: Int, _ height: Int, white: Bool = false) {
        self.width = width; self.height = height
        pixels = [UInt8](repeating: white ? 255 : 0, count: width * height * 4)
    }
    var image: CGImage {
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }
    mutating func draw(_ body: (CGContext) -> Void) {
        let w = width, h = height
        pixels.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            body(ctx)
        }
    }
    // Pixel storage and the canvas use a top-left origin; Quartz paths use bottom-left.
    mutating func drawTopLeft(_ body: (CGContext) -> Void) {
        let h = height
        draw { context in
            context.translateBy(x:0,y:CGFloat(h))
            context.scaleBy(x:1,y:-1)
            body(context)
        }
    }
    static func load(_ url: URL) throws -> Raster {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil),
              cg.width <= 8192, cg.height <= 8192, cg.width * cg.height <= 24_000_000 else {
            throw PaintError.message("無法開啟圖片，或圖片超過 2,400 萬像素／單邊 8192 像素。")
        }
        var r = Raster(cg.width, cg.height)
        r.draw { $0.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height)) }
        return r
    }
    func write(_ url: URL) throws {
        let ext = url.pathExtension.lowercased()
        guard ["png", "jpg", "jpeg", "bmp", "tif", "tiff"].contains(ext) else {
            throw PaintError.message("不支援此輸出格式，請選擇 PNG、JPEG、BMP 或 TIFF。")
        }
        let type: UTType = ext == "jpg" || ext == "jpeg" ? .jpeg : ext == "bmp" ? .bmp : ext == "tiff" || ext == "tif" ? .tiff : .png
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else { throw PaintError.message("無法建立圖片檔案。") }
        var output = self
        if type == .jpeg || type == .bmp {
            for i in stride(from: 0, to: output.pixels.count, by: 4) {
                let a = Int(output.pixels[i+3])
                for c in 0..<3 { output.pixels[i+c] = UInt8(min(255, Int(output.pixels[i+c]) + 255 - a)) }
                output.pixels[i+3] = 255
            }
        }
        CGImageDestinationAddImage(destination, output.image, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw PaintError.message("儲存失敗，請檢查目的資料夾。") }
    }
    mutating func paste(_ source: Raster, at origin: CGPoint) {
        let ox = Int(origin.x), oy = Int(origin.y)
        for y in 0..<source.height where y + oy >= 0 && y + oy < height {
            for x in 0..<source.width where x + ox >= 0 && x + ox < width {
                let s = (y * source.width + x) * 4, d = ((y+oy) * width + x+ox) * 4
                let a = Int(source.pixels[s+3]), inv = 255-a
                for c in 0..<4 { pixels[d+c] = UInt8(min(255, Int(source.pixels[s+c]) + (Int(pixels[d+c]) * inv + 127) / 255)) }
            }
        }
    }
    func cropped(_ rect: CGRect) -> Raster {
        let r = rect.integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !r.isNull, r.width > 0, r.height > 0 else { return Raster(1,1) }
        var out = Raster(Int(r.width), Int(r.height))
        for y in 0..<out.height {
            let start = ((Int(r.minY)+y)*width+Int(r.minX))*4
            out.pixels.replaceSubrange(y*out.width*4..<(y+1)*out.width*4, with: pixels[start..<start+out.width*4])
        }
        return out
    }
    mutating func clear(_ rect: CGRect) {
        let r = rect.integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard !r.isNull else { return }
        for y in Int(r.minY)..<Int(r.maxY) { for x in Int(r.minX)..<Int(r.maxX) {
            let i = (y*width+x)*4; pixels[i..<i+4] = [0,0,0,0][...]
        }}
    }
    mutating func flood(_ point: CGPoint, color: NSColor, tolerance: Int = 12) {
        let x = Int(point.x), y = Int(point.y)
        guard x >= 0, y >= 0, x < width, y < height else { return }
        let start = y*width+x, target = Array(pixels[start*4..<start*4+4]), replacement = color.rgba
        guard target != replacement else { return }
        var visited = [Bool](repeating: false, count: width*height), queue = [start], head = 0
        visited[start] = true
        while head < queue.count {
            let p = queue[head]; head += 1; let i = p*4
            guard (0..<4).allSatisfy({ abs(Int(pixels[i+$0])-Int(target[$0])) <= tolerance }) else { continue }
            pixels.replaceSubrange(i..<i+4, with: replacement)
            let px = p % width, py = p / width
            for n in [px > 0 ? p-1 : -1, px+1 < width ? p+1 : -1, py > 0 ? p-width : -1, py+1 < height ? p+width : -1] where n >= 0 {
                if !visited[n] { visited[n] = true; queue.append(n) }
            }
        }
    }
    func transformed(_ kind: String) -> Raster {
        let rotate = kind == "rotate"
        var out = Raster(rotate ? height : width, rotate ? width : height)
        for y in 0..<height { for x in 0..<width {
            let dx = rotate ? height-1-y : kind == "horizontal" ? width-1-x : x
            let dy = rotate ? x : kind == "vertical" ? height-1-y : y
            let s = (y*width+x)*4, d = (dy*out.width+dx)*4
            out.pixels.replaceSubrange(d..<d+4, with: pixels[s..<s+4])
        }}
        return out
    }
    func resized(_ w: Int, _ h: Int, scale: Bool) -> Raster {
        var out = Raster(w,h)
        if !scale { out.paste(self, at: .zero); return out }
        for y in 0..<h { for x in 0..<w {
            let s = ((y*height/h)*width+(x*width/w))*4, d = (y*w+x)*4
            out.pixels.replaceSubrange(d..<d+4, with: pixels[s..<s+4])
        }}
        return out
    }
}
extension NSColor {
    var rgba: [UInt8] {
        let c = usingColorSpace(.deviceRGB) ?? .black
        let a = c.alphaComponent
        return [UInt8((c.redComponent*a*255).rounded()), UInt8((c.greenComponent*a*255).rounded()), UInt8((c.blueComponent*a*255).rounded()), UInt8((a*255).rounded())]
    }
}
enum PaintError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let s) = self { return s }; return nil }
}
struct PaintLayer {
    var name: String
    var visible = true
    var opacity: Double = 1
    var raster: Raster
}
struct Snapshot { var layers: [PaintLayer]; var active: Int; var revision: UUID }
final class PaintDocument {
    var layers = [PaintLayer(name: "背景", raster: Raster(1000,700,white: true))]
    var active = 0
    var revision = UUID()
    var savedRevision: UUID?
    var url: URL?
    var undoStack = [Snapshot](), redoStack = [Snapshot]()
    var width: Int { layers[0].raster.width }
    var height: Int { layers[0].raster.height }
    var dirty: Bool { revision != savedRevision }
    init() { savedRevision = revision }
    var snapshot: Snapshot { Snapshot(layers: layers, active: active, revision: revision) }
    func restore(_ s: Snapshot) { layers = s.layers; active = s.active; revision = s.revision }
    func checkpoint() {
        undoStack.append(snapshot)
        let perState = max(1,width*height*4*layers.count)
        let limit = max(1,min(40,192_000_000/perState))
        while undoStack.count > limit { undoStack.removeFirst() }
        redoStack.removeAll(); revision = UUID()
    }
    func undo() { guard let s = undoStack.popLast() else { return }; redoStack.append(snapshot); restore(s) }
    func redo() { guard let s = redoStack.popLast() else { return }; undoStack.append(snapshot); restore(s) }
    func composite() -> Raster {
        var output = Raster(width,height)
        for layer in layers where layer.visible {
            var r = layer.raster
            if layer.opacity < 1 { for i in r.pixels.indices { r.pixels[i] = UInt8(Double(r.pixels[i])*layer.opacity) } }
            output.paste(r,at:.zero)
        }
        return output
    }
    func saveProject(_ url: URL) throws {
        let list: [[String: Any]] = layers.map { ["name":$0.name,"visible":$0.visible,"opacity":$0.opacity,"pixels":Data($0.raster.pixels)] }
        let data = try PropertyListSerialization.data(fromPropertyList: ["version":1,"width":width,"height":height,"active":active,"layers":list], format:.binary,options:0)
        try data.write(to:url,options:.atomic)
    }
    func openProject(_ url: URL) throws {
        let data = try Data(contentsOf:url)
        guard data.count < 512_000_000,
              let dict = try PropertyListSerialization.propertyList(from:data,format:nil) as? [String:Any],
              dict["version"] as? Int == 1,
              let w = dict["width"] as? Int, let h = dict["height"] as? Int,
              w > 0, h > 0, w <= 8192, h <= 8192, w*h <= 24_000_000,
              let list = dict["layers"] as? [[String:Any]], !list.isEmpty, list.count <= 32 else { throw PaintError.message("專案格式不支援或尺寸過大。") }
        var loaded = [PaintLayer]()
        for l in list {
            guard let pixels = l["pixels"] as? Data, pixels.count == w*h*4 else { throw PaintError.message("圖層資料損壞。") }
            var r = Raster(w,h); r.pixels = Array(pixels)
            loaded.append(PaintLayer(name:l["name"] as? String ?? "圖層",visible:l["visible"] as? Bool ?? true,opacity:max(0,min(1,l["opacity"] as? Double ?? 1)),raster:r))
        }
        layers = loaded; active = max(0,min(loaded.count-1,dict["active"] as? Int ?? 0))
    }
}
