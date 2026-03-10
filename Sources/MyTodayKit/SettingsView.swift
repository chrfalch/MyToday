import SwiftUI
import EventKit

struct SettingsView: View {
    @ObservedObject var settingsManager: CalendarSettingsManager
    let store: EKEventStore

    private var systemCalendars: [EKCalendar] {
        store.calendars(for: .event).sorted { $0.title < $1.title }
    }

    private var systemReminderLists: [EKCalendar] {
        store.calendars(for: .reminder).sorted { $0.title < $1.title }
    }

    var body: some View {
        List {
            Section("Calendars") {
                ForEach(systemCalendars, id: \.calendarIdentifier) { calendar in
                    CalendarRow(
                        calendar: calendar,
                        settingsManager: settingsManager
                    )
                }
            }

            Section("Reminders") {
                ForEach(systemReminderLists, id: \.calendarIdentifier) { list in
                    ReminderListSettingsRow(
                        calendar: list,
                        settingsManager: settingsManager
                    )
                }
            }
        }
        .frame(width: 360, height: 460)
    }
}

struct CalendarRow: View {
    let calendar: EKCalendar
    @ObservedObject var settingsManager: CalendarSettingsManager

    private var assignment: CalendarAssignment? {
        settingsManager.data.assignments.first { $0.id == calendar.calendarIdentifier }
    }

    private var isVisible: Bool {
        assignment?.isVisible ?? true
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(cgColor: calendar.cgColor))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 1) {
                Text(calendar.title)
                    .lineLimit(1)
                Text(calendar.source.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isVisible },
                set: { settingsManager.setVisibility(calendarID: calendar.calendarIdentifier, visible: $0) }
            ))
            .toggleStyle(.checkbox)
        }
    }
}

struct ReminderListSettingsRow: View {
    let calendar: EKCalendar
    @ObservedObject var settingsManager: CalendarSettingsManager

    private var assignment: CalendarAssignment? {
        settingsManager.data.reminderAssignments.first { $0.id == calendar.calendarIdentifier }
    }

    private var isVisible: Bool {
        assignment?.isVisible ?? true
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(cgColor: calendar.cgColor))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 1) {
                Text(calendar.title)
                    .lineLimit(1)
                Text(calendar.source.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isVisible },
                set: { settingsManager.setReminderVisibility(calendarID: calendar.calendarIdentifier, visible: $0) }
            ))
            .toggleStyle(.checkbox)
        }
    }
}
