import SwiftUI

struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @StateObject private var settings = AISettings.shared
    @StateObject private var ai = AIService.shared

    @State private var hostDraft = ""
    @State private var modelDraft = ""
    @State private var embedDraft = ""
    @State private var embedAvailable: Bool?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://192.168.1.5:11434", text: $hostDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onSubmit(applyHost)

                    HStack {
                        Button("Applica indirizzo", action: applyHost)
                        Spacer()
                        Button("Verifica connessione") {
                            Task { await verify() }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AutumnTheme.rust)
                    }
                } header: {
                    Text("Server Ollama")
                } footer: {
                    Text(AISettings.hostHelpText)
                }

                Section {
                    statusRow

                    if !ai.availableModels.isEmpty {
                        Picker("Modello", selection: $modelDraft) {
                            ForEach(ai.availableModels, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .onChange(of: modelDraft) { _, newValue in
                            settings.model = newValue
                        }
                    } else {
                        TextField("nome-modello", text: $modelDraft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { settings.model = modelDraft }
                    }

                    HStack(spacing: 8) {
                        TextField("modello embeddings", text: $embedDraft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { settings.embedModel = embedDraft }
                        Button("Applica") { settings.embedModel = embedDraft }
                            .font(.caption)
                    }

                    if let embedAvailable {
                        Label(
                            embedAvailable
                                ? "Ricerca semantica disponibile"
                                : "Modello embeddings non installato",
                            systemImage: embedAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(embedAvailable ? AutumnTheme.olive : AutumnTheme.amber)
                    }

                    Toggle("Indicizza automaticamente le note", isOn: $settings.autoEmbed)
                        .tint(AutumnTheme.rust)
                } header: {
                    Text("Modelli")
                } footer: {
                    Text("Scaricali sul PC con: ollama pull <modello>")
                }

                Section {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Creatività")
                                .font(.subheadline)
                            Spacer()
                            Text(String(format: "%.1f", settings.temperature))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(AutumnTheme.textFaint(scheme))
                        }
                        Slider(value: $settings.temperature, in: 0...1.4, step: 0.1)
                            .tint(AutumnTheme.rust)
                        Text("0 = risposte precise e letterali · 1.4 = risposte più creative")
                            .font(.caption2)
                            .foregroundStyle(AutumnTheme.textFaint(scheme))
                    }
                }

                Section {
                    TextEditor(text: $settings.systemPrompt)
                        .font(.footnote)
                        .frame(minHeight: 130)

                    Button("Ripristina istruzioni predefinite") {
                        settings.systemPrompt = AISettings.defaultSystemPrompt
                    }
                    .font(.caption)
                } header: {
                    Text("Istruzioni di sistema")
                } footer: {
                    Text("Queste istruzioni vengono inviate al modello a ogni richiesta, insieme agli appunti selezionati.")
                }

                Section {
                    Label("Tutto funziona in locale: le note non lasciano mai la tua rete.", systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(AutumnTheme.olive)
                }
            }
            .navigationTitle("Impostazioni IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        applyHost()
                        settings.model = modelDraft
                        settings.embedModel = embedDraft
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                hostDraft = settings.host
                modelDraft = settings.model
                embedDraft = settings.embedModel
                Task {
                    await verify()
                    embedAvailable = await ai.isEmbeddingAvailable()
                }
            }
        }
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 9, height: 9)
            Text(statusText)
                .font(.subheadline)
            Spacer()
            if ai.status == .checking {
                ProgressView().controlSize(.small)
            }
        }
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
        case .online:
            return "Connesso · \(ai.availableModels.count) modelli trovati"
        case .checking:
            return "Connessione in corso…"
        case .offline(let reason):
            return reason
        case .unknown:
            return "Non verificato"
        }
    }

    private func applyHost() {
        settings.host = hostDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func verify() async {
        applyHost()
        await ai.checkStatus()
        embedAvailable = await ai.isEmbeddingAvailable()
    }
}