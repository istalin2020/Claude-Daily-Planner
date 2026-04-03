import Foundation
import HealthKit

// MARK: - HealthKit Day Data (returned from a single sync)
struct HealthKitDayData {
    var steps: Int = 0
    var calories: Int = 0
    var workoutMinutes: Int = 0
    var walkingMinutes: Int = 0
    var workouts: [HealthWorkout] = []
}

// MARK: - HealthKit Manager
final class HealthKitManager {

    static let shared = HealthKitManager()
    private init() {}

    private let store = HKHealthStore()

    /// false on Simulator — HealthKit is only available on real iPhone/Apple Watch
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// true when the user has explicitly denied step-count access in Settings.
    var isStepCountAuthDenied: Bool {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return false }
        return store.authorizationStatus(for: stepType) == .sharingDenied
    }

    // Active observer queries — kept so they can be stopped if needed.
    private var observerQueries: [HKQuery] = []

    // Lock protecting concurrent writes inside fetchAllHealthData callbacks.
    private let dataLock = NSLock()

    // MARK: - Read permission types
    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        let qIds: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .activeEnergyBurned,
            .appleExerciseTime,
            .distanceWalkingRunning
        ]
        for id in qIds {
            if let t = HKQuantityType.quantityType(forIdentifier: id) { types.insert(t) }
        }
        types.insert(HKObjectType.workoutType())
        // Sleep analysis
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        return types
    }

    // MARK: - Request authorisation
    /// Requests HealthKit access and always calls completion on the main thread.
    /// Safe to call multiple times — HealthKit is idempotent once authorised.
    func requestAuthorization(completion: @escaping () -> Void) {
        guard isAvailable else { DispatchQueue.main.async { completion() }; return }
        store.requestAuthorization(toShare: nil, read: readTypes) { _, _ in
            // Ignore success/error — always proceed. HealthKit returns empty
            // data for denied types; attempting the fetch is always safe.
            DispatchQueue.main.async { completion() }
        }
    }

    // MARK: - Observer Queries + Background Delivery
    /// Registers HKObserverQuery for every tracked data type so the app
    /// receives a callback whenever Apple Health data changes — including
    /// updates from the Health app, Apple Watch, or third-party apps.
    /// Also enables background delivery so updates arrive while backgrounded.
    /// Safe to call multiple times (stops existing observers first).
    func startObservingHealthData(onUpdate: @escaping () -> Void) {
        guard isAvailable else { return }

        // Stop any previously registered observers before creating new ones.
        for query in observerQueries { store.stop(query) }
        observerQueries.removeAll()

        let quantityIds: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .appleExerciseTime, .distanceWalkingRunning
        ]

        for id in quantityIds {
            guard let sampleType = HKQuantityType.quantityType(forIdentifier: id) else { continue }

            // Enable background delivery so we get woken up when data arrives
            // even if the app has been suspended by the OS.
            store.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { _, _ in }

            let observer = HKObserverQuery(sampleType: sampleType, predicate: nil) { _, completionHandler, error in
                defer { completionHandler() }
                guard error == nil else { return }
                DispatchQueue.main.async { onUpdate() }
            }
            store.execute(observer)
            observerQueries.append(observer)
        }

        // Observe workout-type samples separately (not a quantity type).
        store.enableBackgroundDelivery(for: .workoutType(), frequency: .immediate) { _, _ in }
        let workoutObserver = HKObserverQuery(sampleType: .workoutType(), predicate: nil) { _, completionHandler, error in
            defer { completionHandler() }
            guard error == nil else { return }
            DispatchQueue.main.async { onUpdate() }
        }
        store.execute(workoutObserver)
        observerQueries.append(workoutObserver)
    }

    // MARK: - Fetch all data for one calendar day
    func fetchAllHealthData(for date: Date, completion: @escaping (HealthKitDayData) -> Void) {
        guard isAvailable else { completion(HealthKitDayData()); return }

        var data = HealthKitDayData()
        let group = DispatchGroup()

        // Intermediate values used to derive walkingMinutes in the notify block.
        var walkingFromSessions: Int = 0
        var walkingDistanceKm: Double = 0

        // Steps
        group.enter()
        fetchSum(.stepCount, unit: .count(), date: date) { [weak self] value in
            self?.dataLock.lock(); data.steps = Int(value); self?.dataLock.unlock()
            group.leave()
        }

        // Active calories
        group.enter()
        fetchSum(.activeEnergyBurned, unit: .kilocalorie(), date: date) { [weak self] value in
            self?.dataLock.lock(); data.calories = Int(value); self?.dataLock.unlock()
            group.leave()
        }

        // Apple Exercise Time — matches the Exercise ring in Apple Health exactly.
        // Covers brisk walks, workouts, and any activity ≥ 3 METs even when
        // no explicit HKWorkout session was saved (e.g. iPhone passive tracking).
        group.enter()
        fetchSum(.appleExerciseTime, unit: .minute(), date: date) { [weak self] value in
            self?.dataLock.lock(); data.workoutMinutes = Int(value); self?.dataLock.unlock()
            group.leave()
        }

        // Walking/running distance — used to estimate walking time when no
        // formal walking workout session exists (iPhone passive step tracking).
        group.enter()
        fetchSum(.distanceWalkingRunning, unit: .meterUnit(with: .kilo), date: date) { [weak self] km in
            self?.dataLock.lock(); walkingDistanceKm = km; self?.dataLock.unlock()
            group.leave()
        }

        // Workout samples — drives the "From Apple Health" list and session-based
        // walking minutes (Apple Watch auto-detected walks).
        group.enter()
        fetchWorkoutSamples(date: date) { [weak self] workouts in
            let walking = workouts
                .filter { $0.activityType.lowercased().contains("walk") }
                .reduce(0) { $0 + $1.durationMinutes }
            self?.dataLock.lock()
            data.workouts = workouts
            walkingFromSessions = walking
            self?.dataLock.unlock()
            group.leave()
        }

        group.notify(queue: .main) {
            // Prefer explicit walking sessions; fall back to distance-based estimate
            // at average walking pace of 5 km/h (12 min per km).
            if walkingFromSessions > 0 {
                data.walkingMinutes = walkingFromSessions
            } else if walkingDistanceKm > 0 {
                data.walkingMinutes = Int(walkingDistanceKm * 12)
            }
            completion(data)
        }
    }

    // MARK: - Private: cumulative quantity sum for a day
    private func fetchSum(
        _ id: HKQuantityTypeIdentifier,
        unit: HKUnit,
        date: Date,
        completion: @escaping (Double) -> Void
    ) {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else {
            completion(0); return
        }
        let (start, end) = dayBounds(date)
        // .strictStartDate ensures samples that started before midnight are excluded,
        // preventing double-counting across day boundaries.
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let q = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: pred,
            options: .cumulativeSum
        ) { _, result, _ in
            // Call completion directly on the HealthKit background thread.
            // group.leave() will be called there; group.notify(queue:.main) still
            // delivers the final result on the main thread.
            completion(result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
        }
        store.execute(q)
    }

    // MARK: - Private: workout samples for a day
    private func fetchWorkoutSamples(
        date: Date,
        completion: @escaping ([HealthWorkout]) -> Void
    ) {
        let (start, end) = dayBounds(date)
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        let q = HKSampleQuery(
            sampleType: .workoutType(),
            predicate: pred,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: sort
        ) { _, samples, _ in
            let raw = (samples as? [HKWorkout]) ?? []
            let result = raw.map { w -> HealthWorkout in
                HealthWorkout(
                    activityType: w.workoutActivityType.displayName,
                    icon:         w.workoutActivityType.sfSymbol,
                    durationMinutes: max(1, Int(w.duration / 60)),
                    calories:     Int(w.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0),
                    startTime:    w.startDate
                )
            }
            completion(result)
        }
        store.execute(q)
    }

    // MARK: - Sleep Data
    /// Fetches sleep analysis data from Apple Health for the given date.
    /// Looks at a 28-hour window (prior noon to next noon) to capture overnight sleep.
    /// Calls completion on the main thread with (bedtime, wakeTime, totalSleepSeconds).
    func fetchSleepData(for date: Date, completion: @escaping (Date?, Date?, TimeInterval) -> Void) {
        guard isAvailable else { completion(nil, nil, 0); return }
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            completion(nil, nil, 0); return
        }

        let cal = Calendar.current
        // Window: noon the day before → noon the day after, capturing overnight sleep
        let dayStart = cal.startOfDay(for: date)
        let windowStart = cal.date(byAdding: .hour, value: -12, to: dayStart) ?? dayStart
        let windowEnd   = cal.date(byAdding: .hour, value: 20, to: dayStart) ?? dayStart

        let pred = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: [])
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        let query = HKSampleQuery(
            sampleType: sleepType,
            predicate: pred,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: sort
        ) { _, samples, _ in
            let sleepSamples = (samples as? [HKCategorySample]) ?? []

            // Values that represent actual sleep (exclude just "in bed")
            var asleepValues: Set<Int>
            if #available(iOS 16.0, *) {
                asleepValues = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
            } else {
                asleepValues = [HKCategoryValueSleepAnalysis.asleep.rawValue]
            }
            let inBedValue = HKCategoryValueSleepAnalysis.inBed.rawValue

            // Prefer asleep samples; fall back to in-bed if no asleep data
            let asleepSamples = sleepSamples.filter { asleepValues.contains($0.value) }
            let relevantSamples = asleepSamples.isEmpty
                ? sleepSamples.filter { $0.value == inBedValue }
                : asleepSamples

            guard !relevantSamples.isEmpty else {
                DispatchQueue.main.async { completion(nil, nil, 0) }
                return
            }

            let bedtime  = relevantSamples.min(by: { $0.startDate < $1.startDate })?.startDate
            let wakeTime = relevantSamples.max(by: { $0.endDate   < $1.endDate   })?.endDate
            let totalSeconds = relevantSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

            DispatchQueue.main.async { completion(bedtime, wakeTime, totalSeconds) }
        }
        store.execute(query)
    }

    // MARK: - Helper
    private func dayBounds(_ date: Date) -> (Date, Date) {
        let cal   = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        return (start, end)
    }
}

