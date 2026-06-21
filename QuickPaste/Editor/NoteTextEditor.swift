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
    /// Whether the right-click "Converter fórmula para LaTeX" item is offered (Core AI available).
    var latexMenuEnabled: Bool
    /// Right-click formula→LaTeX on an existing image.
    var onConvertFormula: (NSImage) -> Void

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
        textView.latexMenuEnabled = latexMenuEnabled
        textView.onConvertFormula = onConvertFormula
        // Dynamic, appearance-aware colors so the note stays legible in dark mode.
        textView.textColor = .textColor
        textView.insertionPointColor = .textColor
        textView.typingAttributes[.font] = NSFont.systemFont(ofSize: fontSize)
        textView.typingAttributes[.foregroundColor] = NSColor.textColor
        textView.textStorage?.setAttributedString(attributedText)
        Self.normalizeAppearance(of: textView, font: NSFont.systemFont(ofSize: fontSize))
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
        textView.latexMenuEnabled = latexMenuEnabled
        textView.onConvertFormula = onConvertFormula
        let desiredFont = NSFont.systemFont(ofSize: fontSize)

        // External content change (clear / adopt translation / appended OCR text) → push in,
        // normalize the font across it, and sync the normalized value back to the model so the
        // next pass sees them as equal (no re-push loop).
        if !textView.attributedString().isEqual(to: attributedText) {
            let selected = textView.selectedRange()
            textView.textStorage?.setAttributedString(attributedText)
            Self.normalizeAppearance(of: textView, font: desiredFont)
            textView.typingAttributes[.font] = desiredFont
            textView.typingAttributes[.foregroundColor] = NSColor.textColor
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
                Self.normalizeAppearance(of: textView, font: desiredFont)
                let snapshot = textView.attributedString()
                DispatchQueue.main.async { onChange(snapshot) }
            }
        }

        if focusToken != context.coordinator.lastFocusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
        }
    }

    /// Force the note's font and a dynamic, appearance-aware text color across the whole
    /// storage. RTFD round-trips can bake in a static color (black) that is unreadable in
    /// dark mode; pinning `.textColor` keeps the note legible in both appearances. Paragraph
    /// styles (e.g. a pasted image's centered block) are deliberately left untouched.
    private static func normalizeAppearance(of textView: NSTextView, font: NSFont) {
        guard let storage = textView.textStorage, storage.length > 0 else { return }
        let whole = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.addAttribute(.font, value: font, range: whole)
        storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: whole)
        storage.endEditing()
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
        attachment.bounds = displayBounds(for: image)

        // Lay the image out as a centered block with breathing room, on its own line, so it
        // reads as a deliberate element instead of a tiny glyph crammed into the text.
        let block = NSMutableParagraphStyle()
        block.alignment = .center
        block.paragraphSpacing = 6
        block.paragraphSpacingBefore = 6

        let imagePiece = NSMutableAttributedString(attachment: attachment)
        imagePiece.append(NSAttributedString(string: "\n"))
        imagePiece.addAttributes(
            [.paragraphStyle: block, .foregroundColor: NSColor.textColor],
            range: NSRange(location: 0, length: imagePiece.length)
        )

        let insertion = NSMutableAttributedString()
        let range = selectedRange()
        if needsLeadingNewline(before: range.location) {
            insertion.append(plainNewline())
        }
        insertion.append(imagePiece)

        guard shouldChangeText(in: range, replacementString: nil) else { return }
        textStorage?.replaceCharacters(in: range, with: insertion)
        didChangeText()

        // Caret lands on a fresh, left-aligned line below the image.
        setSelectedRange(NSRange(location: range.location + insertion.length, length: 0))
        typingAttributes[.paragraphStyle] = NSParagraphStyle.default
        typingAttributes[.foregroundColor] = NSColor.textColor
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
        // Collapse leftover blank lines from a previous single-image paste so re-pasting
        // doesn't accumulate empty paragraphs.
        if storage.length > 0,
           storage.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let whole = NSRange(location: 0, length: storage.length)
            if shouldChangeText(in: whole, replacementString: "") {
                storage.replaceCharacters(in: whole, with: "")
                didChangeText()
            }
        }
    }

    /// A newline carrying default (left-aligned) attributes, so it doesn't inherit the
    /// image block's centered paragraph style.
    private func plainNewline() -> NSAttributedString {
        NSAttributedString(string: "\n", attributes: [
            .font: typingAttributes[.font] ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: NSParagraphStyle.default,
        ])
    }

    /// True when an image should be pushed onto its own line (caret isn't already at the
    /// start of a line).
    private func needsLeadingNewline(before location: Int) -> Bool {
        guard location > 0, let storage = textStorage, location <= storage.length else { return false }
        return (storage.string as NSString).substring(with: NSRange(location: location - 1, length: 1)) != "\n"
    }

    /// Size a pasted image to fill the editor's column, preserving aspect ratio. Large images
    /// scale down to the column; small ones scale up only modestly (≤2×) to stay crisp.
    private func displayBounds(for image: NSImage) -> CGRect {
        let content = availableContentWidth()
        let size = image.size

        guard size.width > 0, size.height > 0 else {
            let side = min(content, 240)
            return CGRect(x: 0, y: 0, width: side, height: side)
        }

        let width = size.width >= content ? content : min(content, size.width * 2)
        let height = (size.height * (width / size.width)).rounded()
        return CGRect(x: 0, y: 0, width: width.rounded(), height: height)
    }

    /// The text column's usable width, excluding container insets and line padding.
    private func availableContentWidth() -> CGFloat {
        let inset = textContainerInset.width * 2 + (textContainer?.lineFragmentPadding ?? 0) * 2
        let width = (textContainer?.size.width ?? bounds.width) - inset
        return max(width, 120)
    }

    // MARK: Right-click on an image

    /// Only offer OCR in the menu when the feature is on.
    var ocrMenuEnabled = false
    var onRecognizeImage: ((NSImage) -> Void)?
    /// Only offer formula→LaTeX when Core AI is available and the feature is on.
    var latexMenuEnabled = false
    var onConvertFormula: ((NSImage) -> Void)?

    /// Right-clicking an inline image yields a focused, image-specific menu: recognition actions
    /// first, then image actions, then the native NSTextView items. Items carry SF Symbols so the
    /// menu reads across languages. Built only on an image hit-test.
    override func menu(for event: NSEvent) -> NSMenu? {
        guard let image = image(atContextMenuEvent: event) else {
            return super.menu(for: event)
        }
        let menu = super.menu(for: event) ?? NSMenu()

        var actions: [NSMenuItem] = []
        if ocrMenuEnabled {
            actions.append(imageActionItem(
                title: "Reconhecer texto (OCR)", symbol: "text.viewfinder",
                action: #selector(recognizeImageText(_:)), image: image
            ))
        }
        if latexMenuEnabled {
            actions.append(imageActionItem(
                title: "Converter fórmula para LaTeX", symbol: "function",
                action: #selector(convertFormulaToLatex(_:)), image: image
            ))
        }
        if actions.isEmpty == false { actions.append(.separator()) }
        actions.append(imageActionItem(
            title: "Copiar imagem", symbol: "doc.on.doc",
            action: #selector(copyImage(_:)), image: image
        ))
        // "Open in Preview": a universal SF Symbol instead of a localized label (per design). A
        // tooltip + the symbol's accessibility description aid discovery and VoiceOver.
        actions.append(imageActionItem(
            title: "", symbol: "eye",
            symbolDescription: "Abrir imagem no app Pré-Visualização",
            action: #selector(openImageInPreview(_:)), image: image
        ))

        if menu.items.isEmpty {
            for item in actions { menu.addItem(item) }
        } else {
            for (offset, item) in actions.enumerated() { menu.insertItem(item, at: offset) }
            menu.insertItem(.separator(), at: actions.count)
        }
        return menu
    }

    /// An image-context menu item targeting this view, tagged with the image and an SF Symbol.
    private func imageActionItem(
        title: String,
        symbol: String,
        symbolDescription: String? = nil,
        action: Selector,
        image: NSImage
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = image
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: symbolDescription ?? title)
        if title.isEmpty, let symbolDescription { item.toolTip = symbolDescription }
        return item
    }

    @objc private func recognizeImageText(_ sender: NSMenuItem) {
        if let image = sender.representedObject as? NSImage { onRecognizeImage?(image) }
    }

    @objc private func convertFormulaToLatex(_ sender: NSMenuItem) {
        if let image = sender.representedObject as? NSImage { onConvertFormula?(image) }
    }

    /// Copy the raw image to the clipboard so it pastes as an image into other apps. Pure AppKit glue.
    @objc private func copyImage(_ sender: NSMenuItem) {
        guard let image = sender.representedObject as? NSImage else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    /// Open the image in the system viewer (Preview). Writes a temp PNG inside the app's container
    /// and hands it to NSWorkspace; edits there are not re-imported (by design).
    @objc private func openImageInPreview(_ sender: NSMenuItem) {
        guard let image = sender.representedObject as? NSImage, let data = image.pngData() else {
            NSSound.beep()
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuickPaste-\(UUID().uuidString).png")
        do {
            try data.write(to: url)
            NSWorkspace.shared.open(url)
        } catch {
            NSSound.beep()
        }
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

private extension NSImage {
    /// PNG encoding, for handing the image to another app (e.g. Preview).
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
