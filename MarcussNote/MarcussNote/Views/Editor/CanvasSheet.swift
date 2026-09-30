import SwiftUI
import PencilKit
import UniformTypeIdentifiers

struct CanvasSheet: View {
    @Bindable var note: Note
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var drawing = PKDrawing()
    @State private var tool: PKInkingTool.InkingType = .pen
    @State private var color: Color = AutumnTheme.ink
    @State private var width: CGFloat = 3
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ZStack {
                CanvasBackground(scheme: scheme)
                PencilCanvasRepresentable(drawing: $drawing, isEditable: true, tool: tool, color: color, width: width)
                    .ignoresSafeArea(.keyboard)
                if drawing.strokes.isEmpty && loaded {
                    VStack(spacing: 8) {
                        Image(systemName: "scribble")
                            .font(.system(size: 46, weight: .light))
                        Text("Scrivi qui con Apple Pencil")
                            .font(.callout)
                    }
                    .foregroundStyle(AutumnTheme.textFaint(scheme))
                    .allowsHitTesting(false)
                }
            }
            .safeAreaInset(edge: .bottom) { toolBar }
            .navigationTitle("Canvas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { save() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        drawing = PKDrawing()
                    } label: {
                        Label("Pulisci", systemImage: "trash")
                    }
                    .disabled(drawing.strokes.isEmpty)
                }
            }
            .onAppear {
                if !loaded {
                    drawing = note.drawingData.isEmpty
                        ? PKDrawing()
                        : (try? PKDrawing(data: note.drawingData)) ?? PKDrawing()
                    loaded = true
                }
            }
        }
    }

    private var toolBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                toolButton(.pen, symbol: "pencil.tip")
                toolButton(.marker, symbol: "highlighter")
                toolButton(.pencil, symbol: "pencil.and.scribble")

                Divider().frame(height: 26)

                colorSwatch(AutumnTheme.text(scheme))
                colorSwatch(AutumnTheme.rust)
                colorSwatch(AutumnTheme.terracotta)
                colorSwatch(AutumnTheme.olive)
                colorSwatch(AutumnTheme.blue)

                Divider().frame(height: 26)

                Menu {
                    Picker("Spessore", selection: $width) {
                        Text("Sottile").tag(CGFloat(1.5))
                        Text("Medio").tag(CGFloat(3))
                        Text("Spesso").tag(CGFloat(6))
                        Text("Molto spesso").tag(CGFloat(11))
                    }
                } label: {
                    Image(systemName: "lineweight")
                }
                .frame(width: 34)

                Spacer()

                if !drawing.strokes.isEmpty {
                    Button {
                        drawing = PKDrawing()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(AutumnTheme.terracotta)
                    }
                    .frame(width: 34)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func toolButton(_ type: PKInkingTool.InkType, symbol: String) -> some View {
        Button {
            tool = type
        } label: {
            Image(systemName: symbol)
                .font(.callout)
                .frame(width: 34, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(tool == type ? AutumnTheme.rust.opacity(0.18) : .clear)
                )
                .foregroundStyle(tool == type ? AutumnTheme.rust : AutumnTheme.textSoft(scheme))
        }
        .buttonStyle(.plain)
    }

    private func colorSwatch(_ c: Color) -> some View {
        Button {
            color = c
        } label: {
            Circle()
                .fill(c.gradient)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(AutumnTheme.text(scheme).opacity(color == c ? 0.8 : 0.12), lineWidth: color == c ? 2.5 : 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func save() {
        note.drawingData = drawing.dataRepresentation()
        note.touch()
        try? note.modelContext?.save()
        dismiss()
    }
}

struct CanvasBackground: View {
    let scheme: ColorScheme

    var body: some View {
        ZStack {
            AutumnTheme.canvasBackground(scheme)

            Canvas { context, size in
                let spacing: CGFloat = 34
                var path = Path()
                var x: CGFloat = 0
                while x < size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += spacing
                }
                var y: CGFloat = 0
                while y < size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += spacing
                }
                context.stroke(
                    path,
                    with: .color(AutumnTheme.sand.opacity(scheme == .dark ? 0.16 : 0.5)),
                    lineWidth: 0.6
                )
            }
        }
        .ignoresSafeArea()
    }
}

struct PencilCanvasRepresentable: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var isEditable: Bool
    var tool: PKInkingTool.InkingType = .pen
var color: Color
    var width: CGFloat = 3

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawing = drawing
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(tool, color: UIColor(color), width: width)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.isScrollEnabled = false
        canvas.minimumZoomScale = 1
        canvas.maximumZoomScale = 1
        canvas.alwaysBounceVertical = false
        canvas.alwaysBounceHorizontal = false
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
        let desired = PKInkingTool(tool, color: UIColor(color), width: width)
        if canvas.tool != desired {
            canvas.tool = desired
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        private let drawing: Binding<PKDrawing>

        init(drawing: Binding<PKDrawing>) {
            self.drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing.wrappedValue = canvasView.drawing
        }
    }
}

struct DrawingPreview: UIViewRepresentable {
    let drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.drawing = drawing
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.isOpaque = false
        return view
    }

    func updateUIView(_ view: PKCanvasView, context: Context) {
        if view.drawing != drawing {
            view.drawing = drawing
        }
    }
}
