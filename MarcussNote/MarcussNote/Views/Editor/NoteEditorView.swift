import SwiftUI
import SwiftData
import PencilKit
import UniformTypeIdentifiers
import PhotosUI

struct NoteEditorView: View {
    @Bindable var note: Note

    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

@StateObject private var recorder = AudioRecorder()

    @State private var mode: EditorMode = .edit
    @State private var cursorOffset: Int = 0
    @State private var pendingAIAction: AIAction?
    @State private var showingCanvas = false
    @State private var showingAIStudio = false
    @State private var showingExport = false
    @State private var showingImporter = false
    @State private var showingNoteInfo = false
    @State private var photoItem: PhotosPickerItem?
    @State private var openedAttachment: Attachment?
    @State private var toast: String?

    enum EditorMode: String, CaseIterable, Identifiable {
        case edit, preview, split
        var id: String { rawValue }
        var label: String {
            switch self {
            case .edit: return "Editor"
            case .preview: return "Anteprima"
            case .split: return "Affiancato"
            }
        }
        var symbol: String {
            switch self {
            case .edit: return "pencil"
            case .preview: return "eye"
            case .split: return "rectangle.split.2x1"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AutumnTheme.paper(scheme).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().overlay(AutumnTheme.border(scheme))

                editorArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider().overlay(AutumnTheme.border(scheme))

                AttachmentStrip(
                    note: note,
                    onOpen: { openedAttachment = $0 },
                    onRecord: { Task { await toggleRecording() } },
                    onImport: { showingImporter = true },
                    isRecording: recorder.isRecording,
                    recordingLabel: recorder.elapsedLabel
                )
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle(note.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.pdf, .image, .plainText, .data],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
        .sheet(isPresented: $showingCanvas) {
            CanvasSheet(note: note)
        }
        .sheet(isPresented: $showingAIStudio) {
            AIStudioView(note: note, initialAction: pendingAIAction)
                .onDisappear { pendingAIAction = nil }
        }
        .sheet(item: $openedAttachment) { attachment in
            AttachmentViewer(attachment: attachment)
        }
        .sheet(isPresented: $showingNoteInfo) {
            NoteInfoView(note: note)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingExport) {
            ExportSheet(note: note) { url in
                ShareSheet(items: [url])
            }
        }
        .overlay(alignment: .top) {
            if let toast {
                ToastView(text: toast)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: note.content) { _, _ in
            note.modifiedAt = Date()
            note.wordCountCache = note.computedWordCount
        }
        .onDisappear {
            try? context.save()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Titolo", text: $note.title, axis: .vertical)
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
                .textFieldStyle(.plain)
                .lineLimit(1...3)

            HStack(spacing: 8) {
                TagChips(tags: $note.tags) { tag in
                    note.content += (note.content.isEmpty ? "" : "\n\n") + "#\(tag) "
                    note.touch()
                }

                Spacer(minLength: 0)

                if !note.courseName.isEmpty {
                    Label(note.courseName, systemImage: "graduationcap")
                        .font(.caption)
                        .foregroundStyle(AutumnTheme.olive)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(AutumnTheme.olive.opacity(0.12)))
                }
            }

            formattingBar
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var formattingBar: some View {
        HStack(spacing: 6) {
            fmtButton("Titolo", symbol: "textformat.size") { applyHeading("## ") }
            fmtButton("Grassetto", symbol: "bold") { wrap("**") }
            fmtButton("Corsivo", symbol: "italic") { wrap("*") }
            fmtButton("Codice", symbol: "chevron.left.forwardslash.chevron.right") { wrap("`") }
            fmtButton("Lista", symbol: "list.bullet") { applyHeading("- ") }
            fmtButton("Citazione", symbol: "quote.opening") { applyHeading("> ") }
            fmtButton("Formula", symbol: "function") { insertFormula() }

            Divider().frame(height: 20)

            Picker("Modalità", selection: $mode) {
                ForEach(EditorMode.allCases) { m in
                    Image(systemName: m.symbol).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 132)

            Spacer()

            Text("\(note.computedWordCount) parole · \(note.readingTimeMinutes) min")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(AutumnTheme.textFaint(scheme))
        }
    }

    private func fmtButton(_ label: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 27)
                .background(RoundedRectangle(cornerRadius: 7).fill(AutumnTheme.subtleFill(scheme)))
                .foregroundStyle(AutumnTheme.walnut)
        }
        .buttonStyle(.plain)
        .help(label)
    }

    // MARK: - Editor

    @ViewBuilder
    private var editorArea: some View {
        switch mode {
        case .edit:
            MarkdownTextEditor(text: $note.content, cursorOffset: $cursorOffset, fontSize: 17)

        case .preview:
            ScrollView {
                MarkdownPreview(markdown: note.content.isEmpty ? "_Nessun contenuto._" : note.content)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 20)
            }

        case .split:
            HStack(spacing: 0) {
                MarkdownTextEditor(
                    text: $note.content,
                    cursorOffset: $cursorOffset,
                    fontSize: 15,
                    monospaced: true
                )

                Divider().overlay(AutumnTheme.border(scheme))

                ScrollView {
                    MarkdownPreview(markdown: note.content, fontSize: 15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Riassumi con IA", systemImage: "text.append") { runAI(.summarize) }
                Button("Punti chiave", systemImage: "list.bullet.rectangle") { runAI(.keyPoints) }
                Button("Spiega meglio", systemImage: "bubble.left.and.text.bubble.right") { runAI(.explain) }
                Divider()
                Button("Apri pannello IA", systemImage: "sparkles") { showingAIStudio = true }
            } label: {
                Label("IA rapida", systemImage: "wand.and.stars")
            }
        }

        ToolbarItemGroup(placement: .secondaryAction) {
            Button {
                note.isFavorite.toggle()
                note.touch()
            } label: {
                Label(
                    note.isFavorite ? "Togli dai preferiti" : "Preferiti",
                    systemImage: note.isFavorite ? "star.fill" : "star"
                )
            }

            Menu {
                Button("Importa da file", systemImage: "folder") { showingImporter = true }
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Foto / screenshot", systemImage: "photo")
                }
                Button("Registra lezione", systemImage: "mic") {
                    Task { await toggleRecording() }
                }
                Divider()
                Button("Duplica nota", systemImage: "doc.on.doc") { duplicateNote() }
                Button("Sposta in cestino", systemImage: "trash", role: .destructive) {
                    note.isTrashed = true
                    note.touch()
                }
            } label: {
                Label("Altro", systemImage: "ellipsis.circle")
            }

            Button {
                showingExport = true
            } label: {
                Label("Esporta", systemImage: "square.and.arrow.up")
            }

            Button {
                showingNoteInfo = true
            } label: {
                Label("Info", systemImage: "info.circle")
            }
        }
    }

    // MARK: - Azioni editor

    private func applyHeading(_ prefix: String) {
        let (text, offset) = MarkdownService.applyHeadingPrefix(prefix, to: note.content, cursorOffset: cursorOffset)
        note.content = text
        cursorOffset = offset
        note.touch()
    }

    private func wrap(_ marker: String) {
        let (text, offset) = MarkdownService.wrapSelection(marker, in: note.content, cursorOffset: cursorOffset)
        note.content = text
        cursorOffset = offset
        note.touch()
    }

    private func insertFormula() {
        note.content += (note.content.isEmpty ? "" : "\n\n") + "$$\n\\int_{a}^{b} f(x)\\,dx = F(b) - F(a)\n$$\n"
        cursorOffset = (note.content as NSString).length
        note.touch()
    }

    private func runAI(_ action: AIAction) {
        pendingAIAction = action
        showingAIStudio = true
    }

    // MARK: - Allegati

    private func toggleRecording() async {
        do {
            if recorder.isRecording {
                guard let url = recorder.stop() else { return }
                let attachment = Attachment(
                    kind: .audio,
                    fileName: url.lastPathComponent,
                    data: Data()
                )
                context.insert(attachment)
                attachment.note = note
                note.audioFileName = url.lastPathComponent
                note.touch()
                try? context.save()
                showToast("Registrazione salvata e allegata alla nota")
            } else {
                _ = try await recorder.start()
                showToast("Registrazione in corso…")
            }
        } catch {
            showToast(error.localizedDescription)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                let needsScope = url.startAccessingSecurityScopedResource()
                defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url) else { continue }
                let kind: AttachmentKind
                switch url.pathExtension.lowercased() {
                case "pdf": kind = .pdf
                case "png", "jpg", "jpeg", "heic", "gif", "webp": kind = .image
                default: kind = .file
                }
                let attachment = Attachment(
                    kind: kind,
                    fileName: url.lastPathComponent,
                    data: data,
                    sortIndex: note.attachments.count
                )
                context.insert(attachment)
                attachment.note = note
                note.touch()
            }
            try? context.save()
            showToast("Allegati aggiunti")
        case .failure(let error):
            showToast(error.localizedDescription)
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let attachment = Attachment(
            kind: .image,
            fileName: "immagine_\(Date().timeIntervalSince1970).jpg",
            data: data,
            sortIndex: note.attachments.count
        )
        context.insert(attachment)
        attachment.note = note
        note.touch()
        try? context.save()
        showToast("Immagine allegata")
    }

    private func duplicateNote() {
        let copy = Note(
            title: note.title + " (copia)",
            notebookID: note.notebookID,
            notebookName: note.notebookName,
            colorIndex: note.colorIndex
        )
        copy.content = note.content
        copy.tags = note.tags
        copy.courseName = note.courseName
        copy.drawingData = note.drawingData
        copy.audioFileName = note.audioFileName
        context.insert(copy)
        try? context.save()
        showToast("Nota duplicata")
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(duration: 0.3)) {
            toast = message
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    if toast == message { toast = nil }
                }
            }
        }
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.black.opacity(0.86)))
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }
}