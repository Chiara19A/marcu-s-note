import SwiftUI
import SwiftData

struct AIStudioView: View {
    let note: Note
    var initialAction: AIAction?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    @StateObject private var ai = AIService.shared
    @StateObject private var settings = AISettings.shared

    @State private var selectedAction: AIAction?
    @State private var output = ""
    @State private var isRunning = false
    @State private var errorMessage: String?
    @State private var showingSettings = false
    @State private var history: [(action: AIAction, text: String)] = []

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 10)]

    var body: some View {
        NavigationStack {
            ZStack {
                AutumnTheme.paper(scheme).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            emptyNoteWarning
                        }

                        actionsGrid
                        resultPanel
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Scheda IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingSettings = true
                    } label: {
                        Label("Impostazioni", systemImage: "cpu")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                AISettingsView()
            }
            .onAppear {
                if let initialAction {
                    selectedAction = initialAction
                }
            }
            .overlay(alignment: .bottom) { statusBar }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(AutumnTheme.textSoft(scheme))
            Spacer()
            Text(settings.model)
                .font(.caption.monospaced())
                .foregroundStyle(AutumnTheme.textFaint(scheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.bar)
    }

    private var statusColor: Color {
        switch ai.status {
        case .online: return AutumnTheme.olive
        case .checking: return AutumnTheme.amber
        case .offline: return AutumnTheme.terracotta
        case .unknown: return AutumnTheme.textFaint(scheme)
        }
    }

    private var statusText: String {
        switch ai.status {
        case .online: return "Ollama connesso · \(settings.hostLabel)"
        case .checking: return "Connessione a Ollama…"
        case .offline(let reason): return reason
        case .unknown: return "IA non configurata"
        }
    }

    private var emptyNoteWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AutumnTheme.amber)
            Text("La nota è vuota. Scrivi qualcosa prima di usare l'IA, altrimenti il risultato sarà generico.")
                .font(.footnote)
                .foregroundStyle(AutumnTheme.textSoft(scheme))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(AutumnTheme.amber.opacity(0.12)))
    }

    private var actionsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COSA VUOI FARE")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AutumnTheme.textFaint(scheme))

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(AIAction.allCases) { action in
                    Button {
                        run(action)
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: action.symbol)
                                .font(.callout)
                                .frame(width: 28, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(action.tint.opacity(0.18))
                                )
                                .foregroundStyle(action.tint)
                            Text(action.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AutumnTheme.text(scheme))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(scheme == .dark ? AutumnTheme.nightSurfaceHi : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            isRunning && selectedAction == action
                                                ? action.tint
                                                : AutumnTheme.border(scheme),
                                            lineWidth: isRunning && selectedAction == action ? 1.6 : 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isRunning || ai.status != .online)
                }
            }

            if ai.status != .online {
                Button {
                    Task { await ai.checkStatus() }
                } label: {
                    Label("Riprova connessione con Ollama", systemImage: "arrow.clockwise")
                        .font(.footnote)
                }
                .padding(.top, 2)
            }
        }
    }

    @ViewBuilder
    private var resultPanel: some View {
        if let errorMessage {
            VStack(alignment: .leading, spacing: 8) {
                Label("Errore", systemImage: "xmark.octagon.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AutumnTheme.terracotta)
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(AutumnTheme.textSoft(scheme))
                    .textSelection(.enabled)
                Text("Controlla l'indirizzo del server in Impostazioni IA.")
                    .font(.caption2)
                    .foregroundStyle(AutumnTheme.textFaint(scheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(AutumnTheme.terracotta.opacity(0.09)))
        } else if !output.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if let selectedAction {
                        Label(selectedAction.title, systemImage: selectedAction.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedAction.tint)
                    }
                    Spacer()
                    if isRunning { ProgressView().controlSize(.small) }
                }

                MarkdownPreview(markdown: output, fontSize: 15)

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = output
                    } label: {
                        Label("Copia", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        appendToNote()
                    } label: {
                        Label("Aggiungi alla nota", systemImage: "text.append")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AutumnTheme.rust)

                    Spacer()

                    if !history.isEmpty {
                        Button {
                            output = ""
                        } label: {
                            Label("Pulisci", systemImage: "xmark")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(scheme == .dark ? AutumnTheme.nightSurface : Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
            )
        }
    }

    private func run(_ action: AIAction) {
        selectedAction = action
        output = ""
        errorMessage = nil
        isRunning = true

        Task {
            do {
                let result = try await NoteAIEngine.run(action: action, note: note) { partial in
                    output = partial
                }
                output = result
                history.append((action, result))
                if history.count > 12 { history.removeFirst() }
            } catch {
                errorMessage = error.localizedDescription
            }
            isRunning = false
        }
    }

    private func appendToNote() {
        guard let selectedAction else { return }
        let separator = note.content.isEmpty ? "" : "\n\n---\n\n"
        note.content += "\(separator)## \(selectedAction.title)\n\n\(output)\n"
        note.touch()
        try? context.save()
        dismiss()
    }
}