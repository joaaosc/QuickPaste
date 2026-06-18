import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(QuickPasteSettings.Key.openEditorAtLaunch)
    private var openEditorAtLaunch = false

    @AppStorage(QuickPasteSettings.Key.globalHotKeyEnabled)
    private var globalHotKeyEnabled = true

    @State private var startAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Toggle("Abrir a nota ao iniciar o app", isOn: $openEditorAtLaunch)

                Toggle("Iniciar no login", isOn: $startAtLogin)
                    .onChange(of: startAtLogin) { _, enabled in
                        updateLoginItem(enabled: enabled)
                    }

                Toggle("Atalho global (⌃⌥Espaço)", isOn: $globalHotKeyEnabled)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }

    private func updateLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            startAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

#Preview {
    GeneralSettingsView()
}
