//
//  SettingsContent.swift
//  QuickPaste
//
//  Created by João Pedro Torres on 17/05/26.
//

import Foundation

import SwiftUI

struct SettingsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Configurações")
                .font(.title2)
                .bold()

            Text("Aqui ficarão as opções do aplicativo.")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .frame(minWidth: 320, minHeight: 200)
    }
}
