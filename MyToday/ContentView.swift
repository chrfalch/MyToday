import SwiftUI
import EventKit

struct PopoverContentView: View {
    @ObservedObject var eventManager: EventManager

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
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Reminders summary
                    if eventManager.reminderAccessGranted {
                        RemindersRowView(
                            overdue: eventManager.overdueReminders,
                            undated: eventManager.undatedReminders
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
                        ForEach(eventManager.todaysEvents, id: \.eventIdentifier) { event in
                            EventRowView(event: event)
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                Button("Refresh") {
                    eventManager.refresh()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.accentColor)

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

struct RemindersRowView: View {
    let overdue: Int
    let undated: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.fill")
                .foregroundColor(.orange)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text("Reminders")
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 8) {
                    if overdue > 0 {
                        Label("\(overdue) overdue", systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    if undated > 0 {
                        Label("\(undated) undated", systemImage: "clock.badge.questionmark")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if overdue == 0 && undated == 0 {
                        Text("All clear!")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct EventRowView: View {
    let event: EKEvent
    @State private var now = Date()

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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Color strip + status indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(calendarColor)
                .frame(width: 4)
                .padding(.vertical, 2)

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
        .background(isNow ? Color.green.opacity(0.05) : Color.clear)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                now = Date()
            }
        }
    }

    private var calendarColor: Color {
        guard let cgColor = event.calendar?.cgColor else { return .accentColor }
        return Color(cgColor: cgColor)
    }
}
