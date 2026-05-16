//
//  AppState.swift
//  QuickPaste
//
//  Created by João Pedro Torres on 16/05/26.
//

import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var defaultText: String {
        didSet {
            UserDefaults.standard.set(defaultText, forKey: "defaultText")
        }
    }

    init() {
        self.defaultText = UserDefaults.standard.string(forKey: "defaultText")
            ?? "Texto inserido pelo QuickPaste"
    }
}
