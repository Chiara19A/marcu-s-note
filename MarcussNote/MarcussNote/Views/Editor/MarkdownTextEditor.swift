import SwiftUI
import UIKit

struct MarkdownTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var cursorOffset: Int
    var fontSize: CGFloat = 17
    var monospaced: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.isScrollEnabled = true
        view.alwaysBounceVertical = true
        view.textContainerInset = UIEdgeInsets(top: 16, left: 20, bottom: 22, right: 20)
        view.textContainer.lineFragmentPadding = 0
        view.adjustsFontForContentSizeCategory = true
        view.autocorrectionType = .no
        view.autocapitalizationType = .sentences
        view.smartDashesType = .no
        view.smartQuotesType = .no
        view.smartInsertDeleteType = .no
        view.spellCheckingType = .no
        view.keyboardDismissMode = .interactive
        view.font = makeFont()
        view.text = text
        view.tintColor = UIColor(AutumnTheme.rust)
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if view.text != text {
            let selection = view.selectedRange
            view.text = text
            let clamped = max(0, min(selection.location, (text as NSString).length))
            view.selectedRange = NSRange(location: clamped, length: 0)
        }
        if view.font != makeFont() {
            view.font = makeFont()
        }
    }

    private func makeFont() -> UIFont {
        if monospaced {
            UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        } else {
            UIFont.systemFont(ofSize: fontSize, weight: .regular)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkdownTextEditor

        init(_ parent: MarkdownTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.cursorOffset = textView.selectedRange.location
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.cursorOffset = textView.selectedRange.location
        }
    }
}