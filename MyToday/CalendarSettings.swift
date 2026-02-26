import Foundation
import EventKit
import Combine

struct CalendarGroup: Codable, Identifiable {
    var id: UUID
    var name: String
    var sortOrder: Int
}

struct CalendarAssignment: Codable, Identifiable {
    var id: String // EKCalendar.calendarIdentifier
    var isVisible: Bool
    var groupID: UUID?
}

struct CalendarSettingsData: Codable {
    var groups: [CalendarGroup] = []
    var assignments: [CalendarAssignment] = []
    var reminderAssignments: [CalendarAssignment] = []
}

class CalendarSettingsManager: ObservableObject {
    private static let key = "CalendarSettingsData"

    @Published var data: CalendarSettingsData {
        didSet { save() }
    }

    init() {
        if let raw = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(CalendarSettingsData.self, from: raw) {
            data = decoded
        } else {
            data = CalendarSettingsData()
        }
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: Self.key)
        }
    }

    // MARK: - Group mutations

    func addGroup(name: String) {
        let maxOrder = data.groups.map(\.sortOrder).max() ?? -1
        let group = CalendarGroup(id: UUID(), name: name, sortOrder: maxOrder + 1)
        data.groups.append(group)
    }

    func deleteGroup(id: UUID) {
        data.groups.removeAll { $0.id == id }
        for i in data.assignments.indices where data.assignments[i].groupID == id {
            data.assignments[i].groupID = nil
        }
        for i in data.reminderAssignments.indices where data.reminderAssignments[i].groupID == id {
            data.reminderAssignments[i].groupID = nil
        }
    }

    // MARK: - Assignment mutations

    func setVisibility(calendarID: String, visible: Bool) {
        if let idx = data.assignments.firstIndex(where: { $0.id == calendarID }) {
            data.assignments[idx].isVisible = visible
        }
    }

    func setGroup(calendarID: String, groupID: UUID?) {
        if let idx = data.assignments.firstIndex(where: { $0.id == calendarID }) {
            data.assignments[idx].groupID = groupID
        }
    }

    // MARK: - Reminder assignment mutations

    func setReminderVisibility(calendarID: String, visible: Bool) {
        if let idx = data.reminderAssignments.firstIndex(where: { $0.id == calendarID }) {
            data.reminderAssignments[idx].isVisible = visible
        }
    }

    func setReminderGroup(calendarID: String, groupID: UUID?) {
        if let idx = data.reminderAssignments.firstIndex(where: { $0.id == calendarID }) {
            data.reminderAssignments[idx].groupID = groupID
        }
    }

    // MARK: - Sync with system calendars

    func syncWithSystemCalendars(_ calendars: [EKCalendar]) {
        let existingIDs = Set(data.assignments.map(\.id))
        for cal in calendars {
            if !existingIDs.contains(cal.calendarIdentifier) {
                data.assignments.append(
                    CalendarAssignment(id: cal.calendarIdentifier, isVisible: true, groupID: nil)
                )
            }
        }
        let systemIDs = Set(calendars.map(\.calendarIdentifier))
        data.assignments.removeAll { !systemIDs.contains($0.id) }
    }

    func syncWithSystemReminderLists(_ calendars: [EKCalendar]) {
        let existingIDs = Set(data.reminderAssignments.map(\.id))
        for cal in calendars {
            if !existingIDs.contains(cal.calendarIdentifier) {
                data.reminderAssignments.append(
                    CalendarAssignment(id: cal.calendarIdentifier, isVisible: true, groupID: nil)
                )
            }
        }
        let systemIDs = Set(calendars.map(\.calendarIdentifier))
        data.reminderAssignments.removeAll { !systemIDs.contains($0.id) }
    }

    // MARK: - Filtering

    func visibleCalendars(from store: EKEventStore) -> [EKCalendar] {
        let visibleIDs = Set(data.assignments.filter(\.isVisible).map(\.id))
        return store.calendars(for: .event).filter { visibleIDs.contains($0.calendarIdentifier) }
    }

    func visibleReminderLists(from store: EKEventStore) -> [EKCalendar] {
        let visibleIDs = Set(data.reminderAssignments.filter(\.isVisible).map(\.id))
        return store.calendars(for: .reminder).filter { visibleIDs.contains($0.calendarIdentifier) }
    }
}
