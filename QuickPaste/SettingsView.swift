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
            TextField("Texto padrão", text: $appState.defaultText)
        }
        .padding()
        .frame(width: 360)
    }
}
