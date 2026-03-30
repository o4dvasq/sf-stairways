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

    static func fetchWalkStats(from start: Date, to end: Date) async -> (steps: Int?, elevationFeet: Double?, error: String?) {
        print("[HealthKit] fetchWalkStats called: \(start) → \(end)")
        guard HKHealthStore.isHealthDataAvailable() else {
            print("[HealthKit] HealthKit not available on this device")
            return (nil, nil, "HealthKit not available on this device")
        }

        let store = HKHealthStore()
        let stepType = HKQuantityType(.stepCount)
        let flightsType = HKQuantityType(.flightsClimbed)

        // Check authorization status first — avoid re-requesting if already granted,
        // as re-requesting can throw in certain states (background, HealthKit temporarily unavailable).
        let alreadyAuthorized = await isAuthorized()
        if !alreadyAuthorized {
            let granted = await requestAuthorization(store: store, types: [stepType, flightsType])
            guard granted else {
                print("[HealthKit] Authorization failed — returning nil")
                return (nil, nil, "Health access denied — check Settings > Health > SF Stairways")
            }
        }
        print("[HealthKit] Authorization confirmed, querying \(start) → \(end)")

        // Delay to allow HealthKit to flush pedometer data after motion stops.
        // Queries run immediately after walk end can miss data that hasn't been written yet.
        try? await Task.sleep(for: .seconds(2))

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let (steps, flights) = await queryStats(store: store, stepType: stepType, flightsType: flightsType, predicate: predicate)

        let stepsDesc = steps.map { "\(Int($0))" } ?? "nil"
        let flightsDesc = flights.map { "\(Int($0))" } ?? "nil"
        print("[HealthKit] Attempt 1 — steps: \(stepsDesc), flights (raw): \(flightsDesc)")

        if steps != nil || flights != nil {
            return (steps.map(Int.init), flights.map { $0 * 10 }, nil)
        }

        // Retry once — HealthKit may need extra time to flush data for short walks.
        print("[HealthKit] No data on first attempt — retrying in 2s")
        try? await Task.sleep(for: .seconds(2))

        let (steps2, flights2) = await queryStats(store: store, stepType: stepType, flightsType: flightsType, predicate: predicate)

        let stepsDesc2 = steps2.map { "\(Int($0))" } ?? "nil"
        let flightsDesc2 = flights2.map { "\(Int($0))" } ?? "nil"
        print("[HealthKit] Attempt 2 — steps: \(stepsDesc2), flights (raw): \(flightsDesc2)")

        if steps2 == nil && flights2 == nil {
            return (nil, nil, "No step data recorded for this walk (try a longer walk)")
        }
        return (steps2.map(Int.init), flights2.map { $0 * 10 }, nil)
    }

    private static func queryStats(
        store: HKHealthStore,
        stepType: HKQuantityType,
        flightsType: HKQuantityType,
        predicate: NSPredicate
    ) async -> (Double?, Double?) {
        async let stepsValue = querySum(store: store, type: stepType, predicate: predicate, unit: .count())
        async let flightsValue = querySum(store: store, type: flightsType, predicate: predicate, unit: .count())
        return await (stepsValue, flightsValue)
    }

    private static func requestAuthorization(store: HKHealthStore, types: [HKQuantityType]) async -> Bool {
        do {
            try await store.requestAuthorization(toShare: [], read: Set(types))
            return true
        } catch {
            print("[HealthKit] Authorization request threw: \(error)")
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
