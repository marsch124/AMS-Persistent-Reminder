import SwiftUI
import ReminderCore

/// "Note" and "Call or open" on the reminder page. 0.5 lane "voice" (picks 16, 17) owns this file.
struct NoteLinkSection: View {
    @Binding var note: String
    @Binding var action: TapAction?

    var body: some View { EmptyView() }
}
