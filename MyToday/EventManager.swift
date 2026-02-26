import Foundation
import EventKit
import Combine

class EventManager: ObservableObject {
    let store = EKEventStore()
    
    @Published var todaysEvents: [EKEvent] = []
    @Published var nextEvent: EKEvent? = nil
    @Published var overdueReminders: Int = 0
    @Published var undatedReminders: Int = 0
    @Published var calendarAccessGranted = false
    @Published var reminderAccessGranted = false

    func requestAccess(completion: @escaping () -> Void) {
        let group = DispatchGroup()

        group.enter()
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { granted, _ in
                self.calendarAccessGranted = granted
                group.leave()
            }
        } else {
            store.requestAccess(to: .event) { granted, _ in
                self.calendarAccessGranted = granted
                group.leave()
            }
        }

        group.enter()
        if #available(macOS 14.0, *) {
            store.requestFullAccessToReminders { granted, _ in
                self.reminderAccessGranted = granted
                group.leave()
            }
        } else {
            store.requestAccess(to: .reminder) { granted, _ in
                self.reminderAccessGranted = granted
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.refresh()
            completion()
        }
    }

    func refresh() {
        fetchEvents()
        fetchReminders()
    }

    func fetchEvents() {
        guard calendarAccessGranted else { return }
        let now = Date()
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now)!
        
        let predicate = store.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        DispatchQueue.main.async {
            self.todaysEvents = events
            self.nextEvent = events.first(where: { $0.startDate > now || ($0.startDate <= now && $0.endDate > now) })
        }
    }

    func fetchReminders() {
        guard reminderAccessGranted else { return }
        let now = Date()
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        store.fetchReminders(matching: predicate) { reminders in
            guard let reminders = reminders else { return }
            let overdue = reminders.filter { r in
                if let due = r.dueDateComponents?.date {
                    return due < now
                }
                return false
            }.count
            let undated = reminders.filter { $0.dueDateComponents == nil }.count
            DispatchQueue.main.async {
                self.overdueReminders = overdue
                self.undatedReminders = undated
            }
        }
    }

    func statusBarTitle() -> String {
        guard calendarAccessGranted else { return "📅 No Access" }
        guard let next = nextEvent else { return "📅 No more meetings" }
        let now = Date()
        if next.startDate <= now && next.endDate > now {
            return "🟢 \(next.title ?? "Meeting")"
        }
        let mins = Int(next.startDate.timeIntervalSince(now) / 60)
        if mins < 60 {
            return "📅 \(next.title ?? "Meeting") in \(mins)m"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "📅 \(next.title ?? "Meeting") at \(formatter.string(from: next.startDate))"
    }
}

extension EKCalendarItem {
    var title: String? { return (self as? EKEvent)?.title ?? (self as? EKReminder)?.title }
}

extension DateComponents {
    var date: Date? {
        return Calendar.current.date(from: self)
    }
}
