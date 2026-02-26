import Foundation
import EventKit
import Combine

public enum EventType {
    case meeting  // has attendees/invites
    case place    // has a location but no attendees
    case task     // no attendees, no location

    public var sfSymbol: String {
        switch self {
        case .meeting: return "person.2.fill"
        case .place:   return "mappin.fill"
        case .task:    return "checklist"
        }
    }

    public var emoji: String {
        switch self {
        case .meeting: return "👥"
        case .place:   return "📍"
        case .task:    return "📋"
        }
    }
}

extension EKEvent {
    public var eventType: EventType {
        let hasAttendees = attendees.map { !$0.isEmpty } ?? false
        let hasLocation = location.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false
        if hasAttendees { return .meeting }
        if hasLocation  { return .place }
        return .task
    }
}

public struct GroupedEvents: Identifiable {
    public var id: UUID?
    public var groupName: String
    public var events: [EKEvent]

    public init(id: UUID? = nil, groupName: String, events: [EKEvent]) {
        self.id = id
        self.groupName = groupName
        self.events = events
    }
}

public struct ReminderListSummary: Identifiable {
    public var id: String // calendar identifier
    public var listName: String
    public var color: CGColor
    public var externalIdentifier: String?
    public var overdueCount: Int
    public var undatedCount: Int

    public init(id: String, listName: String, color: CGColor, externalIdentifier: String?, overdueCount: Int, undatedCount: Int) {
        self.id = id
        self.listName = listName
        self.color = color
        self.externalIdentifier = externalIdentifier
        self.overdueCount = overdueCount
        self.undatedCount = undatedCount
    }
}

public class EventManager: ObservableObject {
    public let store = EKEventStore()

    @Published public var todaysEvents: [EKEvent] = []
    @Published public var groupedEvents: [GroupedEvents] = []
    @Published public var nextEvent: EKEvent? = nil
    @Published public private(set) var overdueReminders: Int = 0
    @Published public private(set) var undatedReminders: Int = 0
    @Published public var reminderListSummaries: [ReminderListSummary] = []
    @Published public var calendarAccessGranted = false
    @Published public var reminderAccessGranted = false

    public var settingsManager: CalendarSettingsManager? {
        didSet { subscribeToSettings() }
    }

    private var settingsCancellable: AnyCancellable?
    private var storeChangedCancellable: AnyCancellable?

    public init() {}

    private func subscribeToSettings() {
        settingsCancellable = settingsManager?.objectWillChange
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    public func startObservingStoreChanges() {
        storeChangedCancellable = NotificationCenter.default
            .publisher(for: .EKEventStoreChanged, object: store)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    public func requestAccess(completion: @escaping () -> Void) {
        let group = DispatchGroup()

        group.enter()
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { granted, _ in
                DispatchQueue.main.async { self.calendarAccessGranted = granted }
                group.leave()
            }
        } else {
            store.requestAccess(to: .event) { granted, _ in
                DispatchQueue.main.async { self.calendarAccessGranted = granted }
                group.leave()
            }
        }

        group.enter()
        if #available(macOS 14.0, *) {
            store.requestFullAccessToReminders { granted, _ in
                DispatchQueue.main.async { self.reminderAccessGranted = granted }
                group.leave()
            }
        } else {
            store.requestAccess(to: .reminder) { granted, _ in
                DispatchQueue.main.async { self.reminderAccessGranted = granted }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.refresh()
            completion()
        }
    }

    public func refresh() {
        fetchEvents()
        fetchReminders()
    }

    func fetchEvents() {
        guard calendarAccessGranted else { return }

        // Sync settings with current system calendars
        let systemCalendars = store.calendars(for: .event)
        settingsManager?.syncWithSystemCalendars(systemCalendars)

        let now = Date()
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now)!

        // Use visible calendars from settings if available, otherwise nil (all)
        let calendars: [EKCalendar]? = settingsManager?.visibleCalendars(from: store)

        let predicate = store.predicateForEvents(withStart: now, end: endOfDay, calendars: calendars)
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        DispatchQueue.main.async {
            self.todaysEvents = events
            self.nextEvent = events.first(where: { $0.startDate > now || ($0.startDate <= now && $0.endDate > now) })
            self.buildGroupedEvents(from: events)
        }
    }

