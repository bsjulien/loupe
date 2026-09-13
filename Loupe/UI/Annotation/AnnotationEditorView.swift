import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AnnotationCanvasRepresentable: NSViewRepresentable {
    let canvas: AnnotationCanvasView

    func makeNSView(context: Context) -> AnnotationCanvasView { canvas }
    func updateNSView(_ nsView: AnnotationCanvasView, context: Context) {}
}

struct AnnotationEditorView: View {
    let canvas: AnnotationCanvasView
    @State private var selectedTool: AnnotationTool = .select
    @State private var selectedColor: Color
    @State private var revision = 0
    @State private var delegateHolder: CanvasDelegateHolder?

    init(canvas: AnnotationCanvasView) {
        self.canvas = canvas
        _selectedColor = State(initialValue: Color(canvas.currentColor))
    }

    final class CanvasDelegateHolder: NSObject, AnnotationCanvasDelegate {
        let onChange: () -> Void
        init(onChange: @escaping () -> Void) { self.onChange = onChange }
        func canvasDidChangeElements(_ canvas: AnnotationCanvasView) { onChange() }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(Theme.hairlineColor)
            ScrollView([.horizontal, .vertical]) {
                AnnotationCanvasRepresentable(canvas: canvas)
                    .frame(width: canvas.baseImage.size.width, height: canvas.baseImage.size.height)
            }
            Divider().overlay(Theme.hairlineColor)
            actionBar
        }
        .background(Theme.backgroundColor)
        .onAppear {
            let holder = CanvasDelegateHolder { revision += 1 }
            canvas.delegate = holder
            delegateHolder = holder
        }
    }

    private var toolbar: some View {
        HStack(spacing: 4) {
            ForEach(AnnotationTool.allCases, id: \.self) { tool in
                toolButton(tool)
            }
            Spacer()
            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 28)
                .onChange(of: selectedColor) { _, newValue in
                    canvas.currentColor = NSColor(newValue)
                }
            Divider().frame(height: 20)
            Button {
                canvas.undo(); revision += 1
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }.buttonStyle(.plain)
            Button {
                canvas.redo(); revision += 1
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }.buttonStyle(.plain)
        }
        .padding(10)
    }

    private func toolButton(_ tool: AnnotationTool) -> some View {
        Button {
            selectedTool = tool
            canvas.currentTool = tool
            if tool != .crop { canvas.clearCrop() }
        } label: {
            Image(systemName: tool.symbolName)
                .frame(width: 28, height: 28)
                .background(selectedTool == tool ? Theme.accentColor.opacity(0.18) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(tool.title)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            actionButton("Copy Text", symbol: "text.viewfinder") { copyText() }
            Spacer()
            actionButton("Pin", symbol: "pin") { pin() }
            actionButton("Save", symbol: "square.and.arrow.down") { save() }
            actionButton("Copy", symbol: "doc.on.doc") { copy() }
        }
        .padding(10)
    }

    private func actionButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .medium))
        }
        .buttonStyle(.bordered)
        .tint(Theme.accentColor)
    }

    private func copy() {
        let image = canvas.renderedImage()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }

    private func save() {
        let image = canvas.renderedImage()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "Loupe Screenshot.png"
        panel.directoryURL = PreferencesStore.shared.saveFolderURL
        if panel.runModal() == .OK, let url = panel.url,
           let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: url)
        }
    }

    private func pin() {
        PinnedWindowController.open(image: canvas.renderedImage())
    }

    private func copyText() {
        Task {
            guard let cgImage = canvas.renderedImage().cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
            if let regions = try? await OCRManager.shared.recognizeText(in: cgImage) {
                OCRManager.shared.copyAllText(regions)
            }
        }
    }
}
