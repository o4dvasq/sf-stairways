import HealthKit

struct HealthKitService {
    static func fetchWalkStats(from start: Date, to end: Date) async -> (steps: Int?, elevationFeet: Double?) {
        guard HKHealthStore.isHealthDataAvailable() else { return (nil, nil) }

        let store = HKHealthStore()
        let stepType = HKQuantityType(.stepCount)
        let flightsType = HKQuantityType(.flightsClimbed)

        let authorized = await requestAuthorization(store: store, types: [stepType, flightsType])
        guard authorized else { return (nil, nil) }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        async let stepsValue = querySum(store: store, type: stepType, predicate: predicate, unit: .count())
        async let flightsValue = querySum(store: store, type: flightsType, predicate: predicate, unit: .count())

        let (steps, flights) = await (stepsValue, flightsValue)

        return (steps.map(Int.init), flights.map { $0 * 10 })
    }

    private static func requestAuthorization(store: HKHealthStore, types: [HKQuantityType]) async -> Bool {
        do {
            try await store.requestAuthorization(toShare: [], read: Set(types))
            return true
        } catch {
            return false
        }
    }

    private static func querySum(
        store: HKHealthStore,
        type: HKQuantityType,
        predicate: NSPredicate,
        unit: HKUnit
    ) async -> Double? {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                continuation.resume(returning: statistics?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }
}
