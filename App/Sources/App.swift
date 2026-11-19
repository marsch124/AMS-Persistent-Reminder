import SwiftUI
import UIKit
import UserNotifications
import AMSIcons
import ReminderCore

@main
struct PersistentReminderApp: App {
    @Environment(\.scenePhase) private var phase
    @StateObject private var store = Store.shared

    init() {
        // Set before anything else, so a nudge's button that wakes the app is never missed.
        UNUserNotificationCenter.current().delegate = NudgeDelegate.shared
        Nudger.setUp()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.orange)
        }
        .onChange(of: phase) { _, new in
            if new == .active { store.refresh(); Nudger.openPendingShortcut() }
        }
    }
}

/// Each part of the app has its own colour, pleasing by day and by night.
enum Theme {
    static let orange = dynamic(0xE8603A, 0xFF8A65)   // Reminders, waiting
    static let blue = dynamic(0x2F7CF6, 0x5A9BFF)     // Today, New reminder
    static let purple = dynamic(0x7C4DEB, 0xA78BFA)   // Settings, nudges
    static let green = dynamic(0x24985D, 0x4ADE80)    // Done
    static let waitingRow = dynamic(0xFFF2EC, 0x3A2620)
    // Filled buttons keep a deep colour by night too, so white words on them stay easy to read.
    static let orangeFill = dynamic(0xE8603A, 0xE0562F)
    static let blueFill = dynamic(0x2F7CF6, 0x2F6FE0)

    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light) })
    }

    /// "08:00"
    static func time(_ d: Date) -> String { format("HH:mm", d) }
    /// "Mon 23 Nov"
    static func shortDay(_ d: Date) -> String { format("EEE d MMM", d) }
    /// "Thursday 19 November"
    static func longDay(_ d: Date) -> String { format("EEEE d MMMM", d) }

    private static func format(_ pattern: String, _ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = pattern
        return f.string(from: d)
    }

    static var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                  blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}

enum Tab { case reminders, settings }

/// Two parts only: Reminders and Settings, with large hand-drawn marks at the bottom.
struct RootView: View {
    @EnvironmentObject private var store: Store
    @State private var tab: Tab = .reminders
    private let clock = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch tab {
                case .reminders: RemindersScreen()
                case .settings: SettingsScreen()
                }
            }
            .frame(maxHeight: .infinity)
            TabBar(tab: $tab)
        }
        .onReceive(clock) { store.now = $0 }
        .task {
            if store.nudgesOn { _ = await Nudger.askPermission(); store.refresh() }
        }
    }
}

struct TabBar: View {
    @Binding var tab: Tab

    var body: some View {
        HStack(spacing: 0) {
            item(.reminders, "Reminders", Theme.orange, id: "tab-reminders") { AppMarkView(.bell, size: 42) }
            item(.settings, "Settings", Theme.purple, id: "tab-settings") { ControlMarkView(.settings, size: 42) }
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) { Divider() }
    }

    private func item<M: View>(_ t: Tab, _ title: String, _ colour: Color, id: String, @ViewBuilder mark: () -> M) -> some View {
        Button {
            tab = t
        } label: {
            VStack(spacing: 3) {
                mark()
                Text(title).font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .foregroundStyle(tab == t ? colour : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(tab == t ? .isSelected : [])
    }
}

/// The green ring of what is done today.
struct DoneRing: View {
    let done: Int
    let total: Int
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle().stroke(Theme.green.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: total == 0 ? 0 : CGFloat(done) / CGFloat(total))
                .stroke(Theme.green, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
