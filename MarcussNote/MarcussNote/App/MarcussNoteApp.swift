import SwiftUI
import SwiftData

@main
struct MarcussNoteApp: App {
    @StateObject private var settings = AISettings.shared
    @StateObject private var ai = AIService.shared

    private let container: ModelContainer = {
        let schema = Schema([Notebook.self, Note.self, Attachment.self, ChatMessage.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(ai)
                .tint(AutumnTheme.rust)
                .task {
                    DataSeeder.seedIfNeeded(context: container.mainContext)
                    await ai.checkStatus()
                }
        }
        .modelContainer(container)
    }
}

enum SidebarSelection: Hashable {
    case allNotes
    case favorites
    case recent
    case trash
    case notebook(UUID)
    case tag(String)
    case course(String)

    var title: String {
        switch self {
        case .allNotes: return "Tutte le note"
        case .favorites: return "Preferiti"
        case .recent: return "Recenti"
        case .trash: return "Cestino"
        case .notebook(let id): return "Quaderno"
        case .tag(let tag): return "#\(tag)"
        case .course(let course): return course
        }
    }

    var symbol: String {
        switch self {
        case .allNotes: return "square.grid.2x2"
        case .favorites: return "star"
        case .recent: return "clock"
        case .trash: return "trash"
        case .notebook: return "book"
        case .tag: return "tag"
        case .course: return "graduationcap"
        }
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    @Query(sort: \Notebook.createdAt) private var notebooks: [Notebook]
    @Query(sort: \Note.modifiedAt, order: .reverse) private var notes: [Note]

    @State private var selection: SidebarSelection = .allNotes
    @State private var selectedNoteID: UUID?
    @State private var searchText = ""
    @State private var semanticHits: [SemanticSearch.Hit] = []
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showingAISettings = false
    @State private var showAIChat = false
    @State private var isSearching = false

    private var currentNote: Note? {
        guard let selectedNoteID else { return nil }
        return notes.first { $0.id == selectedNoteID }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(
                selection: $selection,
                notebooks: notebooks,
                notes: notes,
                showingAISettings: $showingAISettings,
                showAIChat: $showAIChat
            )
            .navigationSplitViewColumnWidth(min: 230, ideal: 268, max: 340)
        } content: {
            NoteListView(
                selection: selection,
                notes: notes,
                notebooks: notebooks,
                selectedNoteID: $selectedNoteID,
                searchText: $searchText,
                semanticHits: $semanticHits,
                isSearching: $isSearching
            )
            .navigationSplitViewColumnWidth(min: 290, ideal: 330, max: 440)
        } detail: {
            if let note = currentNote {
                NoteEditorView(note: note)
                    .id(note.id)
            } else {
                EmptyDetailView(
                    notebooks: notebooks.count,
                    notes: notes.count,
                    words: notes.reduce(0) { $0 + $1.computedWordCount }
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(
            text: $searchText,
            placement: .sidebar,
            prompt: "Cerca nelle note (testo o significato)"
        )
        .onSubmit(of: .search) { Task { await runSemanticSearch() } }
        .onChange(of: searchText) { _, newValue in
            guard newValue.isEmpty else { return }
            Task { @MainActor in
                semanticHits = []
                isSearching = false
            }
        }
        .sheet(isPresented: $showingAISettings) {
            AISettingsView()
        }
        .sheet(isPresented: $showAIChat) {
            AIChatView()
        }
        .onChange(of: selection) { _, newValue in
            selectedNoteID = nil
            let isNotebook: Bool
            if case .notebook = newValue {
                isNotebook = true
            } else {
                isNotebook = false
            }
            if !isNotebook {
                searchText = ""
                semanticHits = []
            }
        }
    }

    private func runSemanticSearch() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        semanticHits = await SemanticSearch.ranked(notes, query: query)
    }
}

struct EmptyDetailView: View {
    let notebooks: Int
    let notes: Int
    let words: Int
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            AutumnTheme.paper(scheme).ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(AutumnTheme.accentGradient.opacity(0.16))
                        .frame(width: 132, height: 132)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 58, weight: .light))
                        .foregroundStyle(AutumnTheme.accentGradient)
                }

                VStack(spacing: 8) {
                    Text("Marcus's Note")
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(AutumnTheme.text(scheme))
                    Text("Tieni le slide del primo semestre, il quaderno di esercizi e la lista delle materie. Tutto in un posto, tutto tuo.")
                        .font(.callout)
                        .foregroundStyle(AutumnTheme.textSoft(scheme))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }

                HStack(spacing: 26) {
                    stat("Quaderni", "\(notebooks)", "book.closed")
                    stat("Note", "\(notes)", "doc.text")
                    stat("Parole", "\(words.formatted(.number.grouping(.automatic)))", "textformat")
                }
                .padding(.top, 6)
            }
            .padding(40)
        }
    }

    private func stat(_ label: String, _ value: String, _ symbol: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(AutumnTheme.rust)
            Text(value)
                .font(.title3.weight(.semibold).monospacedDigit())
                .foregroundStyle(AutumnTheme.text(scheme))
            Text(label)
                .font(.caption)
                .foregroundStyle(AutumnTheme.textFaint(scheme))
        }
        .frame(width: 96)
    }
}