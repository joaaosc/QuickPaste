//
//  QuickPasteApp.swift
//  QuickPaste
//
//  Created by João Pedro Torres on 16/05/26.
//

import SwiftUI

@main
struct QuickPasteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsContent()
        }
    }
}
