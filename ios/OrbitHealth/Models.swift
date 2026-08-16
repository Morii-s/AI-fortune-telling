import Foundation

struct BirthProfile: Codable, Equatable {
    var birthYear: Int
    var birthMonth: Int
    var birthDay: Int
    var birthHour: Int
    var gender: String
    var birthPlace: String

    enum CodingKeys: String, CodingKey {
        case birthYear = "birth_year", birthMonth = "birth_month", birthDay = "birth_day"
        case birthHour = "birth_hour", gender, birthPlace = "birth_place"
    }
}

struct HealthSummary: Codable, Equatable {
    let date: String
    let steps: Int?
    let activeEnergyKcal: Double?
    let sleepHours: Double?
    let restingHeartRate: Double?
    let heartRateVariability: Double?
    let workoutMinutes: Int?

    enum CodingKeys: String, CodingKey {
        case date, steps
        case activeEnergyKcal = "active_energy_kcal"
        case sleepHours = "sleep_hours"
        case restingHeartRate = "resting_heart_rate"
        case heartRateVariability = "heart_rate_variability"
        case workoutMinutes = "workout_minutes"
    }
}

extension HealthSummary {
    static func demo(for date: Date = Date()) -> HealthSummary {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd"
        return HealthSummary(
            date: formatter.string(from: date),
            steps: 8_420,
            activeEnergyKcal: 436,
            sleepHours: 7.3,
            restingHeartRate: 58,
            heartRateVariability: 46,
            workoutMinutes: 42
        )
    }
}

struct FortuneEnvelope: Decodable {
    let code: Int
    let message: String
    let data: DailyReport?
}

struct DailyReport: Codable, Equatable {
    let date: String
    let fortune: Fortune
    let analysis: Analysis?

    struct Fortune: Codable, Equatable {
    let overallScore: Int
        let overallText: String
        let guidance: [String]?

        enum CodingKeys: String, CodingKey {
            case overallScore = "overall_score", overallText = "overall_text", guidance
        }
    }
}

struct Analysis: Codable, Equatable {
    let disclaimer: String
    let bazi: AnalysisSection
    let meihua: AnalysisSection
    let fengshui: AnalysisSection
    let astrology: AnalysisSection
    let wellbeing: AnalysisSection?
    let actionable: ActionableTips?
}

struct ActionableTips: Codable, Equatable {
    let title: String
    let items: [ActionableTip]
}

struct ActionableTip: Codable, Equatable, Identifiable {
    let label: String
    let value: String
    let icon: String
    let reason: String
    var id: String { label }
}

struct AnalysisSection: Codable, Equatable {
    let title: String
    let summary: String
    let evidence: [String]
    let guidance: String
}

extension DailyReport.Fortune {
    var practicalGuidance: [String] { guidance ?? [] }
}

enum HealthAuthorizationState: Equatable {
    case unavailable, notRequested, authorized, denied, error(String)
}
