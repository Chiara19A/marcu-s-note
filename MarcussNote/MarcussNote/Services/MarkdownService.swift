import Foundation
import SwiftUI
import UIKit

enum MarkdownService {

    // MARK: - Versione testo semplice

    static func plain(_ markdown: String) -> String {
        markdown
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "^#{1,6}\\s*", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "\\*(.+?)\\*", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "`(.+?)`", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "^>\\s*", with: "", options: .regularExpression)
            .replacingOccurrences(of: "^\\s*[-*+]\\s+", with: "• ", options: .regularExpression)
            .replacingOccurrences(of: "^\\s*\\[ \\]\\s*", with: "☐ ", options: .regularExpression)
            .replacingOccurrences(of: "^\\s*\\[x\\]\\s*", with: "☑ ", options: .regularExpression)
    }

    static func plainText(_ markdown: String) -> String { plain(markdown) }

    // MARK: - Palette

    struct Palette {
        var text: UIColor
        var faint: UIColor
        var heading1: UIColor
        var heading2: UIColor
        var heading3: UIColor
        var quote: UIColor
        var code: UIColor
        var rule: UIColor
        var bullet: UIColor
        var codeBackground: UIColor
    }

    static func palette(for scheme: ColorScheme) -> Palette {
        if scheme == .dark {
            return Palette(
                text: UIColor(AutumnTheme.beige),
                faint: UIColor(AutumnTheme.inkFaint),
                heading1: UIColor(AutumnTheme.amber),
                heading2: UIColor(AutumnTheme.pumpkin),
                heading3: UIColor(AutumnTheme.clay),
                quote: UIColor(AutumnTheme.olive),
                code: UIColor(AutumnTheme.sand),
                rule: UIColor(AutumnTheme.nightBorder),
                bullet: UIColor(AutumnTheme.rust),
                codeBackground: UIColor(AutumnTheme.nightSurfaceHi)
            )
        }
        return Palette(
            text: UIColor(AutumnTheme.ink),
            faint: UIColor(AutumnTheme.inkFaint),
            heading1: UIColor(AutumnTheme.rust),
            heading2: UIColor(AutumnTheme.walnut),
            heading3: UIColor(AutumnTheme.olive),
            quote: UIColor(AutumnTheme.oliveDark),
            code: UIColor(AutumnTheme.walnut),
            rule: UIColor(AutumnTheme.sand),
            bullet: UIColor(AutumnTheme.amber),
            codeBackground: UIColor(AutumnTheme.beige)
        )
    }

    // MARK: - Rendering

    static func nsAttributed(_ markdown: String, fontSize: CGFloat, scheme: ColorScheme = .light) -> NSAttributedString {
        render(markdown, fontSize: fontSize, palette: palette(for: scheme))
    }

    static func attributed(_ markdown: String, fontSize: CGFloat, scheme: ColorScheme = .light) -> AttributedString {
        AttributedString(nsAttributed(markdown, fontSize: fontSize, scheme: scheme))
    }

    static func render(_ markdown: String, fontSize: CGFloat, palette: Palette) -> NSAttributedString {
        let output = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: .newlines)

        var inCodeBlock = false
        var codeBuffer: [String] = []
        var inLatex = false
        var latexBuffer: [String] = []
        var firstLine = true

        func paragraph(_ spacingBefore: CGFloat, _ spacingAfter: CGFloat) -> NSParagraphStyle {
            let style = NSMutableParagraphStyle()
            style.lineSpacing = fontSize * 0.34
            style.paragraphSpacing = spacingAfter
            style.paragraphSpacingBefore = spacingBefore
            return style
        }

        func appendLine(_ text: String, attributes: [NSAttributedString.Key: Any], paragraph: NSParagraphStyle) {
            let attributed = NSMutableAttributedString(string: text, attributes: attributes)
            attributed.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: attributed.length))
            output.append(attributed)
        }

        for rawLine in lines {
            let line = rawLine
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Blocchi di codice
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    inCodeBlock = false
                    output.append(appendCodeBlock(codeBuffer.joined(separator: "\n"), fontSize: fontSize, palette: palette))
                    codeBuffer.removeAll()
                } else {
                    inCodeBlock = true
                }
                continue
            }
            if inCodeBlock {
                codeBuffer.append(line)
                continue
            }

            // Blocchi LaTeX
            if trimmed.hasPrefix("$$") {
                var body = String(trimmed.dropFirst(2))
                if body.hasSuffix("$$") {
                    body = String(body.dropLast(2))
                    latexBuffer.append(body)
                    output.append(appendLatexBlock(latexBuffer.joined(separator: " "), fontSize: fontSize, palette: palette))
                    latexBuffer.removeAll()
                    inLatex = false
                } else {
                    inLatex = true
                    latexBuffer.append(body)
                }
                continue
            }
            if inLatex {
                latexBuffer.append(trimmed)
                if trimmed.hasSuffix("$$") {
                    var body = latexBuffer.joined(separator: " ")
                    body = body.replacingOccurrences(of: "$$", with: "")
                    output.append(appendLatexBlock(body, fontSize: fontSize, palette: palette))
                    latexBuffer.removeAll()
                    inLatex = false
                }
                continue
            }

            if !firstLine {
                appendLine("", attributes: [
                    .font: UIFont.systemFont(ofSize: fontSize * 0.4)
                ], paragraph: paragraph(0, 0))
            }
            firstLine = false

            if trimmed.isEmpty { continue }

            // Regola orizzontale
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                let rule = NSMutableAttributedString(string: String(repeating: "─", count: 46) + "\n", attributes: [
                    .font: UIFont.systemFont(ofSize: fontSize * 0.7),
                    .foregroundColor: palette.rule
                ])
                output.append(rule)
                continue
            }

            // Titoli
            if trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix { $0 == "#" }.count
                let content = String(trimmed.dropFirst(hashes)).trimmingCharacters(in: .whitespaces)
                let size: CGFloat = fontSize + CGFloat(5 - min(hashes, 5)) * fontSize * 0.13
                let color: UIColor
                switch min(hashes, 3) {
                case 1: color = palette.heading1
                case 2: color = palette.heading2
                default: color = palette.heading3
                }
                let font = UIFont.systemFont(ofSize: size, weight: hashes <= 2 ? .bold : .semibold)
                let attributed = inline(
                    content,
                    font: font,
                    color: color,
                    codeColor: palette.code,
                    codeBackground: palette.codeBackground,
                    fontSize: fontSize,
                    palette: palette
                )
                attributed.addAttribute(
                    .paragraphStyle,
                    value: paragraph(fontSize * 0.6, fontSize * 0.34),
                    range: NSRange(location: 0, length: attributed.length)
                )
                output.append(attributed)
                continue
            }

            // Citazioni
            if trimmed.hasPrefix(">") {
                let content = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                let attributed = inline(
                    content,
                    font: UIFont.italicSystemFont(ofSize: fontSize),
                    color: palette.quote,
                    codeColor: palette.code,
                    codeBackground: palette.codeBackground,
                    fontSize: fontSize,
                    palette: palette
                )
                attributed.addAttribute(
                    .paragraphStyle,
                    value: paragraph(0, fontSize * 0.4),
                    range: NSRange(location: 0, length: attributed.length)
                )
                output.append(attributed)
                continue
            }

            // Checkbox
            if let match = trimmed.range(of: "^[-*+]\\s+\\[([ xX])\\]\\s*", options: .regularExpression) {
                let symbol = String(trimmed[match]).contains("x") || String(trimmed[match]).contains("X") ? "☑" : "☐"
                let indent = String(repeating: "  ", count: max(0, line.prefix { $0 == " " }.count / 2))
                let rest = String(trimmed[match.upperBound...])
                let attributed = NSMutableAttributedString(
                    string: "\(indent)\(symbol)  ",
                    attributes: [
                        .font: UIFont.systemFont(ofSize: fontSize * 0.95),
                        .foregroundColor: palette.bullet
                    ]
                )
                attributed.append(inline(
                    rest,
                    font: UIFont.systemFont(ofSize: fontSize),
                    color: palette.text,
                    codeColor: palette.code,
                    codeBackground: palette.codeBackground,
                    fontSize: fontSize,
                    palette: palette
                ))
                attributed.addAttribute(
                    .paragraphStyle,
                    value: paragraph(0, fontSize * 0.22),
                    range: NSRange(location: 0, length: attributed.length)
                )
                output.append(attributed)
                continue
            }

            // Elenchi
            if let match = trimmed.range(of: "^([-*+]|\\d+\\.)\\s+", options: .regularExpression) {
                let marker = String(trimmed[match]).trimmingCharacters(in: .whitespaces)
                let bullet = marker.hasSuffix(".") ? marker : "•"
                let depth = line.prefix { $0 == " " }.count
                let indent = String(repeating: "  ", count: max(0, depth / 2 + 1))
                let rest = String(trimmed[match.upperBound...])
                let attributed = NSMutableAttributedString(
                    string: "\(indent)\(bullet)  ",
                    attributes: [
                        .font: UIFont.systemFont(ofSize: fontSize * 0.95),
                        .foregroundColor: palette.bullet
                    ]
                )
                attributed.append(inline(
                    rest,
                    font: UIFont.systemFont(ofSize: fontSize),
                    color: palette.text,
                    codeColor: palette.code,
                    codeBackground: palette.codeBackground,
                    fontSize: fontSize,
                    palette: palette
                ))
                attributed.addAttribute(
                    .paragraphStyle,
                    value: paragraph(0, fontSize * 0.26),
                    range: NSRange(location: 0, length: attributed.length)
                )
                output.append(attributed)
                continue
            }

            // Paragrafo normale
            let attributed = inline(
                line,
                font: UIFont.systemFont(ofSize: fontSize),
                color: palette.text,
                codeColor: palette.code,
                codeBackground: palette.codeBackground,
                fontSize: fontSize,
                palette: palette
            )
            attributed.addAttribute(
                .paragraphStyle,
                value: paragraph(0, fontSize * 0.42),
                range: NSRange(location: 0, length: attributed.length)
            )
            output.append(attributed)
        }

        if !codeBuffer.isEmpty {
            output.append(appendCodeBlock(codeBuffer.joined(separator: "\n"), fontSize: fontSize, palette: palette))
        }

        return output
    }

    // MARK: - Blocchi speciali

    private static func appendCodeBlock(
        _ code: String,
        fontSize: CGFloat,
        palette: Palette
    ) -> NSMutableAttributedString {
        let monospaced = UIFont.monospacedSystemFont(ofSize: fontSize * 0.88, weight: .regular)
        let style = NSMutableParagraphStyle()
        style.lineSpacing = fontSize * 0.28
        style.paragraphSpacing = fontSize * 0.5
        style.headIndent = fontSize
        style.firstLineHeadIndent = fontSize

        let result = NSMutableAttributedString(
            string: "\u{250C}\u{2500}\u{2500} codice \u{2500}\u{2500}\u{2510}\n",
            attributes: [
                .font: UIFont.systemFont(ofSize: fontSize * 0.62, weight: .semibold),
                .foregroundColor: palette.faint,
                .paragraphStyle: style
            ]
        )
        result.append(NSMutableAttributedString(
            string: code + "\n",
            attributes: [
                .font: monospaced,
                .foregroundColor: palette.code,
                .backgroundColor: palette.codeBackground,
                .paragraphStyle: style
            ]
        ))
        result.append(NSMutableAttributedString(
            string: "\u{2514}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2518}\n",
            attributes: [
                .font: UIFont.systemFont(ofSize: fontSize * 0.62, weight: .semibold),
                .foregroundColor: palette.faint
            ]
        ))
        return result
    }

    private static func appendLatexBlock(
        _ body: String,
        fontSize: CGFloat,
        palette: Palette
    ) -> NSMutableAttributedString {
        let monospaced = UIFont.monospacedSystemFont(ofSize: fontSize * 0.94, weight: .medium)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = fontSize * 0.3
        style.paragraphSpacingBefore = fontSize * 0.5
        style.paragraphSpacing = fontSize * 0.5

        let result = NSMutableAttributedString(
            string: body + "\n",
            attributes: [
                .font: monospaced,
                .foregroundColor: palette.heading1,
                .backgroundColor: palette.codeBackground,
                .paragraphStyle: style
            ]
        )
        return result
    }

    // MARK: - Inline

    private static func inline(
        _ text: String,
        font: UIFont,
        color: UIColor,
        codeColor: UIColor,
        codeBackground: UIColor,
        fontSize: CGFloat,
        palette: Palette
    ) -> NSMutableAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color
        ])

        apply(#"\*\*(.+?)\*\*"#, to: result, transform: { match, inner in
            NSMutableAttributedString(string: inner, attributes: [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: color
            ])
        }, fontSize: fontSize)

        apply(#"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, to: result, transform: { match, inner in
            NSMutableAttributedString(string: inner, attributes: [
                .font: UIFont.italicSystemFont(ofSize: fontSize),
                .foregroundColor: color
            ])
        }, fontSize: fontSize)

        apply(#"`([^`]+)`"#, to: result, transform: { match, inner in
            NSMutableAttributedString(string: inner, attributes: [
                .font: UIFont.monospacedSystemFont(ofSize: fontSize * 0.9, weight: .regular),
                .foregroundColor: codeColor,
                .backgroundColor: codeBackground
            ])
        }, fontSize: fontSize)

        apply(#"\$([^$\n]+)\$"#, to: result, transform: { match, inner in
            NSMutableAttributedString(string: inner, attributes: [
                .font: UIFont.italicSystemFont(ofSize: fontSize),
                .foregroundColor: palette.heading2
            ])
        }, fontSize: fontSize)

        return result
    }

    private static func apply(
        _ pattern: String,
        to text: NSMutableAttributedString,
        transform: (String, String) -> NSMutableAttributedString,
        fontSize: CGFloat
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        var searchRange = NSRange(location: 0, length: text.length)
        var guardCounter = 0

        while guardCounter < 200 {
            guardCounter += 1
            let matches = regex.matches(in: text.string, options: [], range: searchRange)
            guard let match = matches.first else { break }

            let whole = match.range(at: 0)
            let innerRange = match.numberOfRanges > 1 ? match.range(at: 1) : whole
            guard innerRange.location != NSNotFound,
                  whole.location != NSNotFound,
                  NSMaxRange(whole) <= text.length else { break }

            let inner = (text.string as NSString).substring(with: innerRange)
            let replacement = transform((text.string as NSString).substring(with: whole), inner)
            text.replaceCharacters(in: whole, with: replacement)

            let delta = replacement.length - whole.length
            searchRange = NSRange(location: NSMaxRange(whole), length: max(0, text.length - NSMaxRange(whole)))
            if delta == 0 && matches.count == 1 { break }
        }
    }

    // MARK: - Modifica selezione

    static func heading(forLine line: String) -> String? {
        guard let match = line.range(of: "^#{1,6}\\s+", options: .regularExpression) else { return nil }
        return String(line[match])
    }

    static func applyHeadingPrefix(_ prefix: String, to text: String, cursorOffset: Int) -> (String, Int) {
        let ns = text as NSString
        let safeOffset = max(0, min(cursorOffset, ns.length))
        let lineRange = ns.lineRange(for: NSRange(location: safeOffset, length: 0))
        let original = ns.substring(with: lineRange)
        var line = original

        if let existing = heading(forLine: line) {
            line = String(line.dropFirst(existing.count))
            line = prefix + line
        } else {
            line = prefix + line
        }

        let newText = ns.replacingCharacters(in: lineRange, with: line)
        let delta = line.count - original.count
        return (newText, safeOffset + max(0, delta))
    }

    static func wordRange(in ns: NSString, at offset: Int) -> NSRange {
        let length = ns.length
        let clamped = max(0, min(offset, length))
        let wordChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))

        guard clamped < length,
              let current = ns.character(at: clamped).unicodeScalars.first,
              wordChars.contains(current) else {
            return NSRange(location: clamped, length: 0)
        }

        var start = clamped
        while start > 0,
              let prev = ns.character(at: start - 1).unicodeScalars.first,
              wordChars.contains(prev) {
            start -= 1
        }

        var end = clamped + 1
        while end < length,
              let next = ns.character(at: end).unicodeScalars.first,
              wordChars.contains(next) {
            end += 1
        }

        return NSRange(location: start, length: end - start)
    }

    static func wrapSelection(_ marker: String, in text: String, cursorOffset: Int) -> (String, Int) {
        let ns = text as NSString
        let safeOffset = max(0, min(cursorOffset, ns.length))
        let target = wordRange(in: ns, at: safeOffset)
        let selected = ns.substring(with: target)
        let replacement = marker == "`" ? "`\(selected)`" : "\(marker)\(selected)\(marker)"
        let newText = ns.replacingCharacters(in: target, with: replacement)
        return (newText, target.location + replacement.count)
    }
}

enum AppDate {
    static let italian: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    static let italianShort: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d MMM, HH:mm"
        return f
    }()

    static let fileStamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd_HHmm"
        return f
    }()

    static func relative(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let f = DateFormatter()
            f.locale = Locale(identifier: "it_IT")
            f.dateFormat = "HH:mm"
            return "oggi alle \(f.string(from: date))"
        }
        if calendar.isDateInYesterday(date) { return "ieri" }
        if let days = calendar.dateComponents([.day], from: date, to: Date()).day, days < 7 {
            return "\(days) giorni fa"
        }
        return italian.string(from: date)
    }
}
