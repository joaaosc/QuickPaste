import AppKit
import SwiftUI

/// AppKit-backed plain-text editor.
///
/// We use `NSTextView` instead of SwiftUI's `TextEditor` for one reason: to intercept
/// ⌘V and divert a clipboard **image** to `onPasteImage`, while leaving ordinary text
/// paste untouched. The note content stays a plain `String`.
struct NoteTextEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    /// Bumped by the parent to request first-responder focus (initial, on key, after clear).
    var focusToken: Int
    var onPasteImage: (NSImage) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let textView = ClipboardTextView()
        textView.onPasteImage = onPasteImage
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: fontSize)
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.string = text
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? ClipboardTextView else { return }
        textView.onPasteImage = onPasteImage

        if textView.string != text {
            textView.string = text
        }
        if textView.font?.pointSize != fontSize {
            textView.font = .systemFont(ofSize: fontSize)
        }

        if focusToken != context.coordinator.lastFocusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let parent: NoteTextEditor
        var lastFocusToken = -1

        init(_ parent: NoteTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

/// `NSTextView` that hijacks paste when the pasteboard holds an image (and no text),
/// so screenshots / copied images land in the editor as an attachment instead of
/// being dropped on the floor by a plain-text paste.
final class ClipboardTextView: NSTextView {
    var onPasteImage: ((NSImage) -> Void)?

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        let hasText = pasteboard.canReadObject(forClasses: [NSString.self], options: nil)

        if !hasText,
           let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            onPasteImage?(image)
            return
        }

        super.paste(sender)
    }
}
