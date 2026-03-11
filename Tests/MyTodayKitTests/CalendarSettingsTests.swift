import Foundation
import Testing
@testable import MyTodayKit

@Suite("CalendarSettingsData Tests")
struct CalendarSettingsDataTests {

    @Test("Empty data has no assignments")
    func emptyInit() {
        let data = CalendarSettingsData()
        #expect(data.assignments.isEmpty)
        #expect(data.reminderAssignments.isEmpty)
    }

    @Test("CalendarAssignment round-trips through Codable")
    func assignmentCodable() throws {
        let assignment = CalendarAssignment(id: "cal-123", isVisible: true)
        let encoded = try JSONEncoder().encode(assignment)
        let decoded = try JSONDecoder().decode(CalendarAssignment.self, from: encoded)
        #expect(decoded.id == "cal-123")
        #expect(decoded.isVisible == true)
    }
}

@Suite("CalendarSettingsManager Tests", .serialized)
struct CalendarSettingsManagerTests {

    /// Clear persisted state so each test starts fresh.
    private func freshManager() -> CalendarSettingsManager {
        UserDefaults.standard.removeObject(forKey: "CalendarSettingsData")
        return CalendarSettingsManager()
    }

    @Test("Manager initializes with empty data")
    func managerInit() {
        let manager = freshManager()
        #expect(manager.data.assignments.isEmpty)
    }

    @Test("setVisibility toggles calendar visibility")
    func setVisibility() {
        let manager = freshManager()
        manager.data.assignments = [
            CalendarAssignment(id: "cal-1", isVisible: true)
        ]

        manager.setVisibility(calendarID: "cal-1", visible: false)
        #expect(manager.data.assignments[0].isVisible == false)

        manager.setVisibility(calendarID: "cal-1", visible: true)
        #expect(manager.data.assignments[0].isVisible == true)
    }
}
