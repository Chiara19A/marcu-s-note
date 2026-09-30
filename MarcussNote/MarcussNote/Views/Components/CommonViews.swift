import SwiftUI
import UIKit
import AVFoundation

struct RichTextView: UIViewRepresentable {
    let attributed: NSAttributedString

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = true
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.adjustsFontForContentSizeCategory = true
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributed
    }
}

struct MarkdownPreview: View {
    let markdown: String
    var fontSize: CGFloat = 16

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        RichTextView(
            attributed: MarkdownService.nsAttributed(
                markdown,
                fontSize: fontSize,
                scheme: scheme
            )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TagChips: View {
    @Binding var tags: [String]
    var onPick: (String) -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var newTag = ""

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(tags, id: \.self) { tag in
                    Button {
                        onPick(tag)
                    } label: {
                        HStack(spacing: 4) {
                            Text("#\(tag)")
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AutumnTheme.rust)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(AutumnTheme.rust.opacity(0.11)))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                    TextField("tag", text: $newTag)
                        .font(.caption)
                        .frame(width: 62)
                        .onSubmit(commit)
                }
                .foregroundStyle(AutumnTheme.textFaint(scheme))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(AutumnTheme.subtleFill(scheme)))
            }
            .padding(.horizontal, 2)
        }
    }

    private func commit() {
        let cleaned = newTag
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .lowercased()
        newTag = ""
        guard !cleaned.isEmpty, !tags.contains(cleaned) else { return }
        tags.append(cleaned)
    }
}

struct AttachmentStrip: View {
    @Bindable var note: Note
    var onOpen: (Attachment) -> Void
    var onRecord: () -> Void
    var onImport: () -> Void
    var isRecording: Bool
    var recordingLabel: String

    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("ALLEGATI")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AutumnTheme.textFaint(scheme))

                Spacer()

                Button(action: onImport) {
                    Label("Allega", systemImage: "paperclip")
                        .font(.caption)
                }
                .buttonStyle(.borderless)

                Button(action: onRecord) {
                    Label(
                        isRecording ? "Ferma (\(recordingLabel))" : "Registra lezione",
                        systemImage: isRecording ? "stop.circle.fill" : "mic.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(isRecording ? AutumnTheme.terracotta : AutumnTheme.rust)
                }
                .buttonStyle(.borderless)
            }

            if note.sortedAttachments.isEmpty && note.audioFileName.isEmpty {
                Text("Nessun allegato. Aggiungi foto delle slide, PDF del libro o la registrazione della lezione.")
                    .font(.caption)
                    .foregroundStyle(AutumnTheme.textFaint(scheme))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        if !note.audioFileName.isEmpty {
                            chip(
                                symbol: "waveform",
                                title: "Lezione",
                                subtitle: note.audioFileName,
                                tint: AutumnTheme.terracotta
                            ) {
                                AudioPlayerView(fileName: note.audioFileName)
                                    .presentationDetents([.medium])
                            }
                        }

                        ForEach(note.sortedAttachments) { attachment in
                            chip(
                                symbol: attachment.kind.symbol,
                                title: attachment.caption.isEmpty ? attachment.fileName : attachment.caption,
                                subtitle: "\(attachment.kind.label) · \(attachment.sizeLabel)",
                                tint: AutumnTheme.noteColor(note.colorIndex)
                            ) {
                                onOpen(attachment)
                            }
                            .contextMenu {
                                Button("Elimina", systemImage: "trash", role: .destructive) {
                                    context.delete(attachment)
                                    try? context.save()
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func chip(
        symbol: String,
        title: String,
        subtitle: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.callout)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 8).fill(tint.gradient))

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AutumnTheme.text(scheme))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(AutumnTheme.textFaint(scheme))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 11)
                    .fill(AutumnTheme.chipBackground(scheme))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(AutumnTheme.border(scheme), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct AudioPlayerView: View {
    let fileName: String
    @Environment(\.colorScheme) private var scheme
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var error: String?

    private var url: URL { FileStore.recording(fileName: fileName) }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(AutumnTheme.accentGradient)

            VStack(spacing: 4) {
                Text("Registrazione lezione")
                    .font(.headline)
                Text(fileName)
                    .font(.caption)
                    .foregroundStyle(AutumnTheme.textFaint(scheme))
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(AutumnTheme.terracotta)
            }

            Slider(
                value: Binding(
                    get: { progress },
                    set: { progress = $0; seek(to: $0) }
                ),
                in: 0...max(duration, 0.1)
            )
            .tint(AutumnTheme.rust)

            HStack {
                Text(timeLabel(progress))
                Spacer()
                Text(timeLabel(duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(AutumnTheme.textSoft(scheme))

            Button {
                togglePlayback()
            } label: {
                Label(
                    isPlaying ? "Pausa" : "Riproduci",
                    systemImage: isPlaying ? "pause.fill" : "play.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(AutumnTheme.rust)
        }
        .padding(30)
        .onAppear { prepare() }
        .onDisappear { player?.stop() }
    }

    private var duration: Double {
        player?.duration ?? 0
    }

    private func prepare() {
        guard FileManager.default.fileExists(atPath: url.path) else {
            error = "File audio non trovato."
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
        } catch {
            error = "Impossibile aprire l'audio."
        }
    }

    private func togglePlayback() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    private func seek(to value: Double) {
        player?.currentTime = value
        if !isPlaying { player?.play(); isPlaying = true }
    }

    private func timeLabel(_ value: Double) -> String {
        let total = Int(value)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}