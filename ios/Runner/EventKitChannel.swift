import Foundation
import EventKit
import Flutter

class EventKitChannel {
    static let shared = EventKitChannel()
    private let store = EKEventStore()

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestCalendarAccess":
            requestCalendarAccess(result: result)
        case "getNextCalendarEvent":
            getNextCalendarEvent(result: result)
        case "requestRemindersAccess":
            requestRemindersAccess(result: result)
        case "getUpcomingReminders":
            getUpcomingReminders(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Calendar

    private func requestCalendarAccess(result: @escaping FlutterResult) {
        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents { granted, error in
                DispatchQueue.main.async { result(granted) }
            }
        } else {
            store.requestAccess(to: .event) { granted, error in
                DispatchQueue.main.async { result(granted) }
            }
        }
    }

    private func getNextCalendarEvent(result: @escaping FlutterResult) {
        let status = EKEventStore.authorizationStatus(for: .event)
        let isAuthorized: Bool
        if #available(iOS 17.0, *) {
            isAuthorized = (status == .fullAccess)
        } else {
            isAuthorized = (status == .authorized)
        }
        guard isAuthorized else {
            result(nil)
            return
        }

        let now = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: now)!
        let predicate = store.predicateForEvents(withStart: now, end: endDate, calendars: nil)
        let events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }

        guard let event = events.first else {
            result(nil)
            return
        }

        let formatter = ISO8601DateFormatter()
        let dict: [String: Any?] = [
            "title": event.title,
            "startDate": formatter.string(from: event.startDate),
            "endDate": formatter.string(from: event.endDate),
            "location": event.location,
            "isAllDay": event.isAllDay
        ]
        result(dict as [String: Any?])
    }

    // MARK: - Reminders

    private func requestRemindersAccess(result: @escaping FlutterResult) {
        if #available(iOS 17.0, *) {
            store.requestFullAccessToReminders { granted, error in
                DispatchQueue.main.async { result(granted) }
            }
        } else {
            store.requestAccess(to: .reminder) { granted, error in
                DispatchQueue.main.async { result(granted) }
            }
        }
    }

    private func getUpcomingReminders(result: @escaping FlutterResult) {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        let isAuthorized: Bool
        if #available(iOS 17.0, *) {
            isAuthorized = (status == .fullAccess)
        } else {
            isAuthorized = (status == .authorized)
        }
        guard isAuthorized else {
            result([])
            return
        }

        let now = Date()
        let endDate = Calendar.current.date(byAdding: .hour, value: 24, to: now)!
        let predicate = store.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: endDate,
            calendars: nil
        )

        store.fetchReminders(matching: predicate) { reminders in
            let formatter = ISO8601DateFormatter()
            let items: [[String: Any?]] = (reminders ?? [])
                .prefix(3)
                .map { reminder in
                    var dueDate: String? = nil
                    if let components = reminder.dueDateComponents,
                       let date = Calendar.current.date(from: components) {
                        dueDate = formatter.string(from: date)
                    }
                    return [
                        "title": reminder.title,
                        "dueDate": dueDate
                    ]
                }
            DispatchQueue.main.async { result(items) }
        }
    }
}
