import Foundation
import EventKit
import Combine

public struct CalendarGroup: Codable, Identifiable {
    public var id: UUID
    public var name: String
    public var sortOrder: Int

    public init(id: UUID, name: String, sortOrder: Int) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
    }
}

public struct CalendarAssignment: Codable, Identifiable {
    public var id: String // EKCalendar.calendarIdentifier
    public var isVisible: Bool
    public var groupID: UUID?

    public init(id: String, isVisible: Bool, groupID: UUID?) {
        self.id = id
        self.isVisible = isVisible
        self.groupID = groupID
    }
}

public struct CalendarSettingsData: Codable {
    public var groups: [CalendarGroup] = []
    public var assignments: [CalendarAssignment] = []
    public var reminderAssignments: [CalendarAssignment] = []

    public init(groups: [CalendarGroup] = [], assignments: [CalendarAssignment] = [], reminderAssignments: [CalendarAssignment] = []) {
        self.groups = groups
        self.assignments = assignments
        self.reminderAssignments = reminderAssignments
    }
}

public class CalendarSettingsManager: ObservableObject {
    private static let key = "CalendarSettingsData"

    @Published public var data: CalendarSettingsData {
        didSet { save() }
    }

    public init() {
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
