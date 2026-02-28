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
        TabView {
            calendarsTab
                .tabItem { Label("Calendars", systemImage: "calendar") }

            remindersTab
                .tabItem { Label("Reminders", systemImage: "checklist") }

            groupsTab
                .tabItem { Label("Groups", systemImage: "folder") }
        }
        .frame(width: 500, height: 420)
    }

    // MARK: - Tabs

    private var calendarsTab: some View {
        Form {
            Section {
                ForEach(systemCalendars, id: \.calendarIdentifier) { calendar in
                    CalendarRow(calendar: calendar, settingsManager: settingsManager)
                }
            } header: {
                Text("Select which calendars to display")
            }
        }
        .formStyle(.grouped)
    }

    private var remindersTab: some View {
        Form {
            Section {
                ForEach(systemReminderLists, id: \.calendarIdentifier) { list in
                    ReminderListSettingsRow(calendar: list, settingsManager: settingsManager)
                }
            } header: {
                Text("Select which reminder lists to display")
            }
        }
        .formStyle(.grouped)
    }

    private var groupsTab: some View {
        Form {
            if settingsManager.data.groups.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "folder.badge.plus")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No Groups")
                                .font(.headline)
                            Text("Groups let you bundle calendars and reminders together in the menu bar.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 12)
                        Spacer()
                    }
                }
            } else {
                Section {
                    ForEach(settingsManager.data.groups.sorted { $0.sortOrder < $1.sortOrder }) { group in
                        HStack(spacing: 10) {
                            Image(systemName: "folder")
                                .foregroundColor(.accentColor)
                            Text(group.name)
                            Spacer()
                            Button {
                                settingsManager.deleteGroup(id: group.id)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Your groups")
                }
            }

            Section {
                HStack(spacing: 8) {
                    TextField("Group name", text: $newGroupName)
                        .onSubmit { addGroup() }
                    Button("Add") { addGroup() }
                        .disabled(newGroupName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Add a new group")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Actions

    private func addGroup() {
        let name = newGroupName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        settingsManager.addGroup(name: name)
        newGroupName = ""
    }
}

// MARK: - Calendar Row

struct CalendarRow: View {
    let calendar: EKCalendar
    @ObservedObject var settingsManager: CalendarSettingsManager

    private var assignment: CalendarAssignment? {
        settingsManager.data.assignments.first { $0.id == calendar.calendarIdentifier }
    }

    private var isVisible: Bool { assignment?.isVisible ?? true }
    private var currentGroupID: UUID? { assignment?.groupID }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(cgColor: calendar.cgColor))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(calendar.title)
                    .fontWeight(.medium)
                Text(calendar.source.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !settingsManager.data.groups.isEmpty {
                Picker("", selection: Binding(
                    get: { currentGroupID },
                    set: { settingsManager.setGroup(calendarID: calendar.calendarIdentifier, groupID: $0) }
                )) {
                    Text("No Group").tag(UUID?.none)
                    ForEach(settingsManager.data.groups.sorted { $0.sortOrder < $1.sortOrder }) { group in
                        Text(group.name).tag(UUID?.some(group.id))
                    }
                }
                .labelsHidden()
                .frame(width: 110)
            }

            Toggle("", isOn: Binding(
                get: { isVisible },
                set: { settingsManager.setVisibility(calendarID: calendar.calendarIdentifier, visible: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
    }
}

// MARK: - Reminder List Row

struct ReminderListSettingsRow: View {
    let calendar: EKCalendar
    @ObservedObject var settingsManager: CalendarSettingsManager

    private var assignment: CalendarAssignment? {
        settingsManager.data.reminderAssignments.first { $0.id == calendar.calendarIdentifier }
    }

    private var isVisible: Bool { assignment?.isVisible ?? true }
    private var currentGroupID: UUID? { assignment?.groupID }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(cgColor: calendar.cgColor))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(calendar.title)
                    .fontWeight(.medium)
                Text(calendar.source.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !settingsManager.data.groups.isEmpty {
                Picker("", selection: Binding(
                    get: { currentGroupID },
                    set: { settingsManager.setReminderGroup(calendarID: calendar.calendarIdentifier, groupID: $0) }
                )) {
                    Text("No Group").tag(UUID?.none)
                    ForEach(settingsManager.data.groups.sorted { $0.sortOrder < $1.sortOrder }) { group in
                        Text(group.name).tag(UUID?.some(group.id))
                    }
                }
                .labelsHidden()
                .frame(width: 110)
            }

            Toggle("", isOn: Binding(
                get: { isVisible },
                set: { settingsManager.setReminderVisibility(calendarID: calendar.calendarIdentifier, visible: $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
    }
}
