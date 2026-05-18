import SwiftUI

struct QuickPasteConfigContent: View {
    @State private var selectedTab: SettingsTab = .general

    @AppStorage("resetDefaultSize") private var resetDefaultSize: Bool = false
    @AppStorage("defaultFontSize") private var defaultFontSize: Double = 16

    @AppStorage("toggleTranslatorWithRightClick") private var toggleTranslatorWithRightClick: Bool = false
    @AppStorage("defaultTranslationLanguage") private var defaultTranslationLanguage: String = "Portuguese"

    @AppStorage("startAtLogin") private var startAtLogin: Bool = false
    @AppStorage("checkForUpdatesAutomatically") private var checkForUpdatesAutomatically: Bool = true

    private let translationLanguages = [
        "Portuguese",
        "English",
        "Spanish",
        "French",
        "German",
        "Italian",
        "Japanese",
        "Chinese"
    ]

    var body: some View {
        VStack(spacing: 0) {
            tabBar

            Divider()

            content

            Spacer()
        }
        .frame(width: 520, height: 360)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var tabBar: some View {
        HStack(spacing: 24) {
            tabButton(
                tab: .general,
                title: "General",
                systemImage: "gearshape"
            )

            tabButton(
                tab: .about,
                title: "Sobre",
                systemImage: "info.circle"
            )

            tabButton(
                tab: .donate,
                title: "Donate",
                systemImage: "heart"
            )
        }
        .padding(.top, 18)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
    }

    private func tabButton(
        tab: SettingsTab,
        title: String,
        systemImage: String
    ) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))

                Text(title)
                    .font(.caption)
            }
            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
            .frame(width: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .general:
            generalView

        case .about:
            aboutView

        case .donate:
            donateView
        }
    }

    private var generalView: some View {
        VStack(alignment: .leading, spacing: 14) {
            sizeSection

            Divider()

            translatorSection

            Divider()

            systemSection

            Spacer()

            Text("Changes are saved automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Reset default size", isOn: $resetDefaultSize)

            HStack(spacing: 12) {
                Text("Default font size")

                Slider(value: $defaultFontSize, in: 10...32, step: 1)

                Text("\(Int(defaultFontSize))")
                    .monospacedDigit()
                    .frame(width: 28, alignment: .trailing)
            }
        }
    }

    private var translatorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Toggle translator with right click", isOn: $toggleTranslatorWithRightClick)

            HStack {
                Text("Default translation language")

                Spacer()

                Picker("", selection: $defaultTranslationLanguage) {
                    ForEach(translationLanguages, id: \.self) { language in
                        Text(language).tag(language)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 160)
            }
        }
    }

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Start at login", isOn: $startAtLogin)

            Toggle("Check for updates automatically", isOn: $checkForUpdatesAutomatically)
        }
    }

    private var aboutView: some View {
        VStack(spacing: 14) {
            Image(systemName: "info.circle")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text("QuickPaste")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Feito por João Pedro para ser útil.")
                .font(.body)
                .foregroundStyle(.secondary)

            Text("Version 1.0")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var donateView: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text("Donate")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Depois definimos essa parte.")
                .font(.body)
                .foregroundStyle(.secondary)

            Button("Donate") {
                print("Donate clicked")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

private enum SettingsTab {
    case general
    case about
    case donate
}

#Preview {
    QuickPasteConfigContent()
}