// MARK: - HKWorkoutActivityType display helpers
extension HKWorkoutActivityType {

    var displayName: String {
        switch self {
        case .running:                        return "Running"
        case .walking:                        return "Walking"
        case .swimming:                       return "Swimming"
        case .cycling:                        return "Cycling"
        case .yoga:                           return "Yoga"
        case .functionalStrengthTraining,
             .traditionalStrengthTraining:    return "Strength Training"
        case .highIntensityIntervalTraining:  return "HIIT"
        case .hiking:                         return "Hiking"
        case .tennis:                         return "Tennis"
        case .basketball:                     return "Basketball"
        case .soccer:                         return "Soccer"
        case .rowing:                         return "Rowing"
        case .elliptical:                     return "Elliptical"
        case .stairClimbing:                  return "Stair Climbing"
        case .dance:                          return "Dancing"
        case .pilates:                        return "Pilates"
        case .boxing:                         return "Boxing"
        case .cricket:                        return "Cricket"
        case .badminton:                      return "Badminton"
        case .crossTraining:                  return "Cross Training"
        case .coreTraining:                   return "Core Training"
        case .jumpRope:                       return "Jump Rope"
        default:                              return "Workout"
        }
    }

    var sfSymbol: String {
        switch self {
        case .running:                        return "figure.run"
        case .walking:                        return "figure.walk"
        case .swimming:                       return "figure.pool.swim"
        case .cycling:                        return "figure.outdoor.cycle"
        case .yoga:                           return "figure.mind.and.body"
        case .functionalStrengthTraining,
             .traditionalStrengthTraining:    return "dumbbell.fill"
        case .highIntensityIntervalTraining:  return "bolt.heart.fill"
        case .hiking:                         return "figure.hiking"
        case .stairClimbing:                  return "figure.stair.stepper"
        case .dance:                          return "figure.dance"
        case .pilates:                        return "figure.pilates"
        case .boxing:                         return "figure.boxing"
        case .elliptical:                     return "figure.elliptical"
        case .rowing:                         return "figure.rowing"
        case .tennis:                         return "figure.tennis"
        case .basketball:                     return "figure.basketball"
        case .soccer:                         return "figure.soccer"
        default:                              return "heart.fill"
        }
    }
}
