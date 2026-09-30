import Foundation
import SwiftUI
import UIKit
import CoreText

enum ExportFormat: String, CaseIterable, Identifiable {
    case markdown
    case html
    case pdf

    var id: String { rawValue }
    var label: String {
        switch self {
        case .markdown: return "Markdown (.md)"
        case .html: return "HTML (.html)"
        case .pdf: return "PDF (.pdf)"
        }
    }

    var fileExtension: String {
        switch self {
        case .markdown: return "md"
        case .html: return "html"
        case .pdf: return "pdf"
        }
    }
}

enum ExportService {

    static func markdown(from note: Note) -> String {
        var lines: [String] = []
        if !note.title.isEmpty {
            lines.append("# \(note.title)")
            lines.append("")
        }
        lines.append("_Creato il \(AppDate.italian.string(from: note.createdAt)) — modificato il \(AppDate.italian.string(from: note.modifiedAt))_")
        lines.append("")
        lines.append(note.content)

        if !note.tags.isEmpty {
            lines.append("")
            lines.append("Tag: " + note.tags.map { "#\($0)" }.joined(separator: " "))
        }
        return lines.joined(separator: "\n")
    }

    static func html(from note: Note) -> String {
        let body = markdown(from: note)
        let converted = try? AttributedString(
            markdown: body,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .full,
                failurePolicy: .partiallyParsedIfPossible
            )
        )
        let text = (converted.map { String($0.characters) }) ?? MarkdownService.plain(body)
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")

        return """
        <!DOCTYPE html>
        <html lang="it">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(note.displayTitle)</title>
        <style>
          body { font-family: -apple-system, "SF Pro Text", sans-serif; background:#FDF7EC; color:#33261A;
                 max-width: 46rem; margin: 3rem auto; padding: 0 1.5rem; line-height: 1.65; }
          h1 { color:#C1613B; border-bottom: 2px solid #E7D3B4; padding-bottom:.4rem; }
          h2 { color:#7A4A2B; } h3 { color:#7E7A45; }
          em { color:#9C8874; }
          pre { background:#FFFDF8; border:1px solid #E6D7BE; padding:.8rem; border-radius:.6rem; overflow-x:auto; }
          footer { margin-top:3rem; color:#9C8874; font-size:.85rem; }
        </style>
        </head>
        <body>
        \(escaped)
        <footer>Esportato da Marcus's Note</footer>
        </body>
        </html>
        """
    }

    static func pdf(from note: Note, scheme: ColorScheme = .light) throws -> URL {
        let pageSize = CGSize(width: 595.2, height: 841.8)
        let margin: CGFloat = 56
        let contentWidth = pageSize.width - margin * 2
        let bottomLimit = pageSize.height - margin - 24
        let url = FileStore.exports.appendingPathComponent(
            "\(FileStore.safeFileName(note.displayTitle)).pdf"
        )

        let isDark = scheme == .dark
        let background = isDark ? UIColor(AutumnTheme.nightBg) : UIColor(AutumnTheme.ivory)
        let titleColor = isDark ? UIColor(AutumnTheme.amber) : UIColor(AutumnTheme.rust)
        let ruleColor = isDark ? UIColor(AutumnTheme.nightBorder) : UIColor(AutumnTheme.sand)

        let attributed = MarkdownService.nsAttributed(note.content, fontSize: 13, scheme: scheme)

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        try renderer.writePDF(to: url) { context in
            let cgContext = context.cgContext
            var pageNumber = 0
            var cursor = 0

            func drawHeader() {
                background.setFill()
                cgContext.fill(CGRect(origin: .zero, size: pageSize))

                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 21, weight: .semibold),
                    .foregroundColor: titleColor
                ]
                let titleRect = CGRect(x: margin, y: margin, width: contentWidth, height: 60)
                let titleHeight = (note.displayTitle as NSString).boundingRect(
                    with: titleRect.size,
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: titleAttrs,
                    context: nil
                ).height
                (note.displayTitle as NSString).draw(
                    with: CGRect(x: margin, y: margin, width: contentWidth, height: titleHeight),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: titleAttrs,
                    context: nil
                )

                let metaAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9.5),
                    .foregroundColor: UIColor(AutumnTheme.inkFaint)
                ]
                let meta = "Marcus's Note · \(AppDate.italian.string(from: note.modifiedAt)) · \(note.computedWordCount) parole"
                let metaY = margin + titleHeight + 6
                (meta as NSString).draw(
                    with: CGRect(x: margin, y: metaY, width: contentWidth, height: 14),
                    options: [.usesLineFragmentOrigin],
                    attributes: metaAttrs,
                    context: nil
                )

                let rule = UIBezierPath()
                rule.move(to: CGPoint(x: margin, y: metaY + 20))
                rule.addLine(to: CGPoint(x: pageSize.width - margin, y: metaY + 20))
                ruleColor.setStroke()
                rule.lineWidth = 1
                rule.stroke()

                let footer = "\(pageNumber)"
                let footerAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9),
                    .foregroundColor: UIColor(AutumnTheme.inkFaint)
                ]
                let footerSize = (footer as NSString).size(withAttributes: footerAttrs)
                (footer as NSString).draw(
                    at: CGPoint(x: pageSize.width - margin - footerSize.width, y: pageSize.height - margin + 14),
                    withAttributes: footerAttrs
                )
            }

            let textTopOffset: CGFloat = 132
            let framesetter = CTFramesetterCreateWithAttributedString(attributed)
            let total = attributed.length
            var guardCounter = 0

            while cursor < total && guardCounter < 400 {
                guardCounter += 1
                pageNumber += 1
                drawHeader()

                let textRect = CGRect(
                    x: margin,
                    y: margin + textTopOffset,
                    width: contentWidth,
                    height: bottomLimit - (margin + textTopOffset)
                )
                let path = CGPath(rect: textRect, transform: nil)
                let frame = CTFramesetterCreateFrame(
                    framesetter,
                    CFRange(location: cursor, length: 0),
                    path,
                    nil
                )
                CTFrameDraw(frame, cgContext)

                let visible = CTFrameGetVisibleStringRange(frame)
                if visible.length <= 0 { break }
                cursor += visible.length
            }

            if total == 0 {
                pageNumber += 1
                drawHeader()
                let emptyAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.italicSystemFont(ofSize: 13),
                    .foregroundColor: UIColor(AutumnTheme.inkFaint)
                ]
                ("_Nota vuota_").draw(
                    with: CGRect(x: margin, y: margin + textTopOffset, width: contentWidth, height: 30),
                    options: [.usesLineFragmentOrigin],
                    attributes: emptyAttrs,
                    context: nil
                )
            }
        }

        return url
    }

    @discardableResult
    static func export(_ note: Note, as format: ExportFormat) throws -> URL {
        let base = FileStore.safeFileName(note.displayTitle)
        switch format {
        case .markdown:
            let url = FileStore.exports.appendingPathComponent("\(base).md")
            try markdown(from: note).write(to: url, atomically: true, encoding: .utf8)
            return url
        case .html:
            let url = FileStore.exports.appendingPathComponent("\(base).html")
            try html(from: note).write(to: url, atomically: true, encoding: .utf8)
            return url
        case .pdf:
            return try pdf(from: note)
        }
    }
}