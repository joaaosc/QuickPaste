//
//  TextInserter.swift
//  QuickPaste
//
//  Created by João Pedro Torres on 16/05/26.
//

import AppKit

enum TextInserter {
    static func insert(_ text: String) {
        let pasteboard = NSPasteboard.general

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .hidSystemState)

        let commandDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: 0x37,
            keyDown: true
        )

        let vDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: 0x09,
            keyDown: true
        )

        let vUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: 0x09,
            keyDown: false
        )

        let commandUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: 0x37,
            keyDown: false
        )

        commandDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        commandUp?.flags = []

        commandDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        commandUp?.post(tap: .cghidEventTap)
    }
}
