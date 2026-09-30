import SwiftUI
import SwiftData
import PDFKit
import UIKit
import UniformTypeIdentifiers

struct AttachmentViewer: View {
    let attachment: Attachment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            Group {
                switch attachment.kind {
                case .image:
                    if let image = UIImage(data: attachment.data) {
                        ScrollView([.horizontal, .vertical]) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .padding()
                        }
                        .background(AutumnTheme.canvasBackground(.light))
                    } else {
                        failure
                    }

                case .pdf:
                    PDFKitView(data: attachment.data)

                case .audio:
                    AudioPlayerView(fileName: attachment.fileName)

                case .file:
                    if let text = String(data: attachment.data, encoding: .utf8) {
                        ScrollView {
                            Text(text)
                                .font(.system(.footnote, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "doc")
                                .font(.system(size: 52))
                                .foregroundStyle(AutumnTheme.textFaint(scheme))
                            Text(attachment.fileName)
                                .font(.subheadline)
                            Text("\(attachment.sizeLabel)")
                                .font(.caption)
                                .foregroundStyle(AutumnTheme.textFaint(scheme))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle(attachment.caption.isEmpty ? attachment.fileName : attachment.caption)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: tempURL) {
                        Label("Condividi", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }

    private var tempURL: URL {
        let url = FileStore.exports.appendingPathComponent(attachment.fileName)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? attachment.data.write(to: url)
        }
        return url
    }

    private var failure: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(AutumnTheme.amber)
            Text("Impossibile aprire l'allegato")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .secondarySystemBackground
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document == nil {
            view.document = PDFDocument(data: data)
        }
    }
}

struct NoteInfoView: View {
    @Bindable var note: Note
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        NavigationStack {
            Form {
                Section("Organizzazione") {
                    LabeledContent("Quaderno") {
                        Text(note.notebookName.isEmpty ? "Nessuno" : note.notebookName)
                    }
                    TextField("Materia", text: $note.courseName)
                    LabeledContent("Color note") {
                        ColorPicker("", selection: Binding(
                            get: { AutumnTheme.noteColor(note.colorIndex) },
                            set: { _ in }
                        ), supportsOpacity: false)
                        .labelsHidden()
                    }
                }

                Section("Statistiche") {
                    LabeledContent("Parole", value: "\(note.computedWordCount)")
                    LabeledContent("Caratteri", value: "\(note.content.count)")
                    LabeledContent("Tempo di lettura", value: "\(note.readingTimeMinutes) min")
                    LabeledContent("Creatata", value: AppDate.italian.string(from: note.createdAt))
                    LabeledContent("Modificata", value: AppDate.italianShort.string(from: note.modifiedAt))
                    LabeledContent("Allegati", value: "\(note.attachments.count)")
                }

                Section("Colore nota") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(0..<8, id: \.self) { index in
                                Button {
                                    note.colorIndex = index
                                    note.touch()
                                } label: {
                                    Circle()
                                        .fill(AutumnTheme.noteColor(index).gradient)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            Circle().stroke(
                                                note.colorIndex == index ? AutumnTheme.text(scheme) : .clear,
                                                lineWidth: 2.5
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Toggle("Nota preferita", isOn: $note.isFavorite)
                    Toggle("Fissa in alto", isOn: $note.isPinned)
                }

                Section {
                    Button("Salva e chiudi") {
                        try? context.save()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Info nota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
        }
    }
}

struct ExportSheet: View {
    let note: Note
    let onShare: (URL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var format: ExportFormat = .pdf
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Formato") {
                    Picker("Formato", selection: $format) {
                        ForEach(ExportFormat.allCases) { f in
                            Label(f.label, systemImage: symbol(for: f)).tag(f)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section {
                    Button {
                        perform()
                    } label: {
                        HStack {
                            if busy { ProgressView() }
                            Text(busy ? "Esportazione…" : "Esporta e condividi")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(busy)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(AutumnTheme.terracotta)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Esporta nota")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }

    private func symbol(for format: ExportFormat) -> String {
        switch format {
        case .markdown: return "text.document"
        case .html: return "chevron.left.forwardslash.chevron.right"
        case .pdf: return "doc.richtext"
        }
    }

    private func perform() {
        busy = true
        error = nil
        Task {
            do {
                let url = try ExportService.export(note, as: format)
                busy = false
                dismiss()
                try? await Task.sleep(nanoseconds: 350_000_000)
                onShare(url)
            } catch {
                busy = false
                error = error.localizedDescription
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}