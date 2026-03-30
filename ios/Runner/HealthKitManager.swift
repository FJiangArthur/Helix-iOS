import Foundation
import HealthKit

/// Provides daily activity data (steps, calories, exercise, stand hours) via HealthKit.
/// Falls back gracefully when HealthKit is unavailable (e.g., simulator).
class HealthKitManager {
    static let shared = HealthKitManager()

    private let healthStore: HKHealthStore?
    private var authorizationRequested = false

    private init() {
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        } else {
            healthStore = nil
        }
    }

    /// Request read authorization for activity data types.
    private func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard let store = healthStore else {
            DispatchQueue.main.async { completion(false) }
            return
        }

        var typesToRead = Set<HKObjectType>()
        let identifiers: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .appleExerciseTime, .appleStandTime
        ]
        for id in identifiers {
            if let t = HKQuantityType.quantityType(forIdentifier: id) {
                typesToRead.insert(t)
            }
        }
        guard !typesToRead.isEmpty else {
            DispatchQueue.main.async { completion(false) }
            return
        }

        store.requestAuthorization(toShare: nil, read: typesToRead) { success, _ in
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    /// Fetch today's activity data. Returns a dictionary with keys:
    /// steps, activeCalories, exerciseMinutes, standHours, stepGoal.
    /// Always dispatches completion on the main thread.
    func getActivityData(completion: @escaping ([String: Any]) -> Void) {
        guard let store = healthStore else {
            DispatchQueue.main.async { completion(self.mockData()) }
            return
        }

        // Request authorization once, then always attempt to fetch.
        // HealthKit returns empty results for denied types without crashing.
        if !authorizationRequested {
            authorizationRequested = true
            requestAuthorization { [weak self] _ in
                // Regardless of auth result, attempt the fetch —
                // HealthKit returns 0 for denied types.
                self?.fetchTodayStats(store: store, completion: completion)
            }
            return
        }

        fetchTodayStats(store: store, completion: completion)
    }

    private func fetchTodayStats(store: HKHealthStore, completion: @escaping ([String: Any]) -> Void) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        let group = DispatchGroup()
        var steps: Double = 0
        var calories: Double = 0
        var exerciseMinutes: Double = 0
        var standMinutes: Double = 0

        // Steps
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            group.enter()
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                group.leave()
            }
            store.execute(query)
        }

        // Active Calories
        if let calType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            group.enter()
            let query = HKStatisticsQuery(quantityType: calType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                calories = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                group.leave()
            }
            store.execute(query)
        }

        // Exercise Time
        if let exType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) {
            group.enter()
            let query = HKStatisticsQuery(quantityType: exType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                exerciseMinutes = result?.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                group.leave()
            }
            store.execute(query)
        }

        // Stand Time
        if let standType = HKQuantityType.quantityType(forIdentifier: .appleStandTime) {
            group.enter()
            let query = HKStatisticsQuery(quantityType: standType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                standMinutes = result?.sumQuantity()?.doubleValue(for: .minute()) ?? 0
                group.leave()
            }
            store.execute(query)
        }

        group.notify(queue: .main) {
            completion([
                "steps": Int(steps),
                "activeCalories": calories,
                "exerciseMinutes": Int(exerciseMinutes),
                "standHours": Int(standMinutes / 60),
                "stepGoal": 10000,
            ])
        }
    }

    private func mockData() -> [String: Any] {
        return [
            "steps": 0,
            "activeCalories": 0.0,
            "exerciseMinutes": 0,
            "standHours": 0,
            "stepGoal": 10000,
        ]
    }
}