    private func buildGroupedEvents(from events: [EKEvent]) {
        guard let settings = settingsManager else {
            groupedEvents = [GroupedEvents(id: nil, groupName: "Today", events: events)]
            return
        }

        let groups = settings.data.groups.sorted { $0.sortOrder < $1.sortOrder }
        let assignmentsByCalID = Dictionary(uniqueKeysWithValues: settings.data.assignments.map { ($0.id, $0) })

        var buckets: [UUID?: [EKEvent]] = [:]
        for event in events {
            let calID = event.calendar.calendarIdentifier
            let groupID = assignmentsByCalID[calID]?.groupID
            buckets[groupID, default: []].append(event)
        }

        var result: [GroupedEvents] = []
        for group in groups {
            if let groupEvents = buckets[group.id], !groupEvents.isEmpty {
                result.append(GroupedEvents(id: group.id, groupName: group.name, events: groupEvents))
            }
        }
        if let ungrouped = buckets[nil], !ungrouped.isEmpty {
            let name = groups.isEmpty ? "Today" : "Other"
            result.append(GroupedEvents(id: nil, groupName: name, events: ungrouped))
        }

        groupedEvents = result
    }

    func fetchReminders() {
        guard reminderAccessGranted else { return }

        // Sync settings with current system reminder lists
        let systemReminderLists = store.calendars(for: .reminder)
        settingsManager?.syncWithSystemReminderLists(systemReminderLists)

        let now = Date()
        let calendars: [EKCalendar]? = settingsManager?.visibleReminderLists(from: store)
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: calendars)
        store.fetchReminders(matching: predicate) { reminders in
            guard let reminders = reminders else { return }

            var totalOverdue = 0
            var totalUndated = 0
            var perList: [String: (name: String, color: CGColor, externalID: String?, overdue: Int, undated: Int)] = [:]

            for r in reminders {
                let calID = r.calendar.calendarIdentifier
                var entry = perList[calID] ?? (name: r.calendar.title, color: r.calendar.cgColor ?? CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1), externalID: r.calendar.calendarIdentifier, overdue: 0, undated: 0)

                if r.dueDateComponents == nil {
                    entry.undated += 1
                    totalUndated += 1
                } else if let due = Calendar.current.date(from: r.dueDateComponents!), due < now {
                    entry.overdue += 1
                    totalOverdue += 1
                }

                perList[calID] = entry
            }

            let summaries = perList
                .filter { $0.value.overdue > 0 || $0.value.undated > 0 }
                .map { ReminderListSummary(id: $0.key, listName: $0.value.name, color: $0.value.color, externalIdentifier: $0.value.externalID, overdueCount: $0.value.overdue, undatedCount: $0.value.undated) }
                .sorted { $0.listName.localizedCaseInsensitiveCompare($1.listName) == .orderedAscending }

            DispatchQueue.main.async {
                self.overdueReminders = totalOverdue
                self.undatedReminders = totalUndated
                self.reminderListSummaries = summaries
            }
        }
    }

    public func statusBarTitle() -> String {
        guard calendarAccessGranted else { return "📅 No Access" }
        guard let next = nextEvent else { return "📅 No more events" }
        let now = Date()
        let icon = next.eventType.emoji
        if next.startDate <= now && next.endDate > now {
            return "🟢 \(icon) \(next.title ?? "Event")"
        }
        let mins = Int(next.startDate.timeIntervalSince(now) / 60)
        if mins < 60 {
            return "\(icon) \(next.title ?? "Event") in \(mins)m"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(icon) \(next.title ?? "Event") at \(formatter.string(from: next.startDate))"
    }
}
