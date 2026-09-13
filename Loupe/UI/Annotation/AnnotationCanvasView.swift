import AppKit
import CoreImage

protocol AnnotationCanvasDelegate: AnyObject {
    func canvasDidChangeElements(_ canvas: AnnotationCanvasView)
}

final class AnnotationCanvasView: NSView {
    weak var delegate: AnnotationCanvasDelegate?
    var currentTool: AnnotationTool = .select
    var currentColor: NSColor = Theme.accent
    private(set) var elements: [AnnotationElement] = []
    private var undoneElements: [AnnotationElement] = []
    private var activeElement: AnnotationElement?
    private var dragStart: CGPoint?
    let baseImage: NSImage
    var cropRect: CGRect?
    private var textEditor: NSTextField?

    init(image: NSImage) {
        self.baseImage = image
        super.init(frame: NSRect(origin: .zero, size: image.size))
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if currentTool == .text {
            beginTextEditing(at: point)
            return
        }
        dragStart = point
        activeElement = AnnotationElement(tool: currentTool, startPoint: point, endPoint: point, color: currentColor)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let point = convert(event.locationInWindow, from: nil)
        activeElement?.endPoint = point
        if currentTool == .crop {
            cropRect = CGRect(x: min(start.x, point.x), y: min(start.y, point.y),
                               width: abs(point.x - start.x), height: abs(point.y - start.y))
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        defer { dragStart = nil; activeElement = nil }
        guard let element = activeElement, currentTool != .select, currentTool != .crop else {
            needsDisplay = true
            return
        }
        guard element.rect.width > 2 || element.rect.height > 2 else { return }
        elements.append(element)
        undoneElements.removeAll()
        delegate?.canvasDidChangeElements(self)
        needsDisplay = true
    }

    func undo() {
        guard let last = elements.popLast() else { return }
        undoneElements.append(last)
        needsDisplay = true
        delegate?.canvasDidChangeElements(self)
    }

    func redo() {
        guard let last = undoneElements.popLast() else { return }
        elements.append(last)
        needsDisplay = true
        delegate?.canvasDidChangeElements(self)
    }

    func clearCrop() {
        cropRect = nil
        needsDisplay = true
    }

    func renderedImage() -> NSImage {
        let size = bounds.size
        let image = NSImage(size: size)
        image.lockFocus()
        if let context = NSGraphicsContext.current?.cgContext {
            drawContent(in: context, rect: NSRect(origin: .zero, size: size))
        }
        image.unlockFocus()

        guard let crop = cropRect, crop.width > 4, crop.height > 4,
              let cgFull = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image
        }
        let scaleX = CGFloat(cgFull.width) / size.width
        let scaleY = CGFloat(cgFull.height) / size.height
        let pixelCrop = CGRect(x: crop.minX * scaleX, y: crop.minY * scaleY, width: crop.width * scaleX, height: crop.height * scaleY)
        guard let cropped = cgFull.cropping(to: pixelCrop) else { return image }
        return NSImage(cgImage: cropped, size: NSSize(width: pixelCrop.width / scaleX, height: pixelCrop.height / scaleY))
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        drawContent(in: context, rect: bounds)
    }

    private func drawContent(in context: CGContext, rect: NSRect) {
        baseImage.draw(in: rect)
        for element in elements {
            draw(element, in: context)
        }
        if let active = activeElement, currentTool != .select, currentTool != .crop {
            draw(active, in: context)
        }
        if let crop = cropRect {
            context.setFillColor(NSColor.black.withAlphaComponent(0.4).cgColor)
            context.addRect(bounds)
            context.addRect(crop)
            context.fillPath(using: .evenOdd)
            context.setStrokeColor(Theme.accent.cgColor)
            context.setLineWidth(1.5)
            context.stroke(crop)
        }
    }

    private func draw(_ element: AnnotationElement, in context: CGContext) {
        context.saveGState()
        context.setStrokeColor(element.color.cgColor)
        context.setFillColor(element.color.cgColor)
        context.setLineWidth(element.lineWidth)
        switch element.tool {
        case .rectangle:
            context.stroke(element.rect)
        case .ellipse:
            context.strokeEllipse(in: element.rect)
        case .line:
            context.move(to: element.startPoint)
            context.addLine(to: element.endPoint)
            context.strokePath()
        case .arrow:
            drawArrow(from: element.startPoint, to: element.endPoint, in: context, width: element.lineWidth)
        case .highlight:
            context.setAlpha(0.35)
            context.setFillColor(NSColor.systemYellow.cgColor)
            context.fill(element.rect)
        case .blur:
            drawBlur(rect: element.rect, context: context)
        case .text:
            drawText(element)
        default:
            break
        }
        context.restoreGState()
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint, in context: CGContext, width: CGFloat) {
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = max(10, width * 3)
        let arrowAngle: CGFloat = .pi / 7
        let p1 = CGPoint(x: end.x - arrowLength * cos(angle - arrowAngle), y: end.y - arrowLength * sin(angle - arrowAngle))
        let p2 = CGPoint(x: end.x - arrowLength * cos(angle + arrowAngle), y: end.y - arrowLength * sin(angle + arrowAngle))
        context.move(to: end)
        context.addLine(to: p1)
        context.move(to: end)
        context.addLine(to: p2)
        context.strokePath()
    }

    private func drawBlur(rect: CGRect, context: CGContext) {
        guard rect.width > 1, rect.height > 1,
              let cgBase = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let scaleX = CGFloat(cgBase.width) / bounds.width
        let scaleY = CGFloat(cgBase.height) / bounds.height
        let pixelRect = CGRect(x: rect.minX * scaleX, y: rect.minY * scaleY, width: rect.width * scaleX, height: rect.height * scaleY)
        guard let cropped = cgBase.cropping(to: pixelRect) else { return }
        let ciImage = CIImage(cgImage: cropped)
        let filter = CIFilter(name: "CIPixellate")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(max(rect.width, rect.height) / 12, forKey: kCIInputScaleKey)
        guard let output = filter?.outputImage else { return }
        let ciContext = CIContext()
        guard let result = ciContext.createCGImage(output, from: ciImage.extent) else { return }
        context.saveGState()
        context.clip(to: rect)
        context.draw(result, in: rect)
        context.restoreGState()
    }

    private func drawText(_ element: AnnotationElement) {
        guard !element.text.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: element.color
        ]
        element.text.draw(at: element.startPoint, withAttributes: attrs)
    }

    private func beginTextEditing(at point: CGPoint) {
        let field = NSTextField(frame: NSRect(x: point.x, y: point.y, width: 200, height: 24))
        field.isBordered = false
        field.drawsBackground = true
        field.backgroundColor = NSColor.white.withAlphaComponent(0.85)
        field.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        field.textColor = currentColor
        addSubview(field)
        window?.makeFirstResponder(field)
        textEditor = field
        field.target = self
        field.action = #selector(commitTextField(_:))
    }

    @objc private func commitTextField(_ sender: NSTextField) {
        defer {
            sender.removeFromSuperview()
            textEditor = nil
        }
        guard !sender.stringValue.isEmpty else { return }
        let element = AnnotationElement(tool: .text, startPoint: sender.frame.origin,
                                         endPoint: sender.frame.origin, color: currentColor, text: sender.stringValue)
        elements.append(element)
        undoneElements.removeAll()
        delegate?.canvasDidChangeElements(self)
        needsDisplay = true
    }
}
