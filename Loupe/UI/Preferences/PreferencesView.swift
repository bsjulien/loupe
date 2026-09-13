import SwiftUI
import AppKit

struct PreferencesView: View {
    @ObservedObject private var preferences = PreferencesStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Toggle("Copy screenshot to clipboard automatically", isOn: $preferences.autoCopyOnCapture)
            Toggle("Launch Loupe at login", isOn: $preferences.launchAtLogin)

            HStack {
                Text("Save screenshots to:")
                Text(preferences.saveFolderURL.path)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Choose…") { chooseFolder() }
            }

            Divider().overlay(Theme.hairlineColor)

            Text("Keyboard Shortcuts")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(HotkeyAction.allCases, id: \.self) { action in
                HStack {
                    Text(action.title)
                    Spacer()
                    ShortcutRecorderField(action: action)
                }
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 460, height: 420, alignment: .top)
        .background(Theme.backgroundColor)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = preferences.saveFolderURL
        if panel.runModal() == .OK, let url = panel.url {
            preferences.saveFolderURL = url
        }
    }
}
