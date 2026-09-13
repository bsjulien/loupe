import AppKit

enum AnnotationTool: String, CaseIterable {
    case select, arrow, rectangle, ellipse, line, text, highlight, blur, crop

    var symbolName: String {
        switch self {
        case .select: return "cursorarrow"
        case .arrow: return "arrow.up.right"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .line: return "line.diagonal"
        case .text: return "textformat"
        case .highlight: return "highlighter"
        case .blur: return "drop.halffull"
        case .crop: return "crop"
        }
    }

    var title: String {
        switch self {
        case .select: return "Select"
        case .arrow: return "Arrow"
        case .rectangle: return "Rectangle"
        case .ellipse: return "Ellipse"
        case .line: return "Line"
        case .text: return "Text"
        case .highlight: return "Highlight"
        case .blur: return "Blur"
        case .crop: return "Crop"
        }
    }
}

struct AnnotationElement: Identifiable {
    let id = UUID()
    var tool: AnnotationTool
    var startPoint: CGPoint
    var endPoint: CGPoint
    var color: NSColor
    var lineWidth: CGFloat = 3
    var text: String = ""

    var rect: CGRect {
        CGRect(x: min(startPoint.x, endPoint.x), y: min(startPoint.y, endPoint.y),
               width: abs(endPoint.x - startPoint.x), height: abs(endPoint.y - startPoint.y))
    }
}
