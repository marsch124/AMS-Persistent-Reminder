import SwiftUI
import AMSIcons
import ReminderCore

/// Settings parts for nudges, shown right under the "Nudges" part: quiet hours (pick 4), the "later" buttons (pick 6).
struct NudgeSettingsSection: View {
    @EnvironmentObject private var store: Store
    @AppStorage(Nudger.quietOnKey) private var quietOn = false
    @AppStorage(Nudger.quietFromKey) private var quietFrom = QuietHours.defaultFrom
    @AppStorage(Nudger.quietToKey) private var quietTo = QuietHours.defaultTo
    @AppStorage(Nudger.laterKey) private var laterSaved = LaterChoice.save(LaterChoice.defaults)

    var body: some View {
        Section {
            Toggle(isOn: $quietOn) {
                HStack(spacing: 12) {
                    AppMarkView(.moon, size: 24, colour: Theme.purple)
                    Text("Quiet hours")
                }
            }
            .tint(Theme.purple)
            .accessibilityIdentifier("quiet-switch")
            if quietOn {
                DatePicker("From", selection: time($quietFrom), displayedComponents: .hourAndMinute)
                    .tint(Theme.purple)
                    .accessibilityIdentifier("quiet-from")
                DatePicker("To", selection: time($quietTo), displayedComponents: .hourAndMinute)
                    .tint(Theme.purple)
                    .accessibilityIdentifier("quiet-to")
            }
        } header: {
            Text("Quiet hours").foregroundStyle(Theme.purple)
        } footer: {
            Text("No nudges at night. Anything still waiting nudges you when quiet hours end.")
        }
        .onChange(of: quietOn) { _, _ in store.refresh() }
        .onChange(of: quietFrom) { _, _ in store.refresh() }
        .onChange(of: quietTo) { _, _ in store.refresh() }

        Section {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(LaterChoice.allCases, id: \.self) { c in
                    let on = chosen.contains(c)
                    Button {
                        laterSaved = LaterChoice.save(LaterChoice.picking(c, in: chosen))
                        store.refresh()
                    } label: {
                        HStack(spacing: 4) {
                            if on { ControlMarkView(.check, size: 11, colour: .white) }
                            Text(c.chipTitle).font(.footnote.weight(.medium)).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 7)
                        .foregroundStyle(on ? Color.white : Color.primary)
                        .background(on ? Theme.purpleFill : Color(.tertiarySystemFill), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("later-\(c.rawValue)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        } header: {
            Text("Later buttons on a nudge").foregroundStyle(Theme.purple)
        } footer: {
            Text("Pick 3 for the buttons under a nudge. Tap another one to swap it in for the one you picked first. After 19:00 \"This evening\" says \"Tomorrow morning\".")
        }
    }

    private var chosen: [LaterChoice] { LaterChoice.parse(laterSaved) }

    private func time(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(get: { NudgeMoreSection.date(minutes: minutes.wrappedValue) },
                set: { minutes.wrappedValue = NudgeMoreSection.minutes($0) })
    }
}
