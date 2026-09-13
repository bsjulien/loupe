import AppKit
import CoreGraphics

/// Stitches successive overlapping screenshots of a scrolled region into one tall image
/// by finding the vertical offset where the bottom rows of the current image best match
/// the top rows of the next one (grayscale row-sum cross-correlation).
final class ScrollStitcher {
    private var stitchedImage: CGImage?

    func reset() {
        stitchedImage = nil
    }

    func addFrame(_ frame: CGImage) {
        guard let current = stitchedImage else {
            stitchedImage = frame
            return
        }
        guard let offset = findOverlapOffset(previous: current, next: frame), offset < frame.height else {
            return
        }
        let newContentHeight = frame.height - offset
        guard newContentHeight > 0 else { return }

        let width = max(current.width, frame.width)
        let totalHeight = current.height + newContentHeight
        guard let colorSpace = current.colorSpace,
              let context = CGContext(data: nil, width: width, height: totalHeight, bitsPerComponent: 8,
                                       bytesPerRow: 0, space: colorSpace,
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return
        }

        context.draw(current, in: CGRect(x: 0, y: CGFloat(newContentHeight), width: CGFloat(current.width), height: CGFloat(current.height)))
        if let croppedNew = frame.cropping(to: CGRect(x: 0, y: 0, width: frame.width, height: newContentHeight)) {
            context.draw(croppedNew, in: CGRect(x: 0, y: 0, width: CGFloat(croppedNew.width), height: CGFloat(croppedNew.height)))
        }
        stitchedImage = context.makeImage()
    }

    func finalImage() -> NSImage? {
        guard let cg = stitchedImage else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }

    private func findOverlapOffset(previous: CGImage, next: CGImage) -> Int? {
        guard let prevRows = rowSignatures(of: previous), let nextRows = rowSignatures(of: next) else { return nil }
        let searchDepth = min(prevRows.count, 400)
        let prevTail = Array(prevRows.suffix(searchDepth))
        let maxShift = min(nextRows.count, searchDepth)
        var bestOffset: Int?
        var bestScore = Double.greatestFiniteMagnitude

        for shift in 0..<max(maxShift, 1) {
            let compareCount = min(prevTail.count, nextRows.count - shift)
            guard compareCount > 20 else { continue }
            var diff = 0.0
            for i in 0..<compareCount {
                let a = prevTail[prevTail.count - compareCount + i]
                let b = nextRows[shift + i]
                diff += abs(a - b)
            }
            let score = diff / Double(compareCount)
            if score < bestScore {
                bestScore = score
                bestOffset = shift
            }
        }
        guard let offset = bestOffset, bestScore < 0.06 else { return nil }
        return offset
    }

    private func rowSignatures(of image: CGImage) -> [Double]? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                       bytesPerRow: width, space: colorSpace,
                                       bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return nil }
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height)
        var signatures: [Double] = []
        signatures.reserveCapacity(height)
        let stride = max(1, width / 64)
        for row in 0..<height {
            var sum = 0
            let rowStart = row * width
            var col = 0
            while col < width {
                sum += Int(buffer[rowStart + col])
                col += stride
            }
            signatures.append(Double(sum) / 255.0)
        }
        let maxSignature = signatures.max() ?? 1
        guard maxSignature > 0 else { return signatures }
        return signatures.map { $0 / maxSignature }
    }
}
