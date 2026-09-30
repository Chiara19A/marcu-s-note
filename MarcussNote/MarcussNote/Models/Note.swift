import Foundation
import SwiftData

@Model
final class Notebook {
    var id: UUID = UUID()
    var name: String = "Nuovo quaderno"
    var emoji: String = ""
    var colorIndex: Int = 0
    var createdAt: Date = Date()
    var sortIndex: Int = 0
    var parentID: UUID?
    var isArchived: Bool = false

    init(
        name: String = "Nuovo quaderno",
        emoji: String = "",
        colorIndex: Int = 0,
        parentID: UUID? = nil,
        sortIndex: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.colorIndex = colorIndex
        self.parentID = parentID
        self.sortIndex = sortIndex
        self.createdAt = Date()
    }

    var displayTitle: String {
        emoji.isEmpty ? name : "\(emoji)  \(name)"
    }
}

enum AttachmentKind: String, Codable, CaseIterable {
    case image
    case pdf
    case audio
    case file

    var label: String {
        switch self {
        case .image: return "Immagine"
        case .pdf: return "PDF"
        case .audio: return "Audio"
        case .file: return "File"
        }
    }

    var symbol: String {
        switch self {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .audio: return "waveform"
        case .file: return "paperclip"
        }
    }
}

@Model
final class Attachment {
    var id: UUID = UUID()
    var kindRaw: String = AttachmentKind.image.rawValue
    var fileName: String = ""
    var caption: String = ""
    var sortIndex: Int = 0
    var createdAt: Date = Date()
    var byteCount: Int = 0
    @Attribute(.externalStorage) var data: Data = Data()
    var note: Note?

    var kind: AttachmentKind {
        get { AttachmentKind(rawValue: kindRaw) ?? .file }
        set { kindRaw = newValue.rawValue }
    }

    init(kind: AttachmentKind, fileName: String, data: Data, caption: String = "", sortIndex: Int = 0) {
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.fileName = fileName
        self.data = data
        self.caption = caption
        self.sortIndex = sortIndex
        self.byteCount = data.count
        self.createdAt = Date()
    }

    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }
}

@Model
final class Note {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var isFavorite: Bool = false
    var isPinned: Bool = false
    var isArchived: Bool = false
    var isTrashed: Bool = false
    var colorIndex: Int = 0
    var tags: [String] = []
    var notebookID: UUID?
    var notebookName: String = ""
    var courseName: String = ""
    var drawingData: Data = Data()
    var audioFileName: String = ""
    var wordCountCache: Int = 0
    var embeddingCache: [Float] = []
    var embeddingModel: String = ""
    @Relationship(deleteRule: .cascade, inverse: \Attachment.note)
    var attachments: [Attachment] = []

    init(
        title: String = "",
        content: String = "",
        notebookID: UUID? = nil,
        notebookName: String = "",
        colorIndex: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.notebookID = notebookID
        self.notebookName = notebookName
        self.colorIndex = colorIndex
        self.createdAt = Date()
        self.modifiedAt = Date()
    }

    var previewText: String {
        let stripped = content
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped
    }

    var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return title }
        let firstLine = content
            .split(separator: "\n")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        return firstLine.isEmpty ? "Nuova nota" : String(firstLine.prefix(60))
    }

    var computedWordCount: Int {
        content.split(whereSeparator: { $0 == " " || $0 == "\n" || $0 == "\t" }).count
    }

    var readingTimeMinutes: Int {
        max(1, Int(ceil(Double(computedWordCount) / 220.0)))
    }

    var sortedAttachments: [Attachment] {
        attachments.sorted { $0.sortIndex < $1.sortIndex }
    }

    func touch() {
        modifiedAt = Date()
        wordCountCache = computedWordCount
    }
}

@Model
final class ChatMessage {
    var id: UUID = UUID()
    var roleRaw: String = "user"
    var content: String = ""
    var createdAt: Date = Date()
    var noteID: UUID?
    var noteTitle: String = ""

    enum Role: String {
        case user
        case assistant
        case system
    }

    var role: Role {
        get { Role(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    init(role: Role, content: String, noteID: UUID? = nil, noteTitle: String = "") {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.content = content
        self.noteID = noteID
        self.noteTitle = noteTitle
        self.createdAt = Date()
    }
}