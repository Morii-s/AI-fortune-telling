import Foundation
import Combine
import HealthKit

@MainActor
final class HealthKitService: ObservableObject {
    @Published private(set) var authorizationState: HealthAuthorizationState = .notRequested
    private let store = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKCategoryType(.sleepAnalysis),
            HKObjectType.workoutType(),
        ]
    }

    init() {
        if !HKHealthStore.isHealthDataAvailable() { authorizationState = .unavailable }
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { authorizationState = .unavailable; return }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            // HealthKit deliberately does not reveal read authorization per type.
            authorizationState = .authorized
        } catch {
            authorizationState = .error(error.localizedDescription)
        }
    }

    func todaySummary() async -> HealthSummary? {
        guard HKHealthStore.isHealthDataAvailable() else { return nil }
        let interval = Calendar.current.dateInterval(of: .day, for: Date())!
        async let stepsValue = quantitySum(.stepCount, unit: .count(), interval: interval)
        async let energy = quantitySum(.activeEnergyBurned, unit: .kilocalorie(), interval: interval)
        async let resting = latestQuantity(.restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), interval: interval)
        async let hrv = latestQuantity(.heartRateVariabilitySDNN, unit: .secondUnit(with: .milli), interval: interval)
        // Sleep is usually recorded before today's calendar midnight. Use the
        // previous evening through now, rather than a fixed morning-only slice.
        async let sleep = sleepHours(endingAt: min(Date(), interval.end), dayStart: interval.start)
        async let workout = workoutMinutes(interval: interval)
        let steps = await stepsValue.map { Int($0) }
        return await HealthSummary(
            date: Self.dateFormatter.string(from: Date()), steps: steps, activeEnergyKcal: energy,
            sleepHours: sleep, restingHeartRate: resting, heartRateVariability: hrv, workoutMinutes: workout
        )
    }

    private func quantitySum(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, interval: DateInterval) async -> Double? {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: HKQuantityType(identifier), quantitySamplePredicate: HKQuery.predicateForSamples(withStart: interval.start, end: interval.end), options: .cumulativeSum) { _, result, _ in
                continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func latestQuantity(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, interval: DateInterval) async -> Double? {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKQuantityType(identifier), predicate: HKQuery.predicateForSamples(withStart: interval.start, end: interval.end), limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func sleepHours(endingAt end: Date, dayStart: Date) async -> Double? {
        let start = Calendar.current.date(byAdding: .hour, value: -18, to: dayStart)!
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKCategoryType(.sleepAnalysis), predicate: HKQuery.predicateForSamples(withStart: start, end: end), limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let intervals = (samples as? [HKCategorySample] ?? [])
                    .filter { asleepValues.contains($0.value) }
                    .map { (start: max($0.startDate, start), end: min($0.endDate, end)) }
                    .filter { $0.end > $0.start }
                    .sorted { $0.start < $1.start }

                // Samples from multiple devices/sources can overlap. Merge them
                // before summing so the same minutes are never counted twice.
                var merged: [(start: Date, end: Date)] = []
                for interval in intervals {
                    guard let last = merged.last else { merged.append(interval); continue }
                    if interval.start <= last.end {
                        merged[merged.count - 1].end = max(last.end, interval.end)
                    } else {
                        merged.append(interval)
                    }
                }
                let seconds = merged.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
                continuation.resume(returning: seconds > 0 ? min(seconds / 3600, 16) : nil)
            }
            store.execute(query)
        }
    }

    private func workoutMinutes(interval: DateInterval) async -> Int? {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: HKQuery.predicateForSamples(withStart: interval.start, end: interval.end), limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let minutes = (samples as? [HKWorkout] ?? []).reduce(0) { $0 + Int($1.duration / 60) }
                continuation.resume(returning: minutes > 0 ? minutes : nil)
            }
            store.execute(query)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian); formatter.timeZone = TimeZone(identifier: "Asia/Shanghai"); formatter.dateFormat = "yyyy-MM-dd"; return formatter
    }()
}
