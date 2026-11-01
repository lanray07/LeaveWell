import Foundation
import ImageIO
import CoreGraphics

for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
          image.width == 1398, image.height == 2034 else {
        fatalError("Wrong or unreadable native Duo outer capture: \(url.lastPathComponent)")
    }
    var pixels = [UInt8](repeating: 0, count: 32 * 32 * 4)
    let valid = pixels.withUnsafeMutableBytes { buffer -> Bool in
        guard let context = CGContext(data: buffer.baseAddress, width: 32, height: 32, bitsPerComponent: 8,
                                  bytesPerRow: 32 * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return false
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: 32, height: 32))
        let bytes = buffer.bindMemory(to: UInt8.self)
        let brightness = stride(from: 0, to: bytes.count, by: 4).map { i in
            (Int(bytes[i]) + Int(bytes[i + 1]) + Int(bytes[i + 2])) / 3
        }
        guard let low = brightness.min(), let high = brightness.max() else { return false }
        return high - low > 30 && high > 100
    }
    guard valid else {
        fatalError("Blank native capture rejected: \(url.lastPathComponent)")
    }
}
print("Native capture dimensions and content checks passed.")
