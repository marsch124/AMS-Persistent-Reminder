import SwiftUI
import UIKit
import AMSIcons
import ReminderCore

/// "Your shortcuts": every shortcut's name, sent by the helper shortcut "AMS Reminder List".
/// From a reminder, tapping a name puts it into the Shortcut field; from Settings it is only a list.
struct ShortcutPicker: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    /// Nil when opened from Settings.
    var choose: ((String) -> Void)?
    @State private var search = ""

    var body: some View {
        List {
            if store.shortcutNames.isEmpty {
                Section {
                    Text("An iPhone app cannot read your shortcuts by itself. A small helper shortcut, “\(ShortcutNames.helperName)”, does it for the app. Do these two steps once:")
                        .font(.subheadline)
                    step(1, "Add the helper", "Opens the Shortcuts app. Press “Add Shortcut” there.", id: "add-helper") { addHelper() }
                    step(2, "Load my shortcuts", "The Shortcuts app flashes up and comes back with your list. If iPhone asks, press Allow.", id: "load-shortcuts") { load() }
                } footer: {
                    shareHelper
                }
            } else {
                Section {
                    ForEach(ShortcutNames.filter(store.shortcutNames, search), id: \.self) { name in
                        Button {
                            choose?(name)
                            if choose != nil { dismiss() }
                        } label: {
                            HStack(spacing: 10) {
                                ControlMarkView(.play, size: 16, colour: Theme.purple)
                                Text(name).foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(choose == nil)
                        .accessibilityIdentifier("shortcut-option-\(name)")
                    }
                } footer: {
                    Text("\(store.shortcutNames.count) shortcuts. Made a new one? Load the list again.")
                }
                Section {
                    Button { load() } label: {
                        Text("Load again").bold().foregroundStyle(.white).frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Theme.purpleFill)
                    .accessibilityIdentifier("load-shortcuts")
                    Button { addHelper() } label: {
                        Text("Add the helper again").frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("add-helper")
                } footer: {
                    shareHelper
                }
            }
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier("shortcut-picker")
        .searchable(text: $search, prompt: "Search your shortcuts")
        .navigationTitle("Your shortcuts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ n: Int, _ title: String, _ hint: String, id: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: action) {
                Text("\(n). \(title)").bold().foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 9)
                    .background(Theme.purpleFill, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(id)
            Text(hint).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    /// Second way to add the helper: the share sheet offers the file to the Shortcuts app.
    @ViewBuilder private var shareHelper: some View {
        if let file = Bundle.main.url(forResource: ShortcutNames.helperName, withExtension: "shortcut") {
            ShareLink(item: file) {
                Text("Adding did not open Shortcuts? Share the helper file")
                    .font(.footnote).foregroundStyle(Theme.purple)
            }
            .accessibilityIdentifier("share-helper")
            .padding(.top, 6)
        }
    }

    private func addHelper() {
        if let url = ShortcutNames.addHelperURL { UIApplication.shared.open(url) }
    }

    private func load() {
        if let url = Reminder.shortcutURL(for: ShortcutNames.helperName) { UIApplication.shared.open(url) }
    }
}
