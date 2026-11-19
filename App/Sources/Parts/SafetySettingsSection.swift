import SwiftUI
import UniformTypeIdentifiers
import AMSIcons
import ReminderCore

/// Settings part for keeping the list safe: iCloud (pick 28), save and restore a copy (pick 29).
/// 0.5 lane "safety" owns this file. Returns whole `Section { … }`s.
struct SafetySettingsSection: View {
    @EnvironmentObject private var store: Store
    @AppStorage(CloudCopy.switchKey) private var cloudOn = true
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingCloud: CloudCopy.Copy?
    @State private var pendingFile: ReminderList?
    @State private var message: String?

    private var colour: Color { Theme.row(.teal) }

    var body: some View {
        Section {
            Toggle(isOn: $cloudOn) {
                HStack(spacing: 12) { AppMarkView(.cloud, size: 24, colour: colour); Text("Keep a copy in iCloud") }
            }
            .tint(colour)
            .accessibilityIdentifier("cloud-switch")
            Text(savedLine).font(.footnote).foregroundStyle(.secondary)
                .accessibilityIdentifier("cloud-saved-line")
            Button { askCloud() } label: {
                HStack(spacing: 12) { AppMarkView(.cloudDown, size: 24, colour: colour); Text("Bring back from iCloud…") }
            }
            .accessibilityIdentifier("cloud-bring-back")
            Button { exporting = true } label: {
                HStack(spacing: 12) { AppMarkView(.share, size: 24, colour: colour); Text("Save a copy…") }
            }
            .accessibilityIdentifier("copy-save")
            Button { importing = true } label: {
                HStack(spacing: 12) { AppMarkView(.undo, size: 24, colour: colour); Text("Bring back a copy…") }
            }
            .accessibilityIdentifier("copy-bring-back")
        } header: {
            Text("Keep it safe").foregroundStyle(colour)
        } footer: {
            Text("A copy is a file you keep in Files or send yourself. Bringing one back keeps your current list as a safety copy first.")
        }
        .fileExporter(isPresented: $exporting, document: CopyDocument(data: (try? JSONEncoder.reminders.encode(store.list)) ?? Data()),
                      contentType: .json, defaultFilename: "AMS Reminder copy \(Self.fileDay())") { _ in }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in readFile(result) }
        .confirmationDialog(cloudQuestion, isPresented: Binding(get: { pendingCloud != nil }, set: { if !$0 { pendingCloud = nil } }), titleVisibility: .visible) {
            Button("Replace my list") {
                if let c = pendingCloud { store.replaceList(with: c.list) }
                pendingCloud = nil
            }
            .accessibilityIdentifier("cloud-replace")
            Button("Cancel", role: .cancel) { pendingCloud = nil }
        }
        .confirmationDialog(fileQuestion, isPresented: Binding(get: { pendingFile != nil }, set: { if !$0 { pendingFile = nil } }), titleVisibility: .visible) {
            Button("Replace my list") {
                if let l = pendingFile { store.replaceList(with: l) }
                pendingFile = nil
            }
            .accessibilityIdentifier("copy-replace")
            Button("Cancel", role: .cancel) { pendingFile = nil }
        }
        .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        }
    }

    // MARK: Words

    private var savedLine: String {
        guard let d = store.cloudSavedAt else { return "Not saved yet" }
        return Calendar.current.isDateInToday(d) ? "Saved to iCloud today \(Theme.time(d))" : "Saved to iCloud \(Self.stamp(d))"
    }

    private var cloudQuestion: String {
        guard let c = pendingCloud else { return "" }
        return "Replace your list with the iCloud copy from \(Self.stamp(c.savedAt)) — \(c.list.countsText)? Your list now is kept as a safety copy first."
    }

    private var fileQuestion: String {
        guard let l = pendingFile else { return "" }
        return "Replace your list with this copy — \(l.countsText)? Your list now is kept as a safety copy first."
    }

    /// "19 Nov, 15:42"
    private static func stamp(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = "d MMM, HH:mm"
        return f.string(from: d)
    }

    private static func fileDay() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    // MARK: Actions

    private func askCloud() {
        if store.isTesting { message = "There is no iCloud copy yet."; return }
        if let c = CloudCopy.read() { pendingCloud = c } else { message = "There is no iCloud copy yet." }
    }

    private func readFile(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if let data = try? Data(contentsOf: url), let list = ReminderList.readCopy(data) {
            pendingFile = list
        } else {
            message = "That file is not a reminder copy."
        }
    }
}

/// The JSON file of the list, for "Save a copy…".
struct CopyDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
