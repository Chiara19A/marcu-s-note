import SwiftUI
import SwiftData

struct NoteListView: View {
    let selection: SidebarSelection
    let notes: [Note]
    let notebooks: [Notebook]
    @Binding var selectedNoteID: UUID?
    @Binding var searchText: String
    @Binding var semanticHits: [SemanticSearch.Hit]
    @Binding var isSearching: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    @State private var sortMode: SortMode = .modified
    @State private var showingNewNote = false
    @State private var newNoteTitle = ""

    enum SortMode: String, CaseIterable, Identifiable {
        case modified, created, title
        var id: String { rawValue }
        var label: String {
            switch self {
            case .modified: return "Modifica"
            case .created: return "Creazione"
            case .title: return "Titolo"
            }
        }
    }

    private var activeNotebook: Notebook? {
        if case .notebook(let id) = selection { return notebooks.first { $0.id == id } }
        return nil
    }

    private var filteredNotes: [Note] {
        var pool = notes

        switch selection {
        case .allNotes:
            pool = pool.filter { !$0.isTrashed && !$0.isArchived }
        case .favorites:
            pool = pool.filter { $0.isFavorite && !$0.isTrashed }
        case .recent:
            pool = pool.filter { !$0.isTrashed }
                .filter { $0.modifiedAt > Date().addingTimeInterval(-60 * 60 * 24 * 7) }
        case .trash:
            pool = pool.filter(\.isTrashed)
        case .notebook(let id):
            pool = pool.filter { $0.notebookID == id && !$0.isTrashed }
        case .tag(let tag):
            pool = pool.filter { $0.tags.contains(tag) && !$0.isTrashed }
        case .course(let course):
            pool = pool.filter { $0.courseName == course && !$0.isTrashed }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            let textMatches = Set(SemanticSearch.plainTextMatches(pool, query: query).map(\.id))
            let semanticIDs = Set(semanticHits.map(\.note.id))
            pool = pool.filter { textMatches.contains($0.id) || semanticIDs.contains($0.id) }
        }

        switch sortMode {
        case .modified:
            pool.sort { $0.modifiedAt > $1.modifiedAt }
        case .created:
            pool.sort { $0.createdAt > $1.createdAt }
        case .title:
            pool.sort { $0.displayTitle.localizedCaseInsensitiveCompare($1.displayTitle) == .orderedAscending }
        }

        return pool
    }

    private var semanticOnlyNotes: [Note] {
        let textIDs = Set(SemanticSearch.plainTextMatches(notes, query: searchText).map(\.id))
        return semanticHits.map(\.note).filter { !textIDs.contains($0.id) }
    }

