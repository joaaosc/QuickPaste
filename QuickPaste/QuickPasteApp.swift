//
//  QuickPasteApp.swift
//  QuickPaste
//
//  Created by João Pedro Torres on 16/05/26.
//

import SwiftUI

@main
struct QuickPasteApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environmentObject(appState)
        } label: {
            Image(systemName: "text.cursor")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
