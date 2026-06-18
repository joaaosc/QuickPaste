import SwiftUI

/// Preferences window: a native `TabView` so the system renders the macOS settings
/// tab bar (and its material) for us. Each tab is a small modular view.
struct SettingsContent: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("Geral", systemImage: "gearshape") }

            AdvancedSettingsView()
                .tabItem { Label("Avançado", systemImage: "slider.horizontal.3") }

            DisplaysSettingsView()
                .tabItem { Label("Telas", systemImage: "macwindow") }

            ShortcutsSettingsView()
                .tabItem { Label("Atalhos", systemImage: "keyboard") }

            AboutSettingsView()
                .tabItem { Label("Sobre", systemImage: "info.circle") }
        }
    }
}

#Preview {
    SettingsContent()
}
