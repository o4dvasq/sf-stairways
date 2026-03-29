import HealthKit

struct HealthKitService {
    // Returns true if HealthKit is available and authorization has been requested at least once.
    // iOS does not expose read-permission status directly; .unnecessary means the prompt has fired.
    static func isAuthorized() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let store = HKHealthStore()
        let stepType = HKQuantityType(.stepCount)
        let flightsType = HKQuantityType(.flightsClimbed)
        let readTypes: Set<HKObjectType> = [stepType, flightsType]
        let status = try? await store.statusForAuthorizationRequest(toShare: [], read: readTypes)
        return status == .unnecessary
    }

    // Public entry point for requesting authorization from Settings.
    static func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let store = HKHealthStore()
        let stepType = HKQuantityType(.stepCount)
        let flightsType = HKQuantityType(.flightsClimbed)
        _ = await requestAuthorization(store: store, types: [stepType, flightsType])
    }

    static func fetchWalkStats(from start: Date, to end: Date) async -> (steps: Int?, elevationFeet: Double?) {
        print("[HealthKit] fetchWalkStats called: \(start) → \(end)")
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HealthKit] HealthKit not available on this device")
            return (nil, nil)
        }

        let store = HKHealthStore()
        let stepType = HKQuantityType(.stepCount)
        let flightsType = HKQuantityType(.flightsClimbed)

        let authorized = await requestAuthorization(store: store, types: [stepType, flightsType])
        guard authorized else {
            print("[HealthKit] Authorization failed — returning nil")
            return (nil, nil)
        }

        // Short delay to allow HealthKit to flush data recorded during the walk.
        // Queries run immediately after walk end can miss data that hasn't been written yet.
        try? await Task.sleep(for: .seconds(1))

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        async let stepsValue = querySum(store: store, type: stepType, predicate: predicate, unit: .count())
        async let flightsValue = querySum(store: store, type: flightsType, predicate: predicate, unit: .count())

        let (steps, flights) = await (stepsValue, flightsValue)

        print("[HealthKit] Query result — steps: \(steps.map(String.init) ?? "nil"), flights: \(flights.map(String.init) ?? "nil")")

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
