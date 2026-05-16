//
//  SettingsView.swift
//  QuickPaste
//
//  Created by João Pedro Torres on 16/05/26.
//
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("Texto") {
                TextField("Texto padrão", text: $appState.defaultText)
            }

            Section("Sobre") {
                Text("QuickPaste")
                Text("App de barra de menu para inserir textos rapidamente.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 420)
    }
}
