import EventKit
import Foundation

struct NativeCalendarEvent {
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let isAllDay: Bool
}

struct NativeReminder {
    let title: String
    let dueDate: Date?
}

final class NativeEventKitService {
    static let shared = NativeEventKitService()

    private let store = EKEventStore()

    private init() {}

    func requestCalendarAccess(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
        } else {
            store.requestAccess(to: .event) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }

    func nextCalendarEvent() -> NativeCalendarEvent? {
        let status = EKEventStore.authorizationStatus(for: .event)
        let isAuthorized: Bool
        if #available(iOS 17.0, *) {
            isAuthorized = status == .fullAccess
        } else {
            isAuthorized = status == .authorized
        }
        guard isAuthorized else {
            return nil
        }

        let now = Date()
        guard let endDate = Calendar.current.date(byAdding: .day, value: 7, to: now) else {
            return nil
        }

        let predicate = store.predicateForEvents(withStart: now, end: endDate, calendars: nil)
        return store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .first
            .map {
                NativeCalendarEvent(
                    title: $0.title,
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    location: $0.location,
                    isAllDay: $0.isAllDay
                )
            }
    }

    func requestRemindersAccess(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            store.requestFullAccessToReminders { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
        } else {
            store.requestAccess(to: .reminder) { granted, _ in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }

    func upcomingReminders(completion: @escaping ([NativeReminder]) -> Void) {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        let isAuthorized: Bool
        if #available(iOS 17.0, *) {
            isAuthorized = status == .fullAccess
        } else {
            isAuthorized = status == .authorized
        }
        guard isAuthorized else {
            completion([])
            return
        }

        let now = Date()
        guard let endDate = Calendar.current.date(byAdding: .hour, value: 24, to: now) else {
            completion([])
            return
        }
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: now,
            ending: endDate,
            calendars: nil
        )

        store.fetchReminders(matching: predicate) { reminders in
            let items = (reminders ?? [])
                .prefix(3)
                .map { reminder in
                    NativeReminder(
                        title: reminder.title,
                        dueDate: reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
                    )
                }
            DispatchQueue.main.async { completion(items) }
        }
    }
}
