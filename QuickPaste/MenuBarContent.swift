//
//  MenuBarContent.swift
//  QuickPaste
//
//  Created by João Pedro Torres on 16/05/26.
//

import SwiftUI

struct MenuBarContent: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QuickPaste")
                .font(.headline)

            TextField("Texto", text: $appState.defaultText)
                .textFieldStyle(.roundedBorder)

            Button("Inserir texto") {
                TextInserter.insert(appState.defaultText)
            }

            Divider()

            Button("Configurações") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }

            Button("Sair") {
                NSApp.terminate(nil)
            }
        }
        .padding()
        .frame(width: 280)
    }
}
