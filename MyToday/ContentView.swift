import SwiftUI
import Combine
import EventKit

struct PopoverContentView: View {
    @ObservedObject var eventManager: EventManager
    var onOpenSettings: () -> Void = {}

    private var showGroupHeaders: Bool {
        let groups = eventManager.groupedEvents
        if groups.count == 1 && groups.first?.groupName == "Today" {
            return false
        }
        return groups.count > 1 || (groups.count == 1 && groups.first?.groupName != "Today")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Today's Schedule")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Text(Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button(action: { eventManager.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Reminders summary
                    if eventManager.reminderAccessGranted {
                        RemindersSectionView(
                            overdue: eventManager.overdueReminders,
                            undated: eventManager.undatedReminders,
                            listSummaries: eventManager.reminderListSummaries
                        )
                        Divider().padding(.leading, 16)
                    }

                    // Meetings
                    if !eventManager.calendarAccessGranted {
                        Text("Calendar access required.\nPlease grant access in System Settings → Privacy → Calendars.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    } else if eventManager.todaysEvents.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("No more meetings today")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
                        ForEach(eventManager.groupedEvents) { group in
                            if showGroupHeaders {
                                Text(group.groupName.uppercased())
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 10)
                                    .padding(.bottom, 4)
                            }
                            ForEach(group.events, id: \.eventIdentifier) { event in
                                EventRowView(event: event)
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)

                Spacer()

                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 340)
    }
}

struct RemindersSectionView: View {
    let overdue: Int
    let undated: Int
    let listSummaries: [ReminderListSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 12) {
                Image(systemName: "bell.fill")
                    .foregroundColor(.orange)
                    .frame(width: 20)

                Text("Reminders")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if overdue > 0 || undated > 0 {
                    HStack(spacing: 8) {
                        if overdue > 0 {
                            HStack(spacing: 3) {
                                Circle().fill(Color.red).frame(width: 8, height: 8)
                                Text("\(overdue)").font(.caption).foregroundColor(.red)
                            }
                        }
                        if undated > 0 {
                            HStack(spacing: 3) {
                                Circle().fill(Color.orange).frame(width: 8, height: 8)
                                Text("\(undated)").font(.caption).foregroundColor(.orange)
                            }
                        }
                    }
                } else {
                    Text("All clear!")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Per-list breakdown
            ForEach(listSummaries) { summary in
                ReminderListRow(summary: summary)
            }

            if !listSummaries.isEmpty {
                Spacer().frame(height: 6)
            }
        }
    }
}

struct ReminderListRow: View {
    let summary: ReminderListSummary
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(cgColor: summary.color))
                .frame(width: 8, height: 8)

            Text(summary.listName)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            if summary.overdueCount > 0 {
                HStack(spacing: 3) {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                    Text("\(summary.overdueCount)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            if summary.undatedCount > 0 {
                HStack(spacing: 3) {
                    Circle().fill(Color.orange).frame(width: 6, height: 6)
                    Text("\(summary.undatedCount)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.leading, 32)
        .padding(.vertical, 4)
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture { openInReminders() }
    }

    private func openInReminders() {
        if let extID = summary.externalIdentifier,
           let url = URL(string: "x-apple-reminderkit://REMCDList/\(extID)") {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(string: "x-apple-reminderkit://")!)
        }
    }
}

struct EventRowView: View {
    let event: EKEvent
    @State private var now = Date()
    let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var isNow: Bool {
        event.startDate <= now && event.endDate > now
    }

    private var isPast: Bool {
        event.endDate <= now
    }

    private var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return "\(fmt.string(from: event.startDate)) – \(fmt.string(from: event.endDate))"
    }

    private var minutesUntil: Int {
        Int(event.startDate.timeIntervalSince(now) / 60)
    }

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Color strip
            RoundedRectangle(cornerRadius: 2)
                .fill(calendarColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(event.title ?? "Untitled")
                        .font(.subheadline)
                        .fontWeight(isNow ? .semibold : .regular)
                        .foregroundColor(isPast ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer()
                    if isNow {
                        Text("NOW")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .cornerRadius(4)
                    } else if !isPast && minutesUntil <= 15 && minutesUntil >= 0 {
                        Text("in \(minutesUntil)m")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .cornerRadius(4)
                    }
                }

                Text(timeString)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let location = event.location, !location.isEmpty {
                    Label(location, systemImage: "mappin.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                if let url = event.url {
                    Link("Join meeting", destination: url)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isNow ? Color.green.opacity(0.05) : isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture { openInCalendar() }
        .onReceive(timer) { _ in
            now = Date()
        }
    }

    private func openInCalendar() {
        let epoch = event.startDate.timeIntervalSinceReferenceDate
        if let url = URL(string: "ical://showdate/\(Int(epoch))") {
            NSWorkspace.shared.open(url)
        }
    }

    private var calendarColor: Color {
        guard let cgColor = event.calendar?.cgColor else { return .accentColor }
        return Color(cgColor: cgColor)
    }
}
