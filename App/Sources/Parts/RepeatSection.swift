import SwiftUI
import ReminderCore

/// The Repeat part of the reminder page. 0.5 lane "repeats" (picks 7, 8, 9) owns this file.
struct RepeatSection: View {
    @Binding var repeats: Repeat
    @Binding var every: Int
    @Binding var weekdays: [Int]
    @Binding var afterDone: Bool
    let due: Date

    var body: some View {
        Picker("Repeat", selection: $repeats) {
            ForEach([Repeat.never, .daily, .weekly, .monthly], id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
    }
}
