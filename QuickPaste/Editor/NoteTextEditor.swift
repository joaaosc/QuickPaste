import AppKit
import SwiftUI

/// AppKit-backed rich-text editor.
///
/// We use `NSTextView` (not SwiftUI's `TextEditor`) for two reasons SwiftUI can't express
/// here: intercepting ⌘V to insert a clipboard **image inline in the text body**, and
/// honoring the "allow multiple images" preference. Content is an `NSAttributedString`;
/// the model derives plain text from it for translation/counting.
struct NoteTextEditor: NSViewRepresentable {
    var attributedText: NSAttributedString
    var fontSize: CGFloat
    var allowMultipleImages: Bool
    /// Bumped by the parent to request first-responder focus (initial, on key, after clear).
    var focusToken: Int
    var onChange: (NSAttributedString) -> Void
    /// Called after a clipboard image is inserted, so the model can run OCR.
    var onImagePasted: (NSImage) -> Void
    /// Whether the right-click "Reconhecer texto (OCR)" item is offered.
    var ocrEnabled: Bool
    /// Right-click OCR on an existing image.
    var onRecognizeImage: (NSImage) -> Void
    /// Integration point for the separate LaTeX module (nil keeps the menu item disabled).
    var onConvertToLaTeX: ((NSImage) -> Void)? = nil

    func makeNSView(context: Context) -> NSScrollView {
        let textView = ClipboardTextView()
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.importsGraphics = false        // we insert pasted images ourselves
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.allowMultipleImages = allowMultipleImages
        textView.onImagePasted = onImagePasted
        textView.ocrMenuEnabled = ocrEnabled
        textView.onRecognizeImage = onRecognizeImage
        textView.onConvertImageToLaTeX = onConvertToLaTeX
        textView.typingAttributes[.font] = NSFont.systemFont(ofSize: fontSize)
        textView.textStorage?.setAttributedString(attributedText)
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
        textView.allowMultipleImages = allowMultipleImages
        textView.onImagePasted = onImagePasted
        textView.ocrMenuEnabled = ocrEnabled
        textView.onRecognizeImage = onRecognizeImage
        textView.onConvertImageToLaTeX = onConvertToLaTeX
        let desiredFont = NSFont.systemFont(ofSize: fontSize)

        // External content change (clear / adopt translation / appended OCR text) → push in,
        // normalize the font across it, and sync the normalized value back to the model so the
        // next pass sees them as equal (no re-push loop).
        if !textView.attributedString().isEqual(to: attributedText) {
            let selected = textView.selectedRange()
            textView.textStorage?.setAttributedString(attributedText)
            if let storage = textView.textStorage, storage.length > 0 {
                storage.addAttribute(.font, value: desiredFont, range: NSRange(location: 0, length: storage.length))
            }
            textView.typingAttributes[.font] = desiredFont
            let length = (textView.string as NSString).length
            textView.setSelectedRange(NSRange(location: min(selected.location, length), length: 0))

            let snapshot = textView.attributedString()
            if !snapshot.isEqual(to: attributedText) {
                DispatchQueue.main.async { onChange(snapshot) }
            }
        }

        // Font-size change → reformat existing text uniformly and sync the model.
        if context.coordinator.lastFontSize != fontSize {
            context.coordinator.lastFontSize = fontSize
            textView.typingAttributes[.font] = desiredFont
            if let storage = textView.textStorage, storage.length > 0 {
                storage.addAttribute(.font, value: desiredFont, range: NSRange(location: 0, length: storage.length))
                let snapshot = textView.attributedString()
                DispatchQueue.main.async { onChange(snapshot) }
            }
        }

        if focusToken != context.coordinator.lastFocusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private let parent: NoteTextEditor
        var lastFocusToken = -1
        var lastFontSize: CGFloat = -1

        init(_ parent: NoteTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.onChange(textView.attributedString())
        }
    }
}

/// `NSTextView` that inserts a clipboard image inline (as a text attachment) on ⌘V when
/// the pasteboard holds an image and no text. Honors single- vs multi-image preference.
final class ClipboardTextView: NSTextView {
    var allowMultipleImages = false
    var onImagePasted: ((NSImage) -> Void)?

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        let hasText = pasteboard.canReadObject(forClasses: [NSString.self], options: nil)

