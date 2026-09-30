import Foundation
import SwiftUI
import AVFoundation

enum FileStore {
    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static var recordings: URL {
        let url = documents.appendingPathComponent("Recordings", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    static var exports: URL {
        let url = documents.appendingPathComponent("Exports", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    static func recordingURL() -> URL {
        recordings.appendingPathComponent("lezione_\(AppDate.fileStamp.string(from: Date())).m4a")
    }

    static func recording(fileName: String) -> URL {
        recordings.appendingPathComponent(fileName)
    }

    static func safeFileName(_ input: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        let cleaned = input.components(separatedBy: invalid).joined(separator: "-")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "esportazione" : String(trimmed.prefix(80))
    }
}

@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var permissionDenied = false

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var currentURL: URL?

    var elapsedLabel: String {
        let total = Int(elapsed)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    func toggle() async throws -> URL? {
        if isRecording {
            return stop()
        }
        return try await start()
    }

    func start() async throws -> URL? {
        let session = AVAudioSession.sharedInstance()
        let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            session.requestRecordPermission { ok in
                continuation.resume(returning: ok)
            }
        }
        guard granted else {
            permissionDenied = true
            throw NSError(domain: "MarcusNote.Audio", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Permesso microfono negato. Attivalo in Impostazioni."
            ])
        }

        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let url = FileStore.recordingURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()
        recorder.record()

        self.recorder = recorder
        currentURL = url
        elapsed = 0
        isRecording = true

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.elapsed = self.recorder?.currentTime ?? 0
            }
        }
        return url
    }

    @discardableResult
    func stop() -> URL? {
        recorder?.stop()
        recorder = nil
        timer?.invalidate()
        timer = nil
        isRecording = false
        elapsed = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return currentURL
    }
}