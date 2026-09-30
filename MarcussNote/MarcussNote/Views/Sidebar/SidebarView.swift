import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SidebarView: View {
    @Binding var selection: SidebarSelection
    let notebooks: [Notebook]
    let notes: [Note]
    @Binding var showingAISettings: Bool
    @Binding var showAIChat: Bool

    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    @State private var newNotebookName = ""
    @State private var isCreatingNotebook = false
    @State private var renamingNotebook: Notebook?
    @State private var renameText = ""
    @State private var pendingDeletion: Notebook?

    private var activeNotebooks: [Notebook] {
        notebooks.filter { !$0.isArchived }
    }

    private var childNotebooks: [Notebook] {
        notebooks.filter { $0.parentID != nil }
    }

    private var topLevel: [Notebook] {
        activeNotebooks.filter { $0.parentID == nil }.sorted { $0.sortIndex < $1.sortIndex }
    }

    private var courses: [String] {
        Array(Set(notes.map(\.courseName).filter { !$0.isEmpty })).sorted()
    }

    private var tags: [String] {
        var counts: [String: Int] = [:]
        for note in notes where !note.isTrashed {
            for tag in note.tags { counts[tag, default: 0] += 1 }
        }
        return counts.sorted { $0.value > $1.value }.map(\.key)
    }

    var body: some View {
        ZStack {
            (scheme == .dark ? AnyShapeStyle(AutumnTheme.nightSidebarGradient) : AnyShapeStyle(AutumnTheme.sidebarGradient))
                .ignoresSafeArea()

            List(selection: $selection) {
                smartSection
                notebooksSection
                if !courses.isEmpty { coursesSection }
                if !tags.isEmpty { tagsSection }
                iaSection
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Marcus's Note")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCreatingNotebook = true
                } label: {
                    Label("Nuovo quaderno", systemImage: "folder.badge.plus")
                }
            }
        }
        .alert("Nuovo quaderno", isPresented: $isCreatingNotebook) {
            TextField("Nome del quaderno", text: $newNotebookName)
            Button("Crea") { createNotebook() }
            Button("Annulla", role: .cancel) { newNotebookName = "" }
        } message: {
            Text("Es. \"Analisi II\", \"Fisica 2\", \"Tesi\"")
        }
        .alert("Rinomina quaderno", isPresented: Binding(
            get: { renamingNotebook != nil },
            set: { if !$0 { renamingNotebook = nil } }
        )) {
            TextField("Nome", text: $renameText)
            Button("Salva") { commitRename() }
            Button("Annulla", role: .cancel) { renamingNotebook = nil }
        }
        .confirmationDialog(
            "Eliminare il quaderno?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible
        ) {
            Button("Elimina quaderno e note", role: .destructive) { confirmDeleteNotebook() }
            Button("Annulla", role: .cancel) { pendingDeletion = nil }
        } message: {
            if let notebook = pendingDeletion {
                Text("Verranno eliminate anche le \(notesCount(in: notebook)) note contenute. Le troverai nel cestino.")
            }
        }
    }

    private func notesCount(in notebook: Notebook) -> Int {
        notes.filter { $0.notebookID == notebook.id }.count
    }

    // MARK: - Sezioni

    private var smartSection: some View {
        Section {
            row(.allNotes, badge: notes.filter { !$0.isTrashed }.count)
            row(.favorites, badge: notes.filter(\.isFavorite).count)
            row(.recent)
            row(.trash, badge: notes.filter(\.isTrashed).count)
        }
    }

    private var notebooksSection: some View {
        Section {
            ForEach(topLevel) { notebook in
                notebookRow(notebook)
                ForEach(childNotebooks.filter { $0.parentID == notebook.id }) { child in
                    notebookRow(child)
                        .padding(.leading, 18)
                }
            }
        } header: {
            HStack {
                Text("QUADERNI")
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var coursesSection: some View {
        Section("MATERIE") {
            ForEach(courses, id: \.self) { course in
                Label {
                    HStack {
                        Text(course)
                        Spacer()
                        Text("\(notes.filter { $0.courseName == course }.count)")
                            .font(.caption)
                            .foregroundStyle(AutumnTheme.textFaint(scheme))
                    }
                } icon: {
                    Image(systemName: "graduationcap")
                        .foregroundStyle(AutumnTheme.olive)
                }
                .tag(SidebarSelection.course(course))
            }
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        Section("TAG") {
            ForEach(tags.prefix(14), id: \.self) { tag in
                Label {
                    Text("#\(tag)")
                } icon: {
                    Image(systemName: "tag")
                        .foregroundStyle(AutumnTheme.rust)
                }
                .tag(SidebarSelection.tag(tag))
            }
        }
    }

    private var iaSection: some View {
        Section("INTELLIGENZA ARTIFICIALE") {
            Button {
                showAIChat = true
            } label: {
                Label("Chat con le mie note", systemImage: "bubble.left.and.bubble.right")
                    .foregroundStyle(AutumnTheme.text(scheme))
            }
            Button {
                showingAISettings = true
            } label: {
                Label("Impostazioni IA", systemImage: "cpu")
                    .foregroundStyle(AutumnTheme.text(scheme))
            }
        }
    }

    // MARK: - Righe

    private func row(_ item: SidebarSelection, badge: Int? = nil) -> some View {
        Label {
            HStack {
                Text(item.title)
                Spacer()
                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AutumnTheme.textSoft(scheme))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(AutumnTheme.subtleFill(scheme)))
                }
            }
        } icon: {
            Image(systemName: item.symbol)
                .foregroundStyle(AutumnTheme.rust)
        }
        .tag(item)
    }

    private func notebookRow(_ notebook: Notebook) -> some View {
        let count = notes.filter { $0.notebookID == notebook.id && !$0.isTrashed }.count
        return HStack(spacing: 8) {
            Label {
                Text(notebook.name)
                    .lineLimit(1)
            } icon: {
                if notebook.emoji.isEmpty {
                    Image(systemName: "book.closed")
                        .foregroundStyle(AutumnTheme.noteColor(notebook.colorIndex))
                } else {
                    Text(notebook.emoji)
                }
            }

            Spacer(minLength: 4)

            Text("\(count)")
                .font(.caption2)
                .foregroundStyle(AutumnTheme.textFaint(scheme))

            Menu {
                Button("Rinomina", systemImage: "pencil") {
                    renameText = notebook.name
                    renamingNotebook = notebook
                }
                Button("Nuova nota qui", systemImage: "plus") {
                    createNote(in: notebook)
                }
                Button("Duplica", systemImage: "doc.on.doc") {
                    duplicate(notebook)
                }
                Divider()
                Button("Elimina", systemImage: "trash", role: .destructive) {
                    pendingDeletion = notebook
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.caption)
                    .foregroundStyle(AutumnTheme.textFaint(scheme))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .contentShape(Rectangle())
        .tag(SidebarSelection.notebook(notebook.id))
        .contextMenu {
            Button("Nuova nota qui", systemImage: "plus") { createNote(in: notebook) }
            Button("Rinomina", systemImage: "pencil") {
                renameText = notebook.name
                renamingNotebook = notebook
            }
            Button("Elimina", systemImage: "trash", role: .destructive) {
                pendingDeletion = notebook
            }
        }
    }

    // MARK: - Azioni

    private func createNotebook() {
        let name = newNotebookName.trimmingCharacters(in: .whitespacesAndNewlines)
        newNotebookName = ""
        guard !name.isEmpty else { return }
        let notebook = Notebook(
            name: name,
            emoji: emojiFor(name),
            colorIndex: notebooks.count % 8,
            sortIndex: notebooks.count
        )
        context.insert(notebook)
        try? context.save()
        selection = .notebook(notebook.id)
    }

    private func commitRename() {
        guard let notebook = renamingNotebook else { return }
        let name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { notebook.name = name }
        renamingNotebook = nil
        try? context.save()
    }

    private func createNote(in notebook: Notebook) {
        let note = Note(
            title: "",
            notebookID: notebook.id,
            notebookName: notebook.name,
            colorIndex: notebook.colorIndex
        )
        note.courseName = notebook.name
        context.insert(note)
        try? context.save()
        selection = .notebook(notebook.id)
    }

    private func duplicate(_ notebook: Notebook) {
        let copy = Notebook(
            name: notebook.name + " (copia)",
            emoji: notebook.emoji,
            colorIndex: notebook.colorIndex,
            parentID: notebook.parentID,
            sortIndex: notebook.sortIndex + 1
        )
        context.insert(copy)
        try? context.save()
    }

    private func confirmDeleteNotebook() {
        guard let notebook = pendingDeletion else { return }
        for note in notes where note.notebookID == notebook.id {
            note.isTrashed = true
        }
        for child in notebooks where child.parentID == notebook.id {
            child.parentID = nil
        }
        context.delete(notebook)
        try? context.save()
        pendingDeletion = nil
        if selection == .notebook(notebook.id) {
            selection = .allNotes
        }
    }

    private func emojiFor(_ name: String) -> String {
        let lower = name.lowercased()
        let map: [(String, String)] = [
            ("fisic", "⚛️"), ("chem", "🧪"), ("matemat", "📐"), ("calc", "📐"),
            ("analisi", "📈"), ("inform", "💻"), ("program", "💻"), ("ingegner", "⚙️"),
            ("diritto", "⚖️"), ("econom", "💹"), ("storia", "🏛️"), ("filosof", "🧠"),
            ("lingua", "🗣️"), ("inglese", "🗣️"), ("medic", "🩺"), ("bio", "🧬"),
            ("geo", "🌍"), ("psic", "🧠"), ("musica", "🎵"), ("arte", "🎨")
        ]
        return map.first { lower.contains($0.0) }?.1 ?? ""
    }
}