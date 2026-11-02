import Foundation
import EventKit
import Testing
@testable import MyTodayKit

@Suite("EventType Tests")
struct EventTypeTests {

    @Test("meeting has correct sfSymbol")
    func meetingSfSymbol() {
        #expect(EventType.meeting.sfSymbol == "person.2.fill")
    }

    @Test("place has correct sfSymbol")
    func placeSfSymbol() {
        #expect(EventType.place.sfSymbol == "mappin.fill")
    }

    @Test("task has correct sfSymbol")
    func taskSfSymbol() {
        #expect(EventType.task.sfSymbol == "checklist")
    }

    @Test("meeting has correct emoji")
    func meetingEmoji() {
        #expect(EventType.meeting.emoji == "👥")
    }

    @Test("place has correct emoji")
    func placeEmoji() {
        #expect(EventType.place.emoji == "📍")
    }

    @Test("task has correct emoji")
    func taskEmoji() {
        #expect(EventType.task.emoji == "📋")
    }
}

@Suite("Status bar pulse Tests")
struct StatusBarPulseTests {

    @Test("pulses between 2 and 1 minutes before start", arguments: [61.0, 90.0, 120.0])
    func pulsesInWindow(seconds: TimeInterval) {
        #expect(StatusBarUrgency.shouldPulse(secondsUntilStart: seconds))
    }

    @Test("does not pulse outside the 2–1 minute window", arguments: [-30.0, 0.0, 30.0, 60.0, 121.0, 300.0])
    func noPulseOutsideWindow(seconds: TimeInterval) {
        #expect(!StatusBarUrgency.shouldPulse(secondsUntilStart: seconds))
    }
}

@Suite("EventWithGroup Tests")
struct EventWithGroupTests {

    @Test("groupName is nil when no groups configured")
    func nilGroupName() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        let item = EventWithGroup(event: event, groupName: nil)
        #expect(item.groupName == nil)
    }

    @Test("groupName is preserved when provided")
    func preservesGroupName() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        let item = EventWithGroup(event: event, groupName: "Work")
        #expect(item.groupName == "Work")
    }

    @Test("event reference is preserved")
    func preservesEvent() {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = "Standup"
        let item = EventWithGroup(event: event, groupName: "Work")
        #expect(item.event.title == "Standup")
    }
}
