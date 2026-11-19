import SwiftUI
import ReminderCore

/// The Repeat part of the reminder page (0.5: seven choices as chips, chosen days, every few hours or days,
/// counting from the tick). Lane "repeats" owns this file.
struct RepeatSection: View {
    @Binding var repeats: Repeat
    @Binding var every: Int
    @Binding var weekdays: [Int]
    @Binding var afterDone: Bool
    let due: Date

    /// Monday first, Calendar weekday numbers (1 = Sunday).
    private let days: [(number: Int, letter: String, name: String)] = [
        (2, "M", "Monday"), (3, "T", "Tuesday"), (4, "W", "Wednesday"), (5, "T", "Thursday"),
        (6, "F", "Friday"), (7, "S", "Saturday"), (1, "S", "Sunday"),
    ]
    private let choices: [Repeat] = [.never, .daily, .weekly, .monthly, .weekdays, .hours, .days]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            chips
            if repeats == .weekdays { dayButtons }
            if repeats == .hours || repeats == .days { stepper }
            if repeats != .never {
                Toggle("Count from when I tick it off", isOn: $afterDone)
                    .tint(Theme.blue)
                    .accessibilityIdentifier("after-done")
                Text("Example: water the plants 3 days after you last did it.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .onChange(of: repeats) { _, new in
            if new == .weekdays && weekdays.isEmpty {
                weekdays = [Calendar.current.component(.weekday, from: due)]
            }
        }
    }

    // MARK: Chips

    private var chips: some View {
        FlowLayout(spacing: 7) {
            ForEach(choices, id: \.self) { c in
                let on = repeats == c
                Button { repeats = c } label: {
                    Text(c.title)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .foregroundStyle(on ? .white : .primary)
                        .background(on ? Theme.blueFill : Color(.secondarySystemGroupedBackground), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("repeat-\(c.rawValue)")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    // MARK: Days

    private var dayButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(days, id: \.number) { d in
                    let on = weekdays.contains(d.number)
                    Button { toggle(d.number) } label: {
                        Text(d.letter)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .foregroundStyle(on ? .white : .primary)
                            .background(on ? Theme.blueFill : Color(.secondarySystemGroupedBackground), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(d.name)
                    .accessibilityAddTraits(on ? .isSelected : [])
                    .accessibilityIdentifier("day-\(d.number)")
                }
            }
            HStack(spacing: 7) {
                smallChip("Weekdays", id: "days-weekdays", on: Set(weekdays) == [2, 3, 4, 5, 6]) { weekdays = [2, 3, 4, 5, 6] }
                smallChip("Weekend", id: "days-weekend", on: Set(weekdays) == [1, 7]) { weekdays = [7, 1] }
            }
        }
    }

    private func smallChip(_ title: String, id: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .foregroundStyle(on ? Theme.blue : .primary)
                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                .overlay(Capsule().stroke(on ? Theme.blue : .clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    /// At least one day always stays chosen.
    private func toggle(_ n: Int) {
        if weekdays.contains(n) {
            if weekdays.count > 1 { weekdays.removeAll { $0 == n } }
        } else {
            weekdays.append(n)
        }
    }

    // MARK: Every N hours / days

    private var stepper: some View {
        let hours = repeats == .hours
        let limit = hours ? 12 : 30
        let unit = hours ? (every == 1 ? "hour" : "hours") : (every == 1 ? "day" : "days")
        return HStack(spacing: 10) {
            Text("Every")
            Button { every = max(1, every - 1) } label: { Text("−").font(.title3.weight(.semibold)).frame(width: 36, height: 32) }
                .buttonStyle(.bordered).tint(Theme.blue)
                .accessibilityLabel("Fewer")
                .accessibilityIdentifier("every-minus")
            Text("\(min(every, limit))").font(.title3.weight(.semibold)).monospacedDigit().frame(minWidth: 28)
                .accessibilityIdentifier("every-value")
            Button { every = min(limit, every + 1) } label: { Text("+").font(.title3.weight(.semibold)).frame(width: 36, height: 32) }
                .buttonStyle(.bordered).tint(Theme.blue)
                .accessibilityLabel("More")
                .accessibilityIdentifier("every-plus")
            Text(unit)
            Spacer()
        }
        .onAppear { every = min(max(1, every), limit) }
        .onChange(of: repeats) { _, _ in every = min(max(1, every), limit) }
    }
}

/// Chips that wrap onto new lines.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 7

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal.width ?? .infinity, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let l = layout(bounds.width, subviews)
        for (i, p) in l.points.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }

    private func layout(_ width: CGFloat, _ subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, maxX: CGFloat = 0
        var pts: [CGPoint] = []
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x > 0 && x + sz.width > width { x = 0; y += rowH + spacing; rowH = 0 }
            pts.append(CGPoint(x: x, y: y))
            x += sz.width + spacing; rowH = max(rowH, sz.height); maxX = max(maxX, x - spacing)
        }
        return (CGSize(width: maxX, height: y + rowH), pts)
    }
}
