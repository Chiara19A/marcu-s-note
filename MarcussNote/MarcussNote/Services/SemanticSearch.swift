import Foundation
import SwiftData
import SwiftUI

enum SemanticSearch {

    struct Hit: Identifiable {
        let note: Note
        let score: Double
        var id: UUID { note.id }
    }

    static func plainTextMatches(_ notes: [Note], query: String) -> [Note] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return notes }
        let needle = trimmed.lowercased()
        return notes.filter { note in
            note.title.lowercased().contains(needle)
                || note.content.lowercased().contains(needle)
                || note.tags.contains { $0.lowercased().contains(needle) }
                || note.courseName.lowercased().contains(needle)
        }
    }

    @MainActor
    static func ranked(_ notes: [Note], query: String) async -> [Hit] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, AISettings.shared.autoEmbed else { return [] }

        let embedder = notes.filter { !$0.embeddingCache.isEmpty }
        guard !embedder.isEmpty else { return [] }

        do {
            let queryVector = try await AIService.shared.embed(trimmed)
            return embedder
                .map { note in
                    Hit(note: note, score: VectorMath.cosineSimilarity(queryVector, note.embeddingCache))
                }
                .filter { $0.score > 0.25 }
                .sorted { $0.score > $1.score }
        } catch {
            return []
        }
    }

    @MainActor
    static func reindex(_ notes: [Note]) async {
        guard AISettings.shared.autoEmbed else { return }
        for note in notes {
            let text = embeddingText(for: note)
            guard !text.isEmpty else { continue }
            if note.embeddingModel == AISettings.shared.embedModel, !note.embeddingCache.isEmpty {
                continue
            }
            if let vector = try? await AIService.shared.embed(text), !vector.isEmpty {
                note.embeddingCache = vector
                note.embeddingModel = AISettings.shared.embedModel
            }
        }
    }

    static func embeddingText(for note: Note) -> String {
        var parts: [String] = []
        if !note.title.isEmpty { parts.append(note.title) }
        if !note.courseName.isEmpty { parts.append(note.courseName) }
        if !note.tags.isEmpty { parts.append(note.tags.joined(separator: " ")) }
        parts.append(MarkdownService.plain(note.content).prefix(1800))
        return parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    static func context(for question: String, notes: [Note], limit: Int = 4) async -> String {
        let hits = await ranked(notes, query: question).prefix(limit)
        guard !hits.isEmpty else { return "" }
        return hits.map { hit in
            "### \(hit.note.displayTitle)\n\(MarkdownService.plain(hit.note.content).prefix(2500))"
        }.joined(separator: "\n\n")
    }
}

@MainActor
enum DataSeeder {
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Note>()
        let existing = (try? context.fetchCount(descriptor)) ?? 0
        guard existing == 0 else { return }

        let lezioni = Notebook(
            name: "Lezioni",
            emoji: "🎓",
            colorIndex: 0
        )
        let appunti = Notebook(
            name: "Appunti personali",
            emoji: "✍️",
            colorIndex: 4
        )
        let formule = Notebook(
            name: "Formule & formule",
            emoji: "🧮",
            colorIndex: 2
        )
        context.insert(lezioni)
        context.insert(appunti)
        context.insert(formule)
        try? context.save()

        let benvenuto = Note(
            title: "Benvenuto in Marcus's Note",
            notebookID: lezioni.id,
            notebookName: lezioni.name,
            colorIndex: 0
        )
        benvenuto.content = """
        # Benvenuto ✍️

        Questa è la tua prima nota. **Tutto è salvato in locale sul tuo iPad**: nessun account, nessun abbonamento, nessun limite alle note.

        ## Cosa sai fare
        - Quaderni e sottocartelle per ogni materia
        - Testo in **Markdown** con formule $LaTeX$
        - **Apple Pencil** con matita, evidenziatore e forme
        - Allegati: PDF, foto, registrazioni audio delle lezioni
        - **IA offline** (Ollama): riassumi, spiega, genera quiz e flashcard

        ## Scrivere formule
        Usa la sintassi LaTeX tra parentesi dollari:

        - Inline: `$E = mc^2$`
        - Blocco: `$$\\int_0^1 x^2\\,dx = \\frac{1}{3}$$`

        ## Collegare l'IA offline
        1. Sul computer, installa [Ollama](https://ollama.com)
        2. Scarica un modello: `ollama pull llama3.2:3b`
        3. Apri **Impostazioni IA** e inserisci l'indirizzo del computer (es. `http://192.168.1.5:11434`)
        4. Toccate **Verifica connessione**

        Tutto gira in locale: le tue note non lasciano mai la tua rete.
        """
        benvenuto.isFavorite = true
        context.insert(benvenuto)

        let metodo = Note(
            title: "Metodo di studio",
            notebookID: appunti.id,
            notebookName: appunti.name,
            colorIndex: 4
        )
        metodo.content = """
        # Metodo di studio

        ## Regola dei 40 minuti
        1. **Recupero attivo** — chiudi il libro e ricostruisci la lezione a memoria.
        2. **Interrogazione** — usa **Quiz** e **Flashcard** della IA su questa nota.
        3. **Ripasso spaced** — rivedi la nota a 1, 3, 7 e 21 giorni.

        ## Checklist
        - [ ] Ho trasformato le slide in appunti propri
        - [ ] Ho generato le flashcard
        - [ ] Ho rifatto gli esercizi senza guardare
        - [ ] Ho spiegato il tema ad alta voce in 2 minuti
        """
        context.insert(metodo)

        let formulaNote = Note(
            title: "Integrali notevoli",
            notebookID: formule.id,
            notebookName: formule.name,
            colorIndex: 2
        )
        formulaNote.content = """
        # Integrali notevoli

        ## Basi
        $$\\int_0^1 x^n\\,dx = \\frac{1}{n+1}$$

        $$\\int e^{ax}\\,dx = \\frac{e^{ax}}{a} + C$$

        $$\\int \\frac{1}{x}\\,dx = \\ln|x| + C$$

        ## Attenzione
        Quando l'integrale è definito tra due punti, ricorda che $C$ sparisce:
        $$\\int_a^b f(x)\\,dx = F(b) - F(a)$$

        > Consiglio: usa **Scheda IA → Formule utili** su una lezione per estrarre
        > automaticamente tutte le formule con la spiegazione dei simboli.
        """
        context.insert(formulaNote)

        try? context.save()
    }
}