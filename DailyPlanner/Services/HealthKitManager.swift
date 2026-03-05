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

    // MARK: - Read permission types
    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        let qIds: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .activeEnergyBurned,
            .appleExerciseTime
        ]
        for id in qIds {
            if let t = HKQuantityType.quantityType(forIdentifier: id) { types.insert(t) }
        }
        types.insert(HKObjectType.workoutType())
        return types
    }

    // MARK: - Request authorisation
    /// Safe to call multiple times — iOS silently skips the dialog if already answered.
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard isAvailable else { completion(false); return }
        store.requestAuthorization(toShare: nil, read: readTypes) { ok, _ in
            DispatchQueue.main.async { completion(ok) }
        }
    }

    // MARK: - Fetch all data for one calendar day
    func fetchAllHealthData(for date: Date, completion: @escaping (HealthKitDayData) -> Void) {
        guard isAvailable else { completion(HealthKitDayData()); return }

        var data = HealthKitDayData()
        let group = DispatchGroup()

        // Steps
        group.enter()
        fetchSum(.stepCount, unit: .count(), date: date) {
            data.steps = Int($0); group.leave()
        }

        // Active calories
        group.enter()
        fetchSum(.activeEnergyBurned, unit: .kilocalorie(), date: date) {
            data.calories = Int($0); group.leave()
        }

        // Workouts (includes walking, running, swimming …)
        group.enter()
        fetchWorkoutSamples(date: date) { workouts in
            data.workouts        = workouts
            data.workoutMinutes  = workouts.reduce(0) { $0 + $1.durationMinutes }
            data.walkingMinutes  = workouts
                .filter { $0.activityType.lowercased().contains("walk") }
                .reduce(0) { $0 + $1.durationMinutes }
            group.leave()
        }

        group.notify(queue: .main) { completion(data) }
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
        let pred = HKQuery.predicateForSamples(withStart: start, end: end)
        let q = HKStatisticsQuery(
            quantityType: type,
            quantitySamplePredicate: pred,
            options: .cumulativeSum
        ) { _, result, _ in
            DispatchQueue.main.async {
                completion(result?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
        }
        store.execute(q)
    }

    // MARK: - Private: workout samples for a day
    private func fetchWorkoutSamples(
        date: Date,
        completion: @escaping ([HealthWorkout]) -> Void
    ) {
        let (start, end) = dayBounds(date)
        let pred = HKQuery.predicateForSamples(withStart: start, end: end)
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
            DispatchQueue.main.async { completion(result) }
        }
        store.execute(q)
    }

    // MARK: - Helper
    private func dayBounds(_ date: Date) -> (Date, Date) {
        let cal   = Calendar.current
        let start = cal.startOfDay(for: date)
        let end   = cal.date(byAdding: .day, value: 1, to: start)!
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
