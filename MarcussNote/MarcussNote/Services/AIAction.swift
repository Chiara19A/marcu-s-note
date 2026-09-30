import Foundation
import SwiftUI

enum AIAction: String, CaseIterable, Identifiable {
    case summarize
    case keyPoints
    case explain
    case simpler
    case quiz
    case flashcards
    case outline
    case mindMap
    case formulas
    case translateEN
    case improveWriting
    case examPrep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .summarize: return "Riassumi"
        case .keyPoints: return "Punti chiave"
        case .explain: return "Spiega meglio"
        case .simpler: return "Spiega semplice"
        case .quiz: return "Genera quiz"
        case .flashcards: return "Flashcard"
        case .outline: return "Schema / indice"
        case .mindMap: return "Mappa mentale"
        case .formulas: return "Formule utili"
        case .translateEN: return "Traduci in inglese"
        case .improveWriting: return "Migliora il testo"
        case .examPrep: return "Preparazione esame"
        }
    }

    var symbol: String {
        switch self {
        case .summarize: return "text.append"
        case .keyPoints: return "list.bullet.rectangle"
        case .explain: return "bubble.left.and.text.bubble.right"
        case .simpler: return "graduationcap"
        case .quiz: return "questionmark.circle"
        case .flashcards: return "rectangle.on.rectangle"
        case .outline: return "list.number"
        case .mindMap: return "point.3.connected.trianglepath.dotted"
        case .formulas: return "function"
        case .translateEN: return "character.book.closed"
        case .improveWriting: return "wand.and.stars"
        case .examPrep: return "checklist"
        }
    }

    var tint: Color {
        switch self {
        case .summarize, .keyPoints, .outline: return AutumnTheme.amber
        case .explain, .simpler, .examPrep: return AutumnTheme.rust
        case .quiz, .flashcards: return AutumnTheme.olive
        case .mindMap, .formulas: return AutumnTheme.terracotta
        case .translateEN, .improveWriting: return AutumnTheme.walnut
        }
    }

    var instruction: String {
        switch self {
        case .summarize:
            return "Riscrivi questi appunti in un riassunto chiaro e compatto. Usa un titolo, una sintesi in 3-5 frasi e poi i concetti principali in elenchi. Massimo 400 parole. Non aggiungere informazioni che non sono nel testo."
        case .keyPoints:
            return "Estrai i 10 concetti più importanti di questi appunti. Per ogni concetto scrivi: il termine chiave in grassetto e una spiegazione di massimo 2 righe. Alla fine aggiungi 3 formule o termini da memorizzare."
        case .explain:
            return "Analizza questi appunti e spiegami i passaggi che non sono chiari. Per ogni passaggio spiega: cosa dice, perché è importante e con un esempio concreto. Usa formule LaTeX quando servono ($...$)."
        case .simpler:
            return "Spiegami questi appunti come se fossi uno studente del primo anno che non ha mai visto la materia. Evita gergo tecnico, usa metafore semplici e un esempio pratico per ogni concetto."
        case .quiz:
            return "Crea 10 domande d'esame a risposta multipla sugli appunti forniti. Per ogni domanda: la domanda, 4 opzioni (A-D), la risposta corretta e una spiegazione di perché è corretta. Inizia dalle domande più difficili."
        case .flashcards:
            return "Crea 20 flashcard sugli appunti. Formato esatto per ogni flashcard:\n\n**Domanda:** ...\n\n**Risposta:** ...\n\nSeparate ogni flashcard con una riga di tre trattini (---). Non aggiungere numerazione."
        case .outline:
            return "Crea un indice gerarchico di questi appunti in Markdown, con titoli (##, ###) che seguano la struttura reale del contenuto. Serve come schema veloce per ripassare."
        case .mindMap:
            return "Crea una mappa mentale testuale di questi appunti. Usa l'argomento centrale come radice, poi 4-6 rami principali con sotto-rami, in formato Markdown indentato con i trattini. Aggiungi una breve etichetta descrittiva per ogni nodo."
        case .formulas:
            return "Da questi appunti estrai tutte le formule, le leggi e le definizioni formali. Per ognuna scrivi: la formula in LaTeX, il significato di ogni simbolo e a cosa serve. Includi anche le condizioni e i casi limite."
        case .translateEN:
            return "Traduci questi appunti in inglese accademico preciso, mantenendo la struttura Markdown, le formule in LaTeX e la terminologia tecnica corretta."
        case .improveWriting:
            return "Migliora la stesura di questi appunti: rendi il linguaggio più preciso e accademico, correggi ripetizioni, uniforma il registro e organizza meglio i paragrafi. Mantieni tutti i contenuti, cambia solo come sono espressi."
        case .examPrep:
            return "Preparami all'esame su questi appunti. Produci: 1) sintesi dei temi, 2) i 5 concetti che devo sapere a memoria, 3) le formule da ricordare, 4) 5 esercizi tipici con soluzione, 5) gli errori più comuni da evitare."
        }
    }

    func prompt(for note: Note) -> String {
        var body = note.content
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body = "Titolo: \(note.displayTitle)"
        }
        return "\(instruction)\n\n### Materiale\n\(body)"
    }

    func systemPrompt(for note: Note) -> String {
        var context = "Stai aiutando lo studente con la nota «\(note.displayTitle)»"
        if !note.notebookName.isEmpty {
            context += " del quaderno «\(note.notebookName)»"
        }
        if !note.courseName.isEmpty {
            context += " — materia: \(note.courseName)"
        }
        context += ".\nRispondi in italiano. Usa il formato Markdown. Non ripetere testualmente l'intera nota: sintetizza."
        return context
    }
}

@MainActor
enum NoteAIEngine {

    static func run(
        action: AIAction,
        note: Note,
        onToken: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        let service = AIService.shared
        let context = MarkdownService.plain(note.content).prefix(6000)
        let messages = service.buildMessages(
            system: action.systemPrompt(for: note),
            context: String(context),
            user: action.instruction
        )
        return try await service.generateStreaming(messages: messages, onToken: onToken)
    }

    static func ask(
        question: String,
        note: Note?,
        history: [ChatMessage],
        onToken: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        let service = AIService.shared

        var payload: [AIService.ChatPayload] = []
        payload.append(.init(role: "system", content: AISettings.shared.systemPrompt))

        for message in history.suffix(8) {
            payload.append(.init(role: message.role.rawValue, content: message.content))
        }

        var context = ""
        if let note {
            context = "Nota aperta «\(note.displayTitle)»:\n\(MarkdownService.plain(note.content).prefix(4000))"
        }

        let userText = context.isEmpty ? question : "\(question)\n\n[Riprova]\n\(context)"
        payload.append(.init(role: "user", content: userText))

        return try await service.generateStreaming(messages: payload, onToken: onToken)
    }
}