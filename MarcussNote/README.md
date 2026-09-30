# 🍂 Marcus's Note

App per iPad pensata per **prendere appunti universitari**. Interfaccia pulita, tema autunnale, matita Apple, integrazione PDF e **intelligenza artificiale completamente offline**.

Nessun account, nessun abbonamento, nessun tetto alle note.

---

## Indice

1. [Cosa fa](#cosa-fa)
2. [Requisiti](#requisiti)
3. [Come ottenere l'IPA da Windows](#come-ottenere-lipa-da-windows)
4. [Installazione sull'iPad con Sideloadly](#installazione-sullipad-con-sideloadly)
5. [Alternativa: AltStore (rinnovo automatico)](#alternativa-altstore-rinnovo-automatico)
6. [Collegare l'IA offline](#collegare-lia-offline)
7. [Scorciatoie da tastiera](#scorciatoie-da-tastiera)
8. [Compilare in locale da Mac](#compilare-in-locale-da-mac)
9. [Struttura del progetto](#struttura-del-progetto)
10. [Problemi frequenti](#problemi-frequenti)

---

## Cosa fa

### Organizzazione
- **Quaderni** con emoji e colore, con sottocartelle per argomento
- Sezioni smart: *Tutte le note*, *Preferiti*, *Recenti*, *Cestino*
- Vista **Materie** per corso e **Tag** incrociati
- Ordinamento per modifica, creazione o titolo
- Colore personalizzato per ogni nota

### Scrittura
- **Markdown** completo: titoli, grassetto, corsivo, codice, liste, citazioni
- **Formule LaTeX** con `$inline$` e `$$blocco$$`
- Tre modalità: **Editor**, **Anteprima** (impaginata), **Affiancato** (sorgente + anteprima)
- Barra di formattatura che agisce sul testo selezionato
- Statistiche live: parole, caratteri, tempo di lettura

### Matita e canvas
- **PencilKit** a piena pagina: penna, evidenziatore, matita
- 5 colori, 4 spessori, griglia a quadretti come sfondo
- Il disegno viene salvato **nella nota** e resta associato a essa

### Allegati
- **PDF** (importati e visualizzati con PDFKit)
- **Foto e screenshot** dalla libreria
- **Registrazione audio** delle lezioni, con player integrato e riproduzione
- Export singolo in **PDF**, **Markdown** o **HTML**

### Intelligenza artificiale (offline)
Pannello "Scheda IA" con 12 azioni sul testo corrente:

| Azione | A cosa serve |
|---|---|
| Riassumi | Sintesi compatta della lezione |
| Punti chiave | I 10 concetti da sapere |
| Spiega meglio | Passaggi poco chiari, con esempi |
| Spiega semplice | Come a uno studente del primo anno |
| Genera quiz | 10 domande d'esame con soluzioni |
| Flashcard | 20 schede in formato pronto da stampare |
| Schema / indice | Struttura gerarchica per ripassare |
| Mappa mentale | Albero dei concetti |
| Formule utili | Tutte le formule con spiegazione dei simboli |
| Traduci in inglese | Versione inglese accademica |
| Migliora il testo | Stesura più precisa e uniforme |
| Preparazione esame | Piano di ripasso completo |

Ogni risultato si può **copiare** o **aggiungere direttamente alla nota**.

In più c'è **Chat con le note**: fai una domanda e l'app cerca automaticamente le note pertinenti (ricerca semantica con embeddings) e risponde basandosi solo su quelle.

---

## Requisiti

- **iPad con iPadOS 17 o successivo**
- Un computer **Windows 10/11** (per la compilazione) — non serve un Mac
- Un **Apple ID** (quello gratuito va benissimo)
- Per l'IA: un computer con [Ollama](https://ollama.com) e ~4 GB di RAM liberi

---

## Come ottenere l'IPA da Windows

Su Windows non puoi compilare direttamente (serve Xcode, che gira solo su macOS). La soluzione è **GitHub Actions**: il repository viene compilato da un server Apple e tu scarichi l'IPA pronto.

### 1. Crea il repository su GitHub

Vai su [github.com/new](https://github.com/new), metti un nome (es. `marcusnote`) e lascia il repository **privato**.

### 2. Carica i file

Carica il contenuto di questa cartella nel repository. Il modo più semplice:

```bash
cd MarcussNote
git init
git add .
git commit -m "Marcus's Note v1.0"
git branch -M main
git remote add origin https://github.com/TUO-USERNAME/marcusnote.git
git push -u origin main
```

Se non hai Git installato, scaricalo da [git-scm.com](https://git-scm.com/download/win) e riavvia il terminale.

In alternativa puoi caricare i file direttamente dal browser: pulsante **Add file → Upload files**, trascina la cartella `MarcussNote`, la cartella `.github` e `Info.plist`.

### 3. Avvia la compilazione

1. Vai nella scheda **Actions** del repository
2. Seleziona **Build IPA** dalla lista a sinistra
3. Clicca **Run workflow**
4. Attendi 4-8 minuti (la prima volta l'ambiente si avvia lentamente)

### 4. Scarica l'IPA

A compilazione finita:

1. Clicca sulla run appena conclusa
2. In fondo trovi **Artifacts**
3. Scarica `MarcussNote-IPA`
4. Estrai lo ZIP: dentro c'è `MarcussNote-Release.ipa`

L'IPA è **non firmato**: verrà firmato dal tuo Apple ID durante l'installazione con Sideloadly.

---

## Installazione sull'iPad con Sideloadly

### Preparazione
- Installa [iTunes](https://www.apple.com/itunes/) o **Apple Devices** da Microsoft Store (serve per il driver USB)
- Collega l'iPad al PC con un cavo USB
- Sull'iPad: **Impostazioni → Privacy e sicurezza → Modalità sviluppatore** → attiva **App Sideload**

### Installazione
1. Scarica [Sideloadly](https://sideloadly.io/it) ed installalo
2. Collega l'iPad, assicurati che venga riconosciuto (icona verde)
3. Trascina `MarcussNote-Release.ipa` nella finestra di Sideloadly
4. Inserisci l'Apple ID e la password con cui usi l'App Store
5. Clicca **Start** e attendi 2-5 minuti
6. Se richiede un codice di verifica, accettalo sull'iPad

### Validità
Con Apple ID gratuito l'app funziona per **7 giorni**. Per rinnovarla basta rilanciare Sideloadly con lo stesso IPA: viene rifirmata per altri 7 giorni.

---

## Alternativa: AltStore (rinnovo automatico)

AltStore rinnova da solo finché **AltServer resta acceso** sulla stessa rete Wi-Fi dell'iPad.

1. Scarica AltServer per Windows da [altstore.io](https://altstore.io)
2. **Su Windows:** installa AltServer. Comparirà un'icona nella barra delle vicinanze. Tasto destro → **Install AltStore** → seleziona l'iPad → inserisci l'Apple ID
3. **Su iPad:** scarica AltStore, poi Impostazioni → Generali → VPN & Gestione dispositivo → **Consenti** il profilo del tuo Apple ID
4. **Su Windows:** tasto destro sull'icona AltServer → **Install IPA** → seleziona l'IPA
5. Tasto destro su AltServer → **Background Refresh** e lascialo acceso

Da quel momento l'app si reinstalla da sola ogni 7 giorni. Nessun intervento manuale.

---

## Collegare l'IA offline

L'app usa **[Ollama](https://ollama.com)** sul tuo computer. Tutto gira in locale: nessuna richiesta esce dalla tua rete.

### Sul computer

```bash
# scarica Ollama da https://ollama.com
ollama pull llama3.2:3b
ollama pull nomic-embed-text
```

Scarica i modelli una volta sola. Per un PC con 8 GB di RAM `llama3.2:3b` è la scelta più equilibrata. Con 16 GB e/o GPU puoi salire a `qwen2.5:7b` per risposte migliori.

Verifica che sia attivo:
```bash
curl http://localhost:11434/api/tags
```

### Scoprire l'IP del computer
Su Windows apri il Prompt dei comandi e digita `ipconfig`. Cerca **Indirizzo IPv4**, es. `192.168.1.5`.

### Nell'app
1. Apri **Impostazioni IA** (nella sidebar, in basso)
2. Inserisci `http://192.168.1.5:11434`
3. Tocca **Verifica connessione**
4. Deve comparire "Connesso · N modelli trovati"

> `localhost` sull'iPad punta all'iPad stesso, non al computer. Per l'app è sempre necessario l'IP locale del computer.

### Se non si connette
- iPad e computer devono essere sulla **stessa rete Wi-Fi**
- Alcuni router isolano i dispositivi (AP isolation). Cambia rete o usa l'hotspot del telefono
- Su Windows, consenti Node.js nelle regole del firewall di Defender quando richiesto
- Verifica che `ollama serve` sia in esecuzione in una finestra di terminale

---

## Scorciatoie da tastiera

Utili con Magic Keyboard o tastiera Bluetooth:

| Tasto | Funzione |
|---|---|
| `⌘ + N` | Nuova nota |
| `⌘ + ⇧ + F` | Segna come preferita |
| `⌘ + ⇧ + C` | Apri canvas |
| `⌘ + ⇧ + I` | Apri Scheda IA |
| `⌘ + S` | Salva ed esporta in PDF |
| `⌘ + B` / `⌘ + I` | Grassetto / corsivo |

---

## Compilare in locale da Mac

Se in futuro hai un Mac, puoi compilare direttamente:

```bash
open MarcusNote.xcodeproj
```

Poi in Xcode: **Product → Archive**, poi **Distribute App → Ad Hoc** e scegli il tuo team.

Per firmare con account gratuito: **Organize → Developer → Add Account**, Apple ID personale, poi seleziona il team in **Signing & Capabilities**.

---

## Struttura del progetto

```
MarcussNote/
├── MarcusNote.xcodeproj/
│   └── project.pbxproj          progetto Xcode 16 (gruppi sincronizzati)
├── Info.plist                   permessi, orientamenti, ATS per Ollama
├── ExportOptions.plist          export IPA non firmato
├── .github/workflows/
│   └── build-ipa.yml            compilazione automatica su macOS runner
└── MarcussNote/
    ├── App/
    │   └── MarcussNoteApp.swift       @main, container SwiftData, RootView
    ├── Models/
    │   └── Note.swift                 Notebook, Note, Attachment, ChatMessage
    ├── Theme/
    │   └── AutumnTheme.swift          palette + temi chiaro/scuro
    ├── Services/
    │   ├── AISettings.swift           configurazione modello/host
    │   ├── AIService.swift            client Ollama (streaming + embeddings)
    │   ├── AIAction.swift             12 azioni IA + motore
    │   ├── SemanticSearch.swift       RAG, cosine similarity, seed dati
    │   ├── MarkdownService.swift      Markdown + formattazione selezione
    │   ├── ExportService.swift        PDF / Markdown / HTML
    │   └── FileStore.swift            registrazioni audio, documenti
    └── Views/
        ├── Sidebar/
        │   ├── SidebarView.swift      quaderni, materie, tag, cestino
        │   └── NoteListView.swift     lista filtrata + ricerca semantica
        ├── Editor/
        │   ├── NoteEditorView.swift   editor, formattazione, export
        │   ├── MarkdownTextEditor.swift  UITextView con cursore
        │   ├── CanvasSheet.swift       PencilKit
        │   └── AttachmentViews.swift   PDF, immagini, audio, info
        ├── AI/
        │   ├── AIStudioView.swift     pannello azioni
        │   ├── AIChatView.swift       chat con RAG sulle note
        │   └── AISettingsView.swift   configurazione Ollama
        └── Components/
            └── CommonViews.swift      anteprima, tag, strip allegati, player
```

**Stack:** Swift 5 · SwiftUI · SwiftData · PencilKit · PDFKit · AVFoundation
**Minimo:** iPadOS 17.0 · **Battito identificativo:** `com.marcus.marcusnote`

---

## Problemi frequenti

**L'IPA non viene generato**
Apri il log della run su GitHub Actions. Di solito è Xcode sbagliato o un errore di compilazione.

**Sideloadly dice "设备 non supportato" / errore driver**
Reinstalla iTunes o Apple Devices da Microsoft Store, prova una porta USB diversa, preferibilmente un cavo originale.

**L'app si chiude subito all'avvio**
Apri **Impostazioni → Privacy e sicurezza → Analisi** sull'iPad e incolla l'ID del crash report. Spesso è Apple ID con autenticazione a due fattori: in Sideloadly usa la password specifica per l'app.

**Non posso firmare con il mio Apple ID**
Ogni Apple ID gratuito può firmare 3 app per 7 giorni, rinnnovabili. Se hai già 3 app firmate, elimina le vecchie da Sideloadly.

**Ollama non risponde dall'iPad**
Verifica i punti sopra. In alternativa prova `http://host.docker.internal:11434` se Ollama gira in Docker, oppure configura `OLLAMA_HOST=0.0.0.0`.

**Le formule LaTeX non sono renderizzate**
L'app le mostra come sorgente formattato. Per l'impaginazione definitiva, esporta in PDF dal pannello Export.

---

## Licenza

Codice sorgente fornito per uso personale. Nessuna limitazione applicata al numero di note, quaderni, allegati o richieste IA: i limiti sono quelli che imposes tu (hardware, modello scelto, quota gratuita del tuo Apple ID).