import SwiftUI
import SwiftData

struct AIChatView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    @Query(sort: \Note.modifiedAt, order: .reverse) private var notes: [Note]
    @Query private var chatMessages: [ChatMessage]

    @StateObject private var ai = AIService.shared
    @StateObject private var settings = AISettings.shared

    @State private var draft = ""
    @State private var isThinking = false
    @State private var errorMessage: String?
    @State private var usedContextTitles: [String] = []

    private var conversation: [ChatMessage] {
        chatMessages.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AutumnTheme.paper(scheme).ignoresSafeArea()

                VStack(spacing: 0) {
                    contextBanner

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 14) {
                                if conversation.isEmpty {
                                    welcomeBlock
                                }
                                ForEach(conversation) { message in
                                    bubble(for: message)
                                        .id(message.id)
                                }
                                if isThinking {
                                    thinkingBubble.id("thinking")
                                }
                            }
                            .padding(18)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: conversation.count) { _, _ in
                            withAnimation { proxy.scrollTo(conversation.last?.id ?? "thinking", anchor: .bottom) }
                        }
                    }

                    Divider().overlay(AutumnTheme.border(scheme))
                    composer
                }

                if ai.status != .online {
                    offlineOverlay
                }
            }
            .navigationTitle("Chat con le note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Svuota conversazione", systemImage: "trash", role: .destructive) {
                            clearChat()
                        }
                        Button("Impostazioni IA", systemImage: "cpu") {
                            Task { await ai.checkStatus() }
                        }
                    } label: {
                        Label("Altro", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
    }

    // MARK: - Blocchi

    private var contextBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "brain.head.profile")
                .foregroundStyle(AutumnTheme.olive)
            if usedContextTitles.isEmpty {
                Text("Cercherà le note rilevanti per ogni domanda")
                    .font(.caption)
                    .foregroundStyle(AutumnTheme.textSoft(scheme))
            } else {
                Text("Contesto: \(usedContextTitles.joined(separator: " · "))")
                    .font(.caption)
                    .foregroundStyle(AutumnTheme.textSoft(scheme))
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AutumnTheme.olive.opacity(0.09))
    }

    private var welcomeBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(AutumnTheme.accentGradient)
                Text("Marcus")
                    .font(.title3.weight(.semibold).serif())
                    .foregroundStyle(AutumnTheme.text(scheme))
            }

            Text("Fammi domande sui tuoi appunti. Cercherò automaticamente le note pertinenti e risponderò basandomi solo su quelle.")
                .font(.subheadline)
                .foregroundStyle(AutumnTheme.textSoft(scheme))

            VStack(alignment: .leading, spacing: 7) {
                suggestion("Riassumi i punti chiave di Derivazione")
                suggestion("Spiegami il teorema di Bayes con un esempio")
                suggestion("Fammi 5 domande d'esame su tutto")
                suggestion("Quali sono le formule da sapere?")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(scheme == .dark ? AutumnTheme.nightSurface : Color.white)
        )
    }

    private func suggestion(_ text: String) -> some View {
        Button {
            draft = text
            send()
        } label: {
            HStack {
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(AutumnTheme.walnut)
                Spacer()
                Image(systemName: "arrow.up.left")
                    .font(.caption2)
                    .foregroundStyle(AutumnTheme.textFaint(scheme))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(AutumnTheme.subtleFill(scheme))
            )
        }
        .buttonStyle(.plain)
    }

    private func bubble(for message: ChatMessage) -> some View {
        let isUser = message.role == .user
        return HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: .leading, spacing: 6) {
                if !isUser {
                    HStack(spacing: 5) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 9))
                        Text("Marcus")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(AutumnTheme.olive)
                }

                if isUser {
                    Text(message.content)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                } else {
                    MarkdownPreview(markdown: message.content, fontSize: 15)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isUser
                            ? AnyShapeStyle(AutumnTheme.accentGradient)
                            : AnyShapeStyle(scheme == .dark ? AutumnTheme.nightSurface : Color.white)
                    )
            )
            .shadow(color: .black.opacity(0.06), radius: 5, y: 2)

            if !isUser { Spacer(minLength: 60) }
        }
    }

    private var thinkingBubble: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "leaf.fill").font(.system(size: 9))
                    Text("Marcus sta ragionando")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AutumnTheme.olive)
                }
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(AutumnTheme.textFaint(scheme))
                            .frame(width: 6, height: 6)
                            .phaseAnimator([false, true]) { content, phase in
                                content.opacity(phase ? 1 : 0.25)
                            } animation: { _ in
                                .easeInOut(duration: 0.5).delay(Double(index) * 0.15)
                            }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(scheme == .dark ? AutumnTheme.nightSurface : Color.white)
            )
            Spacer(minLength: 60)
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Fai una domanda sui tuoi appunti…", text: $draft, axis: .vertical)
                .font(.subheadline)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(scheme == .dark ? AutumnTheme.nightSurfaceHi : Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(AutumnTheme.border(scheme), lineWidth: 1)
                        )
                )

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(AutumnTheme.accentGradient))
            }
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
            .opacity(isThinking ? 0.5 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var offlineOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "wifi.slash")
                    .font(.title2)
                Text(statusMessage)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                Button("Riprova") {
                    Task { await ai.checkStatus() }
                }
                .buttonStyle(.borderedProminent)
                .tint(AutumnTheme.rust)
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(scheme == .dark ? AutumnTheme.nightSurface : Color.white)
                    .shadow(color: .black.opacity(0.14), radius: 14, y: 5)
            )
            .padding(.bottom, 90)
        }
        .background(.black.opacity(scheme == .dark ? 0.5 : 0.28))
    }

    private var statusMessage: String {
        switch ai.status {
        case .offline(let reason): return reason
        case .checking: return "Connessione a Ollama…"
        default: return "Ollama non raggiungibile su \(settings.hostLabel)"
        }
    }

    // MARK: - Azioni

    private func send() {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isThinking else { return }

        draft = ""
        errorMessage = nil
        isThinking = true

        let userMessage = ChatMessage(role: .user, content: question)
        context.insert(userMessage)
        try? context.save()

        Task {
            do {
                let retrieved = await SemanticSearch.context(for: question, notes: notes)
                usedContextTitles = String(retrieved)
                    .components(separatedBy: "### ")
                    .dropFirst()
                    .map { String($0.prefix(40)) }

                let answer = try await NoteAIEngine.ask(
                    question: question,
                    note: nil,
                    history: Array(conversation.suffix(8)),
                    onToken: { _ in }
                )

                let reply = ChatMessage(role: .assistant, content: answer)
                context.insert(reply)
                try? context.save()
            } catch {
                errorMessage = error.localizedDescription
            }
            isThinking = false
        }
    }

    private func clearChat() {
        for message in chatMessages {
            context.delete(message)
        }
        usedContextTitles = []
        try? context.save()
    }
}