import Foundation
import SwiftUI

@MainActor
final class AISettings: ObservableObject {
    static let shared = AISettings()

    @Published var host: String {
        didSet { defaults.set(host, forKey: Keys.host) }
    }
    @Published var model: String {
        didSet { defaults.set(model, forKey: Keys.model) }
    }
    @Published var embedModel: String {
        didSet { defaults.set(embedModel, forKey: Keys.embedModel) }
    }
    @Published var temperature: Double {
        didSet { defaults.set(temperature, forKey: Keys.temperature) }
    }
    @Published var systemPrompt: String {
        didSet { defaults.set(systemPrompt, forKey: Keys.systemPrompt) }
    }
    @Published var autoEmbed: Bool {
        didSet { defaults.set(autoEmbed, forKey: Keys.autoEmbed) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let host = "ai.host"
        static let model = "ai.model"
        static let embedModel = "ai.embedModel"
        static let temperature = "ai.temperature"
        static let systemPrompt = "ai.systemPrompt"
        static let autoEmbed = "ai.autoEmbed"
    }

    static let defaultSystemPrompt = """
    Sei Marcus, un assistente di studio per uno studente universitario italiano.
    Rispondi SEMPRE in italiano, in modo chiaro, preciso e ben strutturato.
    Usa elenchi puntati quando servono. Non inventare riferimenti bibliografici.
    Quando ricevi il contenuto di appunti, basati esclusivamente su quel materiale
    e segnala esplicitamente se un'informazione non è presente.
    """

    static let suggestedModels = [
        "llama3.2:3b",
        "qwen2.5:7b",
        "qwen2.5:3b",
        "phi4",
        "mistral",
        "gemma2:2b",
        "deepseek-r1:7b",
        "smollm2"
    ]

    static let suggestedEmbedModels = [
        "nomic-embed-text",
        "mxbai-embed-large",
        "bge-m3",
        "all-minilm"
    ]

    private init() {
        let d = UserDefaults.standard
        defaults = d
        host = d.string(forKey: Keys.host) ?? "http://localhost:11434"
        model = d.string(forKey: Keys.model) ?? "llama3.2:3b"
        embedModel = d.string(forKey: Keys.embedModel) ?? "nomic-embed-text"
        temperature = d.object(forKey: Keys.temperature) as? Double ?? 0.7
        systemPrompt = d.string(forKey: Keys.systemPrompt) ?? Self.defaultSystemPrompt
        autoEmbed = d.object(forKey: Keys.autoEmbed) as? Bool ?? true
    }

    var baseURL: URL {
        var s = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { s = "http://localhost:11434" }
        if !s.hasPrefix("http://") && !s.hasPrefix("https://") { s = "http://" + s }
        return URL(string: s) ?? URL(string: "http://localhost:11434")!
    }

    var isLocalHost: Bool {
        let h = baseURL.host ?? ""
        return h == "localhost" || h == "127.0.0.1"
    }

    var hostLabel: String {
        baseURL.absoluteString
    }

    static let hostHelpText = """
    Sul computer: installa Ollama, poi avvialo con `ollama serve`.
    Ollama ascolta solo sul computer, quindi dall'iPad devi usare l'indirizzo \
    IP locale del computer (es. http://192.168.1.5:11434), non "localhost".
    iPad e computer devono essere sulla stessa rete Wi-Fi.
    Per scoprire l'IP del computer, digita "ipconfig" nel suo Prompt dei comandi.
    """

    static func lanSuggestions() -> [String] {
        ["http://localhost:11434", "http://192.168.1.100:11434", "http://host.docker.internal:11434"]
    }
}