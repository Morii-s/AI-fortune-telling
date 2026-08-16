import Foundation

enum APIError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "尚未在应用中配置 DeepSeek API Key"
        case .invalidResponse:
            return "运势服务返回了无效响应"
        case .decoding(let detail):
            return "运势数据格式不兼容：\(detail)"
        }
    }
}

/// The app owns calculation and AI requests. It never talks to the development Mac or FastAPI.
struct FortuneAPI {
    private let localEngine = LocalFortuneEngine()

    func calculate(profile: BirthProfile, health: HealthSummary?) async throws -> FortuneEnvelope {
        let localReport = localEngine.makeReport(profile: profile, health: health)

        guard let key = AppConfiguration.deepSeekAPIKey else {
            return FortuneEnvelope(code: 0, message: "local", data: localReport)
        }

        do {
            let report = try await DeepSeekFortuneClient(apiKey: key).expand(
                profile: profile,
                localReport: localReport,
                healthSummary: health
            )
            return FortuneEnvelope(code: 0, message: "success", data: report)
        } catch {
            // A daily reading remains available while travelling or when the AI provider is offline.
            return FortuneEnvelope(code: 0, message: "local", data: localReport)
        }
    }

    func interpret(sign: FortuneSign, profile: BirthProfile?) async throws -> String {
        guard let key = AppConfiguration.deepSeekAPIKey, let profile else { return sign.interpretation }
        return try await DeepSeekFortuneClient(apiKey: key).interpret(sign: sign, profile: profile)
    }
}

private enum AppConfiguration {
    static var deepSeekAPIKey: String? {
        let key = (Bundle.main.object(forInfoDictionaryKey: "DEEPSEEK_API_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let key, !key.isEmpty, key != "YOUR_DEEPSEEK_API_KEY" else { return nil }
        return key
    }

    static var deepSeekModel: String {
        (Bundle.main.object(forInfoDictionaryKey: "DEEPSEEK_MODEL") as? String) ?? "deepseek-chat"
    }
}

private struct DeepSeekFortuneClient {
    let apiKey: String

    func interpret(sign: FortuneSign, profile: BirthProfile) async throws -> String {
        let prompt = """
        请用温和、具体、不过度断言的中文解读一支黄大仙灵签。只返回 2-3 段纯文本，不要 markdown 标题，不要声称能预测事实，也不要给医疗或财务建议。
        签号：第\(sign.number)签（\(sign.rank)）
        签题：\(sign.title)
        签文：\(sign.poem)
        求签者出生资料：\(profile.birthYear)-\(profile.birthMonth)-\(profile.birthDay) \(profile.birthHour)时，\(profile.gender)，\(profile.birthPlace)。只把出生资料用于语气和自省角度，不要重新计算或虚构命盘。
        请先解释签文的文化象征，再给出今天一个可执行的行动，最后提醒这是自我反思工具。
        """
        var request = URLRequest(url: URL(string: "https://api.deepseek.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 28
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CompletionRequest(
            model: AppConfiguration.deepSeekModel,
            messages: [.init(role: "system", content: "你是传统文化解读助手。"), .init(role: "user", content: prompt)],
            responseFormat: nil
        ))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.invalidResponse }
        let completion = try JSONDecoder().decode(CompletionResponse.self, from: data)
        guard let text = completion.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { throw APIError.invalidResponse }
        return text.replacingOccurrences(of: "```", with: "")
    }

    func expand(profile: BirthProfile, localReport: DailyReport, healthSummary: HealthSummary?) async throws -> DailyReport {
        let date = localReport.date
        let context = LocalFortuneEngine().context(profile: profile, date: date)
        let prompt = """
        你是一位谨慎的传统文化与自我反思向导。请根据以下本地计算结果，返回严格 JSON，不要 markdown。
        结果必须含 overall_score（42-96 的整数）、overall_text、guidance（4 条短建议）和 analysis。
        analysis 必须有 disclaimer、bazi、meihua、fengshui、astrology 四部分；每部分含 title、summary、evidence（3-5 条）、guidance。若有健康汇总，还必须返回 wellbeing 作为第五部分。
        第 2、3、5 部分禁止解释“这个模块是什么”或重复免责声明；summary 和 evidence 必须引用上面提供的具体出生四柱、今日干支、日主五行、个人方位、星座或健康指标，并明确说明这些信息如何导出今天的建议。每条 evidence 都要是针对当前用户的事实或推导，不得写成通用定义。
        不要作事实预测、医疗或财务建议；健康数据只能用于独立的生活节奏建议，不能作为命理依据。

        日期：\(date)
        出生信息：\(profile.birthYear)-\(profile.birthMonth)-\(profile.birthDay) \(profile.birthHour)时，\(profile.gender)，\(profile.birthPlace)
        本地命理资料：\(context.baziDescription)
        本地黄历资料：\(context.almanacDescription)
        星座资料：\(context.astrologyDescription)
        本地节律评分：\(localReport.fortune.overallScore)
        健康汇总：\(healthSummary.map { "睡眠 \($0.sleepHours.map { String(format: "%.1f 小时", $0) } ?? "暂无")；主动能量 \($0.activeEnergyKcal.map { String(format: "%.0f 千卡", $0) } ?? "暂无")；步数 \($0.steps.map(String.init) ?? "暂无")；锻炼 \($0.workoutMinutes.map(String.init) ?? "暂无")" } ?? "未同步；不要臆测")
        """

        var request = URLRequest(url: URL(string: "https://api.deepseek.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 35
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CompletionRequest(
            model: AppConfiguration.deepSeekModel,
            messages: [
                .init(role: "system", content: "用传统文化做自我反思，不构成预测或专业建议。只返回 JSON。"),
                .init(role: "user", content: prompt),
            ],
            responseFormat: .init(type: "json_object")
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.invalidResponse }
        let completion = try JSONDecoder().decode(CompletionResponse.self, from: data)
        guard let content = completion.choices.first?.message.content else { throw APIError.invalidResponse }
        let reading = try JSONDecoder().decode(AIReading.self, from: Data(cleanJSON(content).utf8))
        let score = min(96, max(42, reading.overallScore))
        return DailyReport(
            date: date,
            fortune: .init(overallScore: score, overallText: reading.overallText, guidance: reading.guidance),
            analysis: reading.analysis ?? localReport.analysis
        )
    }

    private func cleanJSON(_ content: String) -> String {
        content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct CompletionRequest: Encodable {
    struct Message: Encodable { let role: String; let content: String }
    struct ResponseFormat: Encodable { let type: String }
    let model: String
    let messages: [Message]
    let responseFormat: ResponseFormat?

    enum CodingKeys: String, CodingKey { case model, messages; case responseFormat = "response_format" }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encodeIfPresent(responseFormat, forKey: .responseFormat)
    }
}

private struct CompletionResponse: Decodable {
    struct Choice: Decodable { struct Message: Decodable { let content: String }; let message: Message }
    let choices: [Choice]
}

private struct AIReading: Decodable {
    let overallScore: Int
    let overallText: String
    let guidance: [String]?
    let analysis: Analysis?

    enum CodingKeys: String, CodingKey {
        case overallScore = "overall_score", overallText = "overall_text", guidance, analysis
    }
}

private struct LocalFortuneContext {
    let baziDescription: String
    let almanacDescription: String
    let astrologyDescription: String
}

private struct LocalFortuneEngine {
    private let stems = Array("甲乙丙丁戊己庚辛壬癸").map(String.init)
    private let branches = Array("子丑寅卯辰巳午未申酉戌亥").map(String.init)
    private let wuxing = ["木", "木", "火", "火", "土", "土", "金", "金", "水", "水"]
    private let animals = ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"]

    func makeReport(profile: BirthProfile, health: HealthSummary?) -> DailyReport {
        let date = Self.shanghaiDateString(Date())
        let input = makeInput(profile: profile, date: date)
        let relation = fiveElementRelation(master: input.dayMasterElement, day: input.todayElement)
        let seed = date.unicodeScalars.reduce(0) { $0 + Int($1.value) } + profile.birthYear
        let score = min(96, max(42, 65 + relation.adjustment + input.elementResonance + seed % 7 - 3))
        let localHealthLine = health == nil ? "今天保留一段不被打扰的留白时间。" : "按已同步的生活节奏，在推进与休息之间留出缓冲。"
        let fortune = DailyReport.Fortune(
            overallScore: score,
            overallText: "今日\(input.todayGanzhi)日，\(input.dayMaster)日主与当日\(input.todayElement)行呈\(relation.name)之势；先稳住节奏，再决定是否推进。你的\(input.sunSign)能量适合\(input.elementAction)，把注意力放回一件可完成的事上。",
            guidance: [
                score >= 70 ? "把最重要的一件事安排在精神最集中的时段。" : "重要决定先记录，给自己一晚的观察时间。",
                "沟通时先说明目标，再讨论细节，减少来回猜测。",
                "今天不为情绪性消费买单，先确认预算边界。",
                localHealthLine,
            ]
        )
        return DailyReport(date: date, fortune: fortune, analysis: makeAnalysis(input: input, relation: relation, health: health, profile: profile))
    }

    func context(profile: BirthProfile, date: String) -> LocalFortuneContext {
        let input = makeInput(profile: profile, date: date)
        return LocalFortuneContext(
            baziDescription: "年柱\(input.yearPillar)、月柱\(input.monthPillar)、日柱\(input.dayPillar)、时柱\(input.hourPillar)。日主\(input.dayMaster)，五行\(input.dayMasterElement)，生肖\(input.animal)。今日\(input.todayGanzhi)，与日主为\(fiveElementRelation(master: input.dayMasterElement, day: input.todayElement).name)。",
            almanacDescription: "本地历法提示：\(input.todayGanzhi)日，宜整理、沟通、完成已开始的事务；忌仓促承诺和冲动消费。吉方位以\(input.luckyDirection)作日程与空间整理的灵感。",
            astrologyDescription: "太阳\(input.sunSign)，元素\(input.element)，建议\(input.elementAction)。这是性格和行动节奏的观察框架，不是精确预测。"
        )
    }

    private func makeAnalysis(input: Input, relation: Relation, health: HealthSummary?, profile: BirthProfile) -> Analysis {
        let disclaimer = "这是传统文化与自我反思视角，不构成事实预测、医疗或财务建议。"
        let bazi = AnalysisSection(
            title: "八字与五行",
            summary: "你的日主为\(input.dayMaster)，五行属\(input.dayMasterElement)。今日\(input.todayGanzhi)以\(input.todayElement)为主，对日主形成\(relation.name)关系；可把它看作安排节奏的一个传统文化提示。",
            evidence: ["日柱为\(input.dayPillar)，以日干\(input.dayMaster)作为观察中心。", "今日干支按本地历法简化计算为\(input.todayGanzhi)，日五行取\(input.todayElement)。", "\(input.dayMasterElement)与\(input.todayElement)的生克关系为\(relation.name)，因此建议\(relation.guidance)。"],
            guidance: relation.guidance
        )
        let meihua = AnalysisSection(
            title: "梅花易数·今日取象",
            summary: "以你出生的\(input.dayPillar)日柱、\(input.hourPillar)时柱对照今日\(input.todayGanzhi)，取象落在“先定边界、再求变化”：今天适合把一个模糊计划拆成可验证的第一步，而不是同时打开多个方向。",
            evidence: ["你的日柱为\(input.dayPillar)，时柱为\(input.hourPillar)，今天先处理与你个人节奏直接相关的事项。", "今日干支为\(input.todayGanzhi)，与\(input.dayMaster)日主呈\(relation.name)，行动顺序应以已知条件优先。", "你出生地记录为\(profile.birthPlace)，涉及他人或外部资源的安排，先确认时间、地点和回应期限再投入。"],
            guidance: "把今天最想推进的事写成一个 30 分钟内能完成的动作，并在开始前写下完成标准。"
        )
        let fengshui = AnalysisSection(
            title: "黄历与空间提醒",
            summary: "你是\(input.animal)年生、\(input.dayMaster)日主，今日\(input.todayGanzhi)的空间策略应服务于“收拢注意力”：把主要工作位朝\(input.luckyDirection)整理，减少同时可见的物件和通知，让推进有明确落点。",
            evidence: ["你的日主五行为\(input.dayMasterElement)，今日\(input.todayElement)与之为\(relation.name)，先整理再扩张比临时增加任务更稳。", "本地黄历按\(input.todayGanzhi)提示宜整理、沟通、收尾，这与你当前需要降低干扰的行动节奏一致。", "\(input.luckyDirection)是根据你的日主五行取出的个人空间提醒，可具体落实为座位、桌面或文件夹的整理方向。"],
            guidance: "先整理\(input.luckyDirection)一侧的桌面和通知栏 10 分钟，再只保留一个待办窗口完成今天的首要任务。"
        )
        let astrology = AnalysisSection(
            title: "星座与星盘视角",
            summary: "太阳星座为\(input.sunSign)，属\(input.element)。它只提供性格与行动节奏的观察框架，今天更适合\(input.elementAction)。",
            evidence: ["太阳星座由出生月日计算为\(input.sunSign)。", "\(input.element)关注\(input.elementFocus)，可作为沟通和安排工作的参考。", "未使用未经计算的行星相位或宫位，因此不对精确星盘作断言。"],
            guidance: "在一次关键沟通前，先说清你希望达成的结果，再给对方留下回应空间。"
        )
        let wellbeing: AnalysisSection? = health.map { metrics in
            let sleep = metrics.sleepHours.map { String(format: "%.1f 小时", $0) } ?? "暂无记录"
            let energy = metrics.activeEnergyKcal.map { String(format: "%.0f 千卡", $0) } ?? "暂无记录"
            let steps = metrics.steps.map { "\($0) 步" } ?? "暂无记录"
            let workout = metrics.workoutMinutes.map { "\($0) 分钟" } ?? "暂无记录"
            return AnalysisSection(title: "今日节奏建议", summary: "今天同步到你的睡眠为\(sleep)、主动能量\(energy)、步数\(steps)和锻炼\(workout)。这组数据显示的是今天已经发生的节奏，因此建议先安排恢复，再决定是否增加新的负荷。", evidence: ["睡眠记录为\(sleep)，高专注任务应放在你清醒度较高的时段，避免连续熬夜。", "主动能量为\(energy)、步数为\(steps)，今天可用短距离走动作为工作间的恢复，不需要用额外训练补偿。", "锻炼记录为\(workout)，若晚些时候仍感到疲惫，优先缩短任务时长并保留休息间隔。"], guidance: "把今天的工作切成 45 分钟专注加 5 分钟走动；若睡眠不足 6 小时，主动减少一个非必要任务。")
        }
        return Analysis(disclaimer: disclaimer, bazi: bazi, meihua: meihua, fengshui: fengshui, astrology: astrology, wellbeing: wellbeing, actionable: nil)
    }

    private func makeInput(profile: BirthProfile, date: String) -> Input {
        let birthYearIndex = positiveMod(profile.birthYear - 4, 60)
        let yearPillar = pillar(index: birthYearIndex)
        let monthPillar = pillar(index: positiveMod(birthYearIndex * 12 + profile.birthMonth + 1, 60))
        let dayPillar = pillar(index: dayIndex(year: profile.birthYear, month: profile.birthMonth, day: profile.birthDay))
        let hourPillar = pillar(index: positiveMod(dayIndex(year: profile.birthYear, month: profile.birthMonth, day: profile.birthDay) * 12 + (profile.birthHour + 1) / 2, 60))
        let today = date.split(separator: "-").compactMap { Int($0) }
        let todayIndex = dayIndex(year: today[0], month: today[1], day: today[2])
        let todayGanzhi = pillar(index: todayIndex)
        let sun = zodiac(month: profile.birthMonth, day: profile.birthDay)
        let element = zodiacElement(sun)
        let dayMaster = stems[positiveMod(dayIndex(year: profile.birthYear, month: profile.birthMonth, day: profile.birthDay), 10)]
        let masterElement = wuxing[positiveMod(dayIndex(year: profile.birthYear, month: profile.birthMonth, day: profile.birthDay), 10)]
        let todayElement = wuxing[positiveMod(todayIndex, 10)]
        return Input(yearPillar: yearPillar, monthPillar: monthPillar, dayPillar: dayPillar, hourPillar: hourPillar, dayMaster: dayMaster, dayMasterElement: masterElement, todayGanzhi: todayGanzhi, todayElement: todayElement, animal: animals[positiveMod(profile.birthYear - 4, 12)], sunSign: sun, element: element, elementAction: action(for: element), elementFocus: focus(for: element), elementResonance: zodiacToWuxing(element) == masterElement ? 3 : 0, luckyDirection: direction(for: masterElement))
    }

    private func pillar(index: Int) -> String { stems[positiveMod(index, 10)] + branches[positiveMod(index, 12)] }

    // The 1984-02-02 Jia-Zi reference keeps the sexagenary cycle deterministic without a server-side calendar package.
    private func dayIndex(year: Int, month: Int, day: Int) -> Int {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let reference = calendar.date(from: DateComponents(year: 1984, month: 2, day: 2))!
        let target = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        return calendar.dateComponents([.day], from: reference, to: target).day ?? 0
    }

    private func fiveElementRelation(master: String, day: String) -> Relation {
        if master == day { return .init(name: "比和", adjustment: 7, guidance: "维持既定节奏，避免因为顺手而忽略细节。") }
        let produces = ["木": "火", "火": "土", "土": "金", "金": "水", "水": "木"]
        let controls = ["木": "土", "土": "水", "水": "火", "火": "金", "金": "木"]
        if produces[day] == master { return .init(name: "生我", adjustment: 11, guidance: "适合推进已经准备好的重点事项。") }
        if produces[master] == day { return .init(name: "我生", adjustment: 3, guidance: "输出和沟通可以主动一些，同时给自己留出恢复空间。") }
        if controls[day] == master { return .init(name: "克我", adjustment: -7, guidance: "先收拢变量，重要决定留出观察时间。") }
        return .init(name: "我克", adjustment: -2, guidance: "明确边界后再推进，避免和细节硬碰硬。")
    }

    private func zodiac(month: Int, day: Int) -> String {
        let boundaries = [(1, 20, "摩羯座"), (2, 19, "水瓶座"), (3, 21, "双鱼座"), (4, 20, "白羊座"), (5, 21, "金牛座"), (6, 22, "双子座"), (7, 23, "巨蟹座"), (8, 23, "狮子座"), (9, 23, "处女座"), (10, 24, "天秤座"), (11, 23, "天蝎座"), (12, 22, "射手座")]
        let previous = boundaries[(month + 10) % 12].2
        guard let boundary = boundaries.first(where: { $0.0 == month }) else { return previous }
        return day >= boundary.1 ? boundary.2 : previous
    }

    private func zodiacElement(_ sign: String) -> String {
        if ["白羊座", "狮子座", "射手座"].contains(sign) { return "火象" }
        if ["金牛座", "处女座", "摩羯座"].contains(sign) { return "土象" }
        if ["双子座", "天秤座", "水瓶座"].contains(sign) { return "风象" }
        return "水象"
    }

    private func action(for element: String) -> String { ["火象": "明确优先级后主动行动", "土象": "把计划拆成稳定可交付的步骤", "风象": "通过沟通和记录澄清想法", "水象": "先辨认感受，再安排对话" ][element] ?? "保持平稳节奏" }
    private func focus(for element: String) -> String { ["火象": "行动与表达", "土象": "秩序与落实", "风象": "交流与思考", "水象": "感受与边界" ][element] ?? "当下节奏" }
    private func zodiacToWuxing(_ element: String) -> String { ["火象": "火", "土象": "土", "风象": "木", "水象": "水"][element] ?? "" }
    private func direction(for element: String) -> String { ["金": "西方", "木": "东方", "水": "北方", "火": "南方", "土": "中央"][element] ?? "中央" }
    private func positiveMod(_ number: Int, _ divisor: Int) -> Int { ((number % divisor) + divisor) % divisor }
    private static func shanghaiDateString(_ date: Date) -> String { let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian); formatter.timeZone = TimeZone(identifier: "Asia/Shanghai"); formatter.dateFormat = "yyyy-MM-dd"; return formatter.string(from: date) }

    private struct Input {
        let yearPillar: String; let monthPillar: String; let dayPillar: String; let hourPillar: String
        let dayMaster: String; let dayMasterElement: String; let todayGanzhi: String; let todayElement: String
        let animal: String; let sunSign: String; let element: String; let elementAction: String; let elementFocus: String
        let elementResonance: Int; let luckyDirection: String
    }
    private struct Relation { let name: String; let adjustment: Int; let guidance: String }
}
