import SwiftUI
import UIKit
import ContactsUI
import ReminderCore

/// "Note" and "Call or open" on the reminder page. 0.5 lane "voice" (picks 16, 17) owns this file.
struct NoteLinkSection: View {
    @Binding var note: String
    @Binding var action: TapAction?
    @State private var pickingContact = false

    private enum Mode: Hashable { case none, call, link }

    private var mode: Binding<Mode> {
        Binding(
            get: {
                switch action?.kind {
                case .call: return .call
                case .link: return .link
                case nil: return .none
                }
            },
            set: { new in
                switch new {
                case .none: action = nil
                case .call: if action?.kind != .call { action = TapAction(kind: .call, value: "", label: "") }
                case .link: if action?.kind != .link { action = TapAction(kind: .link, value: "", label: "") }
                }
            })
    }

    private var value: Binding<String> {
        Binding(get: { action?.value ?? "" }, set: { action?.value = $0 })
    }
    private var label: Binding<String> {
        Binding(get: { action?.label ?? "" }, set: { action?.label = $0 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading("Note")
            TextField("A few extra words (optional)", text: $note, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("note-field")

            heading("Call or open")
            Picker("Call or open", selection: mode) {
                Text("None").tag(Mode.none)
                Text("Call").tag(Mode.call)
                Text("Link").tag(Mode.link)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("action-kind")

            if let a = action {
                VStack(spacing: 10) {
                    if a.kind == .call {
                        HStack(spacing: 8) {
                            TextField("Phone number", text: value)
                                .keyboardType(.phonePad)
                                .accessibilityIdentifier("call-number")
                            Button("Pick a contact") { pickingContact = true }
                                .buttonStyle(.borderedProminent).tint(Theme.blueFill).controlSize(.small)
                                .accessibilityIdentifier("pick-contact")
                        }
                        TextField("Name (optional)", text: label)
                            .accessibilityIdentifier("action-name")
                    } else {
                        TextField("Web address", text: value)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("link-address")
                        TextField("Name (optional)", text: label)
                            .accessibilityIdentifier("action-name")
                    }
                    HStack {
                        Spacer()
                        Button("Try it") { if let url = a.url { UIApplication.shared.open(url) } }
                            .buttonStyle(.bordered).tint(Theme.blue).controlSize(.small)
                            .disabled(a.url == nil)
                            .accessibilityIdentifier("try-action")
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                Text("Press and hold the row to call or open it.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("action-hint")
            }
        }
        .sheet(isPresented: $pickingContact) {
            ContactPicker { number, name in
                action = TapAction(kind: .call, value: number, label: name)
            }
            .ignoresSafeArea()
        }
    }

    private func heading(_ text: String) -> some View {
        Text(text.uppercased()).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            .padding(.top, 2)
    }
}

/// The iPhone's own contact list, showing phone numbers; tapping a number hands back the number and the name.
struct ContactPicker: UIViewControllerRepresentable {
    let onPick: (String, String) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let p = CNContactPickerViewController()
        p.displayedPropertyKeys = [CNContactPhoneNumbersKey]
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: CNContactPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (String, String) -> Void
        init(_ onPick: @escaping (String, String) -> Void) { self.onPick = onPick }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect property: CNContactProperty) {
            guard let number = (property.value as? CNPhoneNumber)?.stringValue else { return }
            let name = CNContactFormatter.string(from: property.contact, style: .fullName) ?? ""
            onPick(number, name)
        }
    }
}
