import Foundation
import SwiftUI

@MainActor
final class AIService: ObservableObject {
    static let shared = AIService()

    enum Status: Equatable {
        case unknown
        case checking
        case online
        case offline(String)
    }

    @Published private(set) var status: Status = .unknown
    @Published private(set) var availableModels: [String] = []
    @Published private(set) var isGenerating: Bool = false
    @Published private(set) var streamText: String = ""

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 120
        cfg.timeoutIntervalForResource = 600
        return URLSession(configuration: cfg)
    }()

    private init() {}

    struct ChatPayload: Codable {
        let role: String
        let content: String
    }

    private struct ChatRequest: Codable {
        let model: String
        let messages: [ChatPayload]
        let stream: Bool
        let options: Options
        struct Options: Codable {
            let temperature: Double
        }
    }

    private struct StreamChunk: Codable {
        struct Message: Codable { let content: String }
        let message: Message?
        let done: Bool?
        let error: String?
    }

    private struct TagsResponse: Codable {
        struct Model: Codable { let name: String }
        let models: [Model]?
    }

    private struct EmbedRequest: Codable {
        let model: String
        let input: String
    }

    private struct EmbedResponse: Codable {
        let embeddings: [[Double]]?
        let embedding: [Double]?
    }

    private struct ChatResponse: Codable {
        struct Message: Codable { let content: String }
        let message: Message?
        let error: String?
    }

    enum ServiceError: LocalizedError {
        case badURL
        case offline(String)
        case server(String)
        case noModel

        var errorDescription: String? {
            switch self {
            case .badURL:
                return "Indirizzo del server non valido."
            case .offline(let m):
                return m
            case .server(let m):
                return m
            case .noModel:
                return "Nessun modello disponibile. Avvia Ollama e scarica un modello."
            }
        }
    }

    func checkStatus() async {
        status = .checking
        do {
            var req = URLRequest(url: AISettings.shared.baseURL.appendingPathComponent("api/tags"))
            req.httpMethod = "GET"
            req.timeoutInterval = 5
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                status = .offline("Risposta non valida dal server.")
                return
            }
            if http.statusCode != 200 {
                status = .offline("Server ha risposto con codice \(http.statusCode).")
                return
            }
            let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
            availableModels = (decoded.models ?? []).map(\.name)
            status = .online
            if !availableModels.contains(AISettings.shared.model),
               let first = availableModels.first {
                AISettings.shared.model = first
            }
        } catch {
            status = .offline(friendlyOfflineMessage(error))
        }
    }

    private func friendlyOfflineMessage(_ error: Error) -> String {
        let urlError = error as? URLError
        switch urlError?.code {
        case .some(.cannotConnectToHost), .some(.cannotFindHost):
            return "Ollama non raggiungibile su \(AISettings.shared.hostLabel). Verifica che sia in esecuzione e che l'iPad e il PC siano sulla stessa rete Wi-Fi."
        case .some(.timedOut):
            return "Timeout di connessione verso \(AISettings.shared.hostLabel)."
        case .some(.networkConnectionLost):
            return "Connessione di rete persa."
        default:
            return error.localizedDescription
        }
    }

    private func resolveModel(override: String?) throws -> String {
        let requested = (override?.isEmpty == false) ? override! : AISettings.shared.model
        guard !requested.isEmpty else { throw ServiceError.noModel }
        if !availableModels.isEmpty && !availableModels.contains(requested) {
            throw ServiceError.server("Il modello \"\(requested)\" non è installato. Fallo scaricare con: ollama pull \(requested)")
        }
        return requested
    }

    func buildMessages(system: String?, context: String, user: String) -> [ChatPayload] {
        var messages: [ChatPayload] = [
            ChatPayload(role: "system", content: AISettings.shared.systemPrompt)
        ]
        if let system, !system.isEmpty {
            messages.append(ChatPayload(role: "system", content: system))
        }
        if !context.isEmpty {
            messages.append(ChatPayload(
                role: "user",
                content: "Ecco il materiale di riferimento (appunti dello studente):\n\n---\n\(context)\n---\n"
            ))
        }
        messages.append(ChatPayload(role: "user", content: user))
        return messages
    }

    func generateStreaming(
        messages: [ChatPayload],
        model: String? = nil,
        onToken: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        let usedModel = try resolveModel(override: model)
        var req = URLRequest(url: AISettings.shared.baseURL.appendingPathComponent("api/chat"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ChatRequest(
            model: usedModel,
            messages: messages,
            stream: true,
            options: .init(temperature: AISettings.shared.temperature)
        )
        req.httpBody = try JSONEncoder().encode(body)

        isGenerating = true
        streamText = ""
        defer { isGenerating = false }

        do {
            let (bytes, response) = try await session.bytes(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw ServiceError.server("Server ha risposto con codice \(http.statusCode).")
            }

            var accumulated = ""
            var buffer = Data()
            for try await byte in bytes {
                buffer.append(byte)
                while let idx = buffer.firstIndex(of: 0x0A) {
                    let line = buffer[buffer.startIndex..<idx]
                    buffer.removeSubrange(buffer.startIndex...idx)
                    guard !line.isEmpty,
                          let decoded = try? JSONDecoder().decode(StreamChunk.self, from: Data(line))
                    else { continue }
                    if let err = decoded.error { throw ServiceError.server(err) }
                    if let piece = decoded.message?.content, !piece.isEmpty {
                        accumulated += piece
                        onToken(accumulated)
                    }
                    if decoded.done == true { break }
                }
            }
            streamText = accumulated
            return accumulated
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.offline(friendlyOfflineMessage(error))
        }
    }

    func generate(messages: [ChatPayload], model: String? = nil) async throws -> String {
        try await generateStreaming(messages: messages, model: model) { _ in }
    }

    func embed(_ text: String) async throws -> [Float] {
        var req = URLRequest(url: AISettings.shared.baseURL.appendingPathComponent("api/embed"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(EmbedRequest(model: AISettings.shared.embedModel, input: text))
        let (data, _) = try await session.data(for: req)
        let decoded = try JSONDecoder().decode(EmbedResponse.self, from: data)
        if let vectors = decoded.embeddings, let first = vectors.first {
            return first.map(Float.init)
        }
        if let single = decoded.embedding {
            return single.map(Float.init)
        }
        throw ServiceError.server("Embeddings non disponibili per il modello \(AISettings.shared.embedModel).")
    }

    func isEmbeddingAvailable() async -> Bool {
        do {
            var req = URLRequest(url: AISettings.shared.baseURL.appendingPathComponent("api/tags"))
            req.timeoutInterval = 4
            let (data, _) = try await session.data(for: req)
            let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
            return (decoded.models ?? []).contains { $0.name == AISettings.shared.embedModel }
        } catch {
            return false
        }
    }
}

enum VectorMath {
    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        guard !a.isEmpty, a.count == b.count else { return 0 }
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for i in a.indices {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denominator = (normA * normB).squareRoot()
        guard denominator > 0 else { return 0 }
        return Double(dot / denominator)
    }
}