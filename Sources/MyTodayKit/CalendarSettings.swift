import Foundation
import EventKit
import Combine

public struct CalendarAssignment: Codable, Identifiable {
    public var id: String // EKCalendar.calendarIdentifier
    public var isVisible: Bool

    public init(id: String, isVisible: Bool) {
        self.id = id
        self.isVisible = isVisible
    }
}

public struct CalendarSettingsData: Codable {
    public var assignments: [CalendarAssignment] = []
    public var reminderAssignments: [CalendarAssignment] = []

    public init(assignments: [CalendarAssignment] = [], reminderAssignments: [CalendarAssignment] = []) {
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

    // MARK: - Assignment mutations

    func setVisibility(calendarID: String, visible: Bool) {
        if let idx = data.assignments.firstIndex(where: { $0.id == calendarID }) {
            data.assignments[idx].isVisible = visible
        }
    }

    // MARK: - Reminder assignment mutations

    func setReminderVisibility(calendarID: String, visible: Bool) {
        if let idx = data.reminderAssignments.firstIndex(where: { $0.id == calendarID }) {
            data.reminderAssignments[idx].isVisible = visible
        }
    }

    // MARK: - Sync with system calendars

    func syncWithSystemCalendars(_ calendars: [EKCalendar]) {
        let existingIDs = Set(data.assignments.map(\.id))
        for cal in calendars {
            if !existingIDs.contains(cal.calendarIdentifier) {
                data.assignments.append(
                    CalendarAssignment(id: cal.calendarIdentifier, isVisible: true)
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
                    CalendarAssignment(id: cal.calendarIdentifier, isVisible: true)
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
