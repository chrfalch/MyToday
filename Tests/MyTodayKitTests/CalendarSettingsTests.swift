import Foundation
import Testing
@testable import MyTodayKit

@Suite("CalendarSettingsData Tests")
struct CalendarSettingsDataTests {

    @Test("Empty data has no groups or assignments")
    func emptyInit() {
        let data = CalendarSettingsData()
        #expect(data.groups.isEmpty)
        #expect(data.assignments.isEmpty)
        #expect(data.reminderAssignments.isEmpty)
    }

    @Test("CalendarGroup round-trips through Codable")
    func groupCodable() throws {
        let group = CalendarGroup(id: UUID(), name: "Work", sortOrder: 0)
        let encoded = try JSONEncoder().encode(group)
        let decoded = try JSONDecoder().decode(CalendarGroup.self, from: encoded)
        #expect(decoded.name == "Work")
        #expect(decoded.sortOrder == 0)
        #expect(decoded.id == group.id)
    }

    @Test("CalendarAssignment round-trips through Codable")
    func assignmentCodable() throws {
        let groupID = UUID()
        let assignment = CalendarAssignment(id: "cal-123", isVisible: true, groupID: groupID)
        let encoded = try JSONEncoder().encode(assignment)
        let decoded = try JSONDecoder().decode(CalendarAssignment.self, from: encoded)
        #expect(decoded.id == "cal-123")
        #expect(decoded.isVisible == true)
        #expect(decoded.groupID == groupID)
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
        #expect(manager.data.groups.isEmpty)
    }

    @Test("addGroup appends a group with correct sort order")
    func addGroup() {
        let manager = freshManager()
        manager.addGroup(name: "Work")
        manager.addGroup(name: "Personal")

        #expect(manager.data.groups.count == 2)
        #expect(manager.data.groups[0].name == "Work")
        #expect(manager.data.groups[0].sortOrder == 0)
        #expect(manager.data.groups[1].name == "Personal")
        #expect(manager.data.groups[1].sortOrder == 1)
    }

    @Test("deleteGroup removes the group and unsets assignments")
    func deleteGroup() {
        let manager = freshManager()
        manager.addGroup(name: "Work")
        let groupID = manager.data.groups[0].id

        // Add an assignment linked to the group
        manager.data.assignments = [
            CalendarAssignment(id: "cal-1", isVisible: true, groupID: groupID)
        ]

        manager.deleteGroup(id: groupID)
        #expect(manager.data.groups.isEmpty)
        #expect(manager.data.assignments[0].groupID == nil)
    }

    @Test("setVisibility toggles calendar visibility")
    func setVisibility() {
        let manager = freshManager()
        manager.data.assignments = [
            CalendarAssignment(id: "cal-1", isVisible: true, groupID: nil)
        ]

        manager.setVisibility(calendarID: "cal-1", visible: false)
        #expect(manager.data.assignments[0].isVisible == false)

        manager.setVisibility(calendarID: "cal-1", visible: true)
        #expect(manager.data.assignments[0].isVisible == true)
    }
}
