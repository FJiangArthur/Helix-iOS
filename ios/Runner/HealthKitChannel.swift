import Foundation
import HealthKit
import Flutter

class HealthKitChannel {
    static let shared = HealthKitChannel()
    private let store = HKHealthStore()

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestAccess":
            requestAccess(result: result)
        case "getTodayStepCount":
            getTodayStepCount(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Authorization

    private func requestAccess(result: @escaping FlutterResult) {
        guard HKHealthStore.isHealthDataAvailable() else {
            result(false)
            return
        }

        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            result(false)
            return
        }

        store.requestAuthorization(toShare: nil, read: [stepType]) { success, error in
            DispatchQueue.main.async { result(success) }
        }
    }

    // MARK: - Steps

    private func getTodayStepCount(result: @escaping FlutterResult) {
        guard HKHealthStore.isHealthDataAvailable() else {
            result(0)
            return
        }

        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            result(0)
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, statistics, error in
            let steps = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
            DispatchQueue.main.async { result(Int(steps)) }
        }

        store.execute(query)
    }
}
