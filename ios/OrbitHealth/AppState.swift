import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var profile: BirthProfile?
    @Published var healthSummary: HealthSummary?
    @Published var report: DailyReport?
    @Published var isLoading = false
    @Published var loadingMessage = "正在校准八字与当日节气"
    @Published var errorMessage: String?
    @Published var usesDemoHealthData: Bool
    let healthKit = HealthKitService()
    private let api = FortuneAPI()
    private let analysisContentVersion = "2026-08-16-v2"
    private var loadingMessageTask: Task<Void, Never>?

    init() {
        profile = UserDefaults.standard.data(forKey: "orbit.birth-profile").flatMap { try? JSONDecoder().decode(BirthProfile.self, from: $0) }
        usesDemoHealthData = UserDefaults.standard.bool(forKey: "orbit.uses-demo-health-data")
        if usesDemoHealthData {
            healthSummary = .demo()
        }
    }

    func save(profile: BirthProfile) {
        self.profile = profile
        if let data = try? JSONEncoder().encode(profile) { UserDefaults.standard.set(data, forKey: "orbit.birth-profile") }
    }

    func setUsesDemoHealthData(_ enabled: Bool) {
        usesDemoHealthData = enabled
        UserDefaults.standard.set(enabled, forKey: "orbit.uses-demo-health-data")
        healthSummary = enabled ? .demo() : nil
    }

    func authorizeHealthAndRefresh() async {
        guard !usesDemoHealthData else {
            errorMessage = "请先关闭演示健康数据，才能读取 Apple 健康。"
            return
        }
        await healthKit.requestAuthorization()
        guard case .authorized = healthKit.authorizationState else { return }
        healthSummary = await healthKit.todaySummary()
        clearTodayReportCache()
        await refresh(force: true)
    }

    func healthDataStatusText() -> String {
        guard let healthSummary else { return "已授权，但今天暂无可读取的汇总数据" }
        let count = [
            healthSummary.steps,
            healthSummary.activeEnergyKcal.map { Int($0) },
            healthSummary.sleepHours.map { Int($0) },
            healthSummary.restingHeartRate.map { Int($0) },
            healthSummary.heartRateVariability.map { Int($0) },
            healthSummary.workoutMinutes,
        ].compactMap { $0 }.count
        return count > 0 ? "已读取 \(count) 项今日健康汇总，正在用于生成建议" : "已授权，但今天暂无可读取的汇总数据"
    }

    private func clearTodayReportCache() {
        UserDefaults.standard.removeObject(forKey: "orbit.report-date")
        UserDefaults.standard.removeObject(forKey: "orbit.report")
    }

    func refreshIfNeeded(force: Bool = false) async {
        guard let profile else { return }
        let today = HealthKitService.dateFormatterString(Date())
        if !force, UserDefaults.standard.string(forKey: "orbit.analysis-content-version") == analysisContentVersion,
           let cachedDate = UserDefaults.standard.string(forKey: "orbit.report-date"), cachedDate == today,
           let cached = UserDefaults.standard.data(forKey: "orbit.report"), let report = try? JSONDecoder().decode(DailyReport.self, from: cached), report.analysis != nil, report.fortune.overallScore > 10 {
            // The report can remain cached for the day, but HealthKit values are
            // live and change throughout the day. Refresh the metrics separately.
            if !usesDemoHealthData {
                await healthKit.requestAuthorization()
                if case .authorized = healthKit.authorizationState {
                    healthSummary = await healthKit.todaySummary()
                }
            }
            self.report = report
            return
        }
        await refresh(profile: profile, today: today)
    }

    func refresh(profile: BirthProfile? = nil, today: String? = nil) async {
        guard let profile = profile ?? self.profile else { return }
        isLoading = true; errorMessage = nil
        beginLoadingMessages()
        if usesDemoHealthData {
            healthSummary = .demo()
        } else {
            await healthKit.requestAuthorization()
            healthSummary = await healthKit.todaySummary()
        }
        do {
            let envelope = try await api.calculate(profile: profile, health: healthSummary)
            guard let report = envelope.data else { throw APIError.invalidResponse }
            self.report = report
            let date = today ?? report.date
            UserDefaults.standard.set(date, forKey: "orbit.report-date")
            if let data = try? JSONEncoder().encode(report) {
                UserDefaults.standard.set(data, forKey: "orbit.report")
            }
            UserDefaults.standard.set(analysisContentVersion, forKey: "orbit.analysis-content-version")
        } catch {
            errorMessage = error.localizedDescription
        }
        loadingMessageTask?.cancel()
        isLoading = false
    }

    func refresh(force: Bool) async {
        await refreshIfNeeded(force: force)
    }

    func interpretSign(_ sign: FortuneSign) async -> String {
        (try? await api.interpret(sign: sign, profile: profile)) ?? sign.interpretation
    }

    private func beginLoadingMessages() {
        loadingMessageTask?.cancel()
        loadingMessage = "正在校准八字与当日节气"
        loadingMessageTask = Task { [weak self] in
            let messages = [
                "正在融合今日黄历与空间提示",
                "正在读取已授权的生活节奏摘要",
                "正在生成今天的专属建议",
            ]
            for message in messages {
                try? await Task.sleep(for: .seconds(1.35))
                guard !Task.isCancelled else { return }
                self?.loadingMessage = message
            }
        }
    }
}

extension HealthKitService {
    static func dateFormatterString(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian); formatter.timeZone = TimeZone(identifier: "Asia/Shanghai"); formatter.dateFormat = "yyyy-MM-dd"; return formatter.string(from: date)
    }
}