    var body: some View {
        ZStack {
            AutumnTheme.surface(scheme).ignoresSafeArea()

            if filteredNotes.isEmpty {
                emptyState
            } else {
                List(selection: $selectedNoteID) {
                    if !searchText.isEmpty, !semanticOnlyNotes.isEmpty {
                        Section {
                            ForEach(semanticOnlyNotes) { note in
                                NoteRowView(note: note, score: score(for: note), isSemantic: true)
                                    .tag(note.id)
                            }
                        } header: {
                            Label("Risultati per significato", systemImage: "sparkle.magnifyingglass")
                                .foregroundStyle(AutumnTheme.olive)
                        }
                    }

                    Section {
                        ForEach(filteredNotes) { note in
                            NoteRowView(note: note)
                                .tag(note.id)
                                .listRowInsets(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
                        }
                        .onDelete { offsets in handleDelete(offsets) }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(headerTitle)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Cerca")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Ordina per", selection: $sortMode) {
                        ForEach(SortMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    Divider()
                    Button("Nuova nota", systemImage: "square.and.pencil") { createNote() }
                    if !notes.filter({ $0.isTrashed }).isEmpty {
                        Button("Svuota cestino", systemImage: "trash.slash", role: .destructive) { emptyTrash() }
                    }
                } label: {
                    Label("Altro", systemImage: "ellipsis.circle")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if selection == .trash, !notes.filter(\.isTrashed).isEmpty {
                HStack {
                    Button {
                        emptyTrash()
                    } label: {
                        Label("Svuota cestino", systemImage: "trash")
                            .font(.subheadline.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AutumnTheme.terracotta)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
        }
    }

    private var headerTitle: String {
        if !searchText.isEmpty {
            return "\(filteredNotes.count) risultati"
        }
        if let notebook = activeNotebook { return notebook.name }
        if case .course(let course) = selection { return course }
        return selection.title
    }

    private func score(for note: Note) -> Double? {
        semanticHits.first { $0.note.id == note.id }?.score
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: searchText.isEmpty ? "square.and.pencil" : "magnifyingglass")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(AutumnTheme.textFaint(scheme))
            Text(searchText.isEmpty ? "Nessuna nota qui" : "Nessun risultato")
                .font(.headline)
                .foregroundStyle(AutumnTheme.text(scheme))
            Text(
                searchText.isEmpty
                    ? "Crea la prima nota con il pulsante + in basso a destra."
                    : "Prova con altre parole, oppure attiva l'IA per la ricerca semantica."
            )
            .font(.subheadline)
            .foregroundStyle(AutumnTheme.textSoft(scheme))
            .multilineTextAlignment(.center)
            .frame(maxWidth: 320)

            if searchText.isEmpty, selection != .trash {
                Button {
                    createNote()
                } label: {
                    Label("Nuova nota", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(AutumnTheme.rust)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Azioni

    private func createNote() {
        let notebookID: UUID?
        let notebookName: String
        var colorIndex = Int.random(in: 0..<8)

        if case .notebook(let id) = selection, let notebook = notebooks.first(where: { $0.id == id }) {
            notebookID = notebook.id
            notebookName = notebook.name
            colorIndex = notebook.colorIndex
        } else {
            notebookID = nil
            notebookName = caseCourseName ?? ""
        }

        let note = Note(
            title: "",
            notebookID: notebookID,
            notebookName: notebookName,
            colorIndex: colorIndex
        )
        note.courseName = caseCourseName ?? notebookName
        context.insert(note)
        try? context.save()
        selectedNoteID = note.id
    }

    private var caseCourseName: String? {
        if case .course(let course) = selection { return course }
        return nil
    }

    private func handleDelete(_ offsets: IndexSet) {
        for index in offsets {
            let note = filteredNotes[index]
            if selection == .trash {
                context.delete(note)
            } else {
                note.isTrashed = true
            }
        }
        try? context.save()
    }

    private func emptyTrash() {
        for note in notes where note.isTrashed {
            context.delete(note)
        }
        try? context.save()
    }
}

struct NoteRowView: View {
    @Bindable var note: Note
    var score: Double?
    var isSemantic: Bool = false

    @Environment(\.colorScheme) private var scheme
    @State private var hovering = false

    private var accent: Color {
        isSemantic ? AutumnTheme.olive : AutumnTheme.noteColor(note.colorIndex)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            RoundedRectangle(cornerRadius: 3)
                .fill(accent.gradient)
                .frame(width: 4)
                .frame(maxHeight: .infinity)
                .opacity(note.isTrashed ? 0.35 : 1)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(note.displayTitle)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(AutumnTheme.text(scheme))
                        .lineLimit(1)

                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(AutumnTheme.rust)
                    }

                    Spacer(minLength: 2)

                    if let score {
                        Text("\(Int(score * 100))%")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(AutumnTheme.olive)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(AutumnTheme.olive.opacity(0.14)))
                    }
                }

                if !note.previewText.isEmpty {
                    Text(note.previewText)
                        .font(.footnote)
                        .foregroundStyle(AutumnTheme.textSoft(scheme))
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Text(AppDate.relative(note.modifiedAt))
                    if !note.courseName.isEmpty {
                        Text("·")
                        Text(note.courseName)
                    }
                    if note.attachments.count > 0 {
                        Text("·")
                        Label("\(note.attachments.count)", systemImage: "paperclip")
                            .labelStyle(.titleAndIcon)
                    }
                    if !note.drawingData.isEmpty {
                        Text("·")
                        Image(systemName: "scribble.variable")
                    }
                    if note.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(AutumnTheme.amber)
                    }
                }
                .font(.caption2)
                .foregroundStyle(AutumnTheme.textFaint(scheme))
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(scheme == .dark ? AutumnTheme.nightSurfaceHi : Color.white)
                .shadow(color: .black.opacity(hovering ? 0.10 : 0.04), radius: 5, y: 2)
        )
        .scaleEffect(hovering ? 1.01 : 1)
        .animation(.easeOut(duration: 0.15), value: hovering)
        .onHover { hovering = $0 }
        .contextMenu {
            Button(note.isFavorite ? "Togli dai preferiti" : "Aggiungi ai preferiti", systemImage: "star") {
                note.isFavorite.toggle()
                note.touch()
                try? note.modelContext?.save()
            }
            Button(note.isPinned ? "Sblocca" : "Fissa in alto", systemImage: "pin") {
                note.isPinned.toggle()
                note.touch()
                try? note.modelContext?.save()
            }
            Button(note.isTrashed ? "Ripristina" : "Sposta in cestino", systemImage: note.isTrashed ? "arrow.uturn.backward" : "trash") {
                note.isTrashed.toggle()
                note.touch()
                try? note.modelContext?.save()
            }
        }
    }
}