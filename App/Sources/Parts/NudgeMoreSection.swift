import SwiftUI
import AVFoundation
import AMSIcons
import ReminderCore

/// Plays a sound when its chip is tapped, so the choice is heard.
enum SoundPreview {
    private static var player: AVAudioPlayer?
    static func play(_ sound: NudgeSound) {
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "caf") else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}

/// Extra nudge choices on the reminder page, shown under "Nudge me every":
/// louder when ignored (pick 2), its own sound (pick 3), stop nudging at a time (pick 5).
struct NudgeMoreSection: View {
    @Binding var sound: NudgeSound?
    @Binding var louder: Bool
    @Binding var stopAt: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $louder) {
                HStack(spacing: 8) {
                    AppMarkView(.bell, size: 18, colour: Theme.purple)
                    Text("Nudge more often when I don't react").font(.subheadline)
                }
            }
            .tint(Theme.purple)
            .accessibilityIdentifier("louder-switch")
            if louder {
                Text("From the 4th nudge: twice as often, and a stronger sound.")
                    .font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("louder-note")
            }

            Text("Sound").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.purple)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 6)], alignment: .leading, spacing: 6) {
                chip("iPhone", on: sound == nil, id: "sound-iphone") { sound = nil }
                ForEach(NudgeSound.allCases, id: \.self) { s in
                    chip(s.title, on: sound == s, id: "sound-\(s.rawValue)") { sound = s; SoundPreview.play(s) }
                }
            }
            Text(sound == nil ? "The iPhone's own nudge sound." : "Tap a name to hear it.")
                .font(.footnote).foregroundStyle(.secondary)

            Toggle(isOn: Binding(get: { stopAt != nil }, set: { stopAt = $0 ? (stopAt ?? 18 * 60) : nil })) {
                HStack(spacing: 8) {
                    AppMarkView(.clock, size: 18, colour: Theme.purple)
                    Text("Stop nudging at").font(.subheadline)
                }
            }
            .tint(Theme.purple)
            .accessibilityIdentifier("stop-switch")
            if let s = stopAt {
                DatePicker("Stop nudging at", selection: Binding(get: { Self.date(minutes: s) }, set: { stopAt = Self.minutes($0) }),
                           displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .tint(Theme.purple)
                    .accessibilityIdentifier("stop-time")
                Text("On the day it is for, no nudges after this time. It stays on the list.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func chip(_ title: String, on: Bool, id: String, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            HStack(spacing: 4) {
                if on { ControlMarkView(.check, size: 11, colour: .white) }
                Text(title).font(.footnote.weight(.medium)).lineLimit(1)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 7)
            .foregroundStyle(on ? Color.white : Color.primary)
            .background(on ? Theme.purpleFill : Color(.secondarySystemGroupedBackground), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    static func date(minutes: Int) -> Date { at(hour: minutes / 60, minute: minutes % 60, on: Date()) }
    static func minutes(_ d: Date) -> Int {
        let c = Calendar.current
        return c.component(.hour, from: d) * 60 + c.component(.minute, from: d)
    }
}
