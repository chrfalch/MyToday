import SwiftUI
import EventKit

struct SettingsView: View {
    @ObservedObject var settingsManager: CalendarSettingsManager
    let store: EKEventStore
    @State private var newGroupName = ""

    private var systemCalendars: [EKCalendar] {
        store.calendars(for: .event).sorted { $0.title < $1.title }
    }

    private var systemReminderLists: [EKCalendar] {
        store.calendars(for: .reminder).sorted { $0.title < $1.title }
    }

    var body: some View {
        HSplitView {
            // Left panel: Groups
            VStack(alignment: .leading, spacing: 0) {
                Text("Groups")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                List {
                    ForEach(settingsManager.data.groups.sorted { $0.sortOrder < $1.sortOrder }) { group in
                        Text(group.name)
                    }
                }
                .listStyle(.sidebar)

                Divider()

                HStack(spacing: 4) {
                    TextField("New group", text: $newGroupName)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addGroup() }

                    Button(action: addGroup) {
                        Image(systemName: "plus")
                    }
                    .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button(action: deleteSelectedGroup) {
                        Image(systemName: "minus")
                    }
                    .disabled(settingsManager.data.groups.isEmpty)
                }
                .padding(8)
            }
            .frame(minWidth: 140, idealWidth: 160, maxWidth: 200)

            // Right panel: Calendars & Reminders
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
            .frame(minWidth: 300)
        }
        .frame(width: 520, height: 460)
    }

    private func addGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        settingsManager.addGroup(name: name)
        newGroupName = ""
    }

    private func deleteSelectedGroup() {
        if let last = settingsManager.data.groups.sorted(by: { $0.sortOrder < $1.sortOrder }).last {
            settingsManager.deleteGroup(id: last.id)
        }
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

    private var currentGroupID: UUID? {
        assignment?.groupID
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

            Picker("", selection: Binding(
                get: { currentGroupID },
                set: { settingsManager.setGroup(calendarID: calendar.calendarIdentifier, groupID: $0) }
            )) {
                Text("None").tag(UUID?.none)
                ForEach(settingsManager.data.groups.sorted { $0.sortOrder < $1.sortOrder }) { group in
                    Text(group.name).tag(UUID?.some(group.id))
                }
            }
            .frame(width: 100)

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

    private var currentGroupID: UUID? {
        assignment?.groupID
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

            Picker("", selection: Binding(
                get: { currentGroupID },
                set: { settingsManager.setReminderGroup(calendarID: calendar.calendarIdentifier, groupID: $0) }
            )) {
                Text("None").tag(UUID?.none)
                ForEach(settingsManager.data.groups.sorted { $0.sortOrder < $1.sortOrder }) { group in
                    Text(group.name).tag(UUID?.some(group.id))
                }
            }
            .frame(width: 100)

            Toggle("", isOn: Binding(
                get: { isVisible },
                set: { settingsManager.setReminderVisibility(calendarID: calendar.calendarIdentifier, visible: $0) }
            ))
            .toggleStyle(.checkbox)
        }
    }
}
