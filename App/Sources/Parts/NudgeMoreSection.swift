import SwiftUI
import ReminderCore

/// Extra nudge choices on the reminder page, shown under "Nudge me every".
/// 0.5 lane "nudges" (picks 2 louder, 3 sound, 5 stop at a time) owns this file.
struct NudgeMoreSection: View {
    @Binding var sound: NudgeSound?
    @Binding var louder: Bool
    @Binding var stopAt: Int?

    var body: some View { EmptyView() }
}