        if !hasText,
           let image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage {
            insertImage(image)
            return
        }

        super.paste(sender)
    }

    private func insertImage(_ image: NSImage) {
        if !allowMultipleImages {
            removeAllImageAttachments()
        }

        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = scaledBounds(for: image)

        let attributed = NSAttributedString(attachment: attachment)
        let range = selectedRange()
        guard shouldChangeText(in: range, replacementString: nil) else { return }
        textStorage?.replaceCharacters(in: range, with: attributed)
        didChangeText()
        setSelectedRange(NSRange(location: range.location + attributed.length, length: 0))
        onImagePasted?(image)
    }

    private func removeAllImageAttachments() {
        guard let storage = textStorage, storage.length > 0 else { return }
        var ranges: [NSRange] = []
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            if value != nil { ranges.append(range) }
        }
        for range in ranges.reversed() where shouldChangeText(in: range, replacementString: "") {
            storage.replaceCharacters(in: range, with: "")
            didChangeText()
        }
    }

    /// Fit a pasted image to the editor width, preserving aspect ratio.
    private func scaledBounds(for image: NSImage) -> CGRect {
        let inset = textContainerInset.width * 2 + (textContainer?.lineFragmentPadding ?? 0) * 2
        let available = (textContainer?.size.width ?? bounds.width) - inset
        let maxWidth = max(80, min(available, 420))
        let size = image.size

        guard size.width > 0, size.height > 0 else {
            return CGRect(x: 0, y: 0, width: maxWidth, height: maxWidth)
        }
        guard size.width > maxWidth else {
            return CGRect(origin: .zero, size: size)
        }
        let scale = maxWidth / size.width
        return CGRect(x: 0, y: 0, width: maxWidth, height: (size.height * scale).rounded())
    }

    // MARK: Right-click on an image

    /// Only offer OCR in the menu when the feature is on.
    var ocrMenuEnabled = false
    var onRecognizeImage: ((NSImage) -> Void)?
    /// Integration point for the separate LaTeX/Core AI module. Nil until that module is added,
    /// which keeps the menu item present but disabled ("em breve").
    var onConvertImageToLaTeX: ((NSImage) -> Void)?

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let image = image(atContextMenuEvent: event) else {
            return super.menu(for: event)
        }

        let menu = NSMenu()

        if ocrMenuEnabled {
            let ocr = NSMenuItem(title: "Reconhecer texto (OCR)", action: #selector(recognizeImageText(_:)), keyEquivalent: "")
            ocr.target = self
            ocr.representedObject = image
            menu.addItem(ocr)
        }

        let latexTitle = onConvertImageToLaTeX == nil
            ? "Converter fórmula para LaTeX (.tex) — em breve"
            : "Converter fórmula para LaTeX (.tex)…"
        let latex = NSMenuItem(
            title: latexTitle,
            action: onConvertImageToLaTeX == nil ? nil : #selector(convertImageToLaTeX(_:)),
            keyEquivalent: ""
        )
        latex.target = self
        latex.representedObject = image
        menu.addItem(latex)   // disabled while the action is nil (separate module not installed)

        return menu.items.isEmpty ? super.menu(for: event) : menu
    }

    @objc private func recognizeImageText(_ sender: NSMenuItem) {
        if let image = sender.representedObject as? NSImage { onRecognizeImage?(image) }
    }

    @objc private func convertImageToLaTeX(_ sender: NSMenuItem) {
        if let image = sender.representedObject as? NSImage { onConvertImageToLaTeX?(image) }
    }

    private func image(atContextMenuEvent event: NSEvent) -> NSImage? {
        guard let storage = textStorage, storage.length > 0 else { return nil }
        let point = convert(event.locationInWindow, from: nil)
        let index = characterIndexForInsertion(at: point)
        for i in [index, index - 1] where i >= 0 && i < storage.length {
            if let attachment = storage.attribute(.attachment, at: i, effectiveRange: nil) as? NSTextAttachment {
                return image(from: attachment)
            }
        }
        return nil
    }

    private func image(from attachment: NSTextAttachment) -> NSImage? {
        if let image = attachment.image { return image }
        if let data = attachment.fileWrapper?.regularFileContents, let image = NSImage(data: data) {
            return image
        }
        return nil
    }
}
