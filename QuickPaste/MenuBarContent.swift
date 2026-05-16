//
//  MenuBarContent.swift
//  QuickPaste
//
//  Created by João Pedro Torres on 16/05/26.
//
import SwiftUI

struct MenuBarContent: View {
    @State private var text: String = ""

    var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .padding(8)
            .frame(width: 320, height: 180)
    }
}
