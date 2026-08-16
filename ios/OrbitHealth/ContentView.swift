import SwiftUI

private struct ReadingStartOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = .greatestFiniteMagnitude
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingProfile = false
    @State private var isVisible = false
    @State private var showFloatingRail = false
    @State private var floatingRailHideWorkItem: DispatchWorkItem?

    var body: some View {
        NavigationStack {
            ZStack {
                OrbitTheme.background.ignoresSafeArea()
                if state.profile == nil {
                    onboarding
                } else {
                    dashboard
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingProfile) {
            ProfileView().environmentObject(state)
                .presentationDetents([.height(420), .medium])
                .presentationDragIndicator(.visible)
        }
        .task { await state.refreshIfNeeded() }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.72, dampingFraction: 0.82)) {
                isVisible = true
            }
        }
    }

    private var onboarding: some View {
        ZStack {
            OrbitBackdrop()
                .frame(width: 0, height: 0)
                .opacity(isVisible ? 1 : 0)
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("ORBIT", systemImage: "sparkle")
                        .font(.caption.weight(.bold))
                        .tracking(2)
                        .foregroundStyle(OrbitTheme.gold)
                    Spacer()
                    Text("DAILY GUIDE")
                        .font(.caption2.monospaced())
                        .foregroundStyle(OrbitTheme.secondary)
                        .lineLimit(1)
                        .frame(width: 92, alignment: .trailing)
                }
                .padding(.top, 16)

                Spacer()

                VStack(alignment: .leading, spacing: 18) {
                    Text("今天的节奏，\n由你定义。")
                        .font(.system(size: 36, weight: .semibold, design: .serif))
                        .foregroundStyle(OrbitTheme.primary)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("结合你的出生资料和 Apple 健康今日摘要，生成一份清晰、可执行的日常建议。")
                        .font(.body)
                        .foregroundStyle(OrbitTheme.secondary)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 8) {
                        onboardingTag("每日更新", icon: "arrow.clockwise")
                        onboardingTag("私密保存", icon: "lock")
                    }
                }
                .offset(y: isVisible ? 0 : 26)
                .opacity(isVisible ? 1 : 0)

                Button { showingProfile = true } label: {
                    HStack {
                        Text("创建我的命轨").font(.headline)
                        Spacer()
                        Image(systemName: "arrow.right").fontWeight(.bold)
                    }
                    .padding(.horizontal, 20)
                    .frame(height: 58)
                    .foregroundStyle(OrbitTheme.background)
                    .background(OrbitTheme.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(OrbitPressStyle())
                .padding(.top, 36)
                .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
        }
    }

    private func onboardingTag(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.medium))
            .foregroundStyle(OrbitTheme.primary)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(OrbitTheme.surface.opacity(0.85), in: Capsule())
    }

    private var dashboard: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 30) {
                        header
                        if state.isLoading {
                            loadingState
                        } else if let report = state.report {
                            scoreHero(report)
                            guidanceList(report)
                            healthSummary
                            fullReading(report, proxy: proxy)
                        } else {
                            unavailableState
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                }
            .coordinateSpace(name: "dashboardScroll")
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, offset in
                updateFloatingRail(for: offset)
            }
            .overlay(alignment: .trailing) {
                if let analysis = state.report?.analysis, !state.isLoading, showFloatingRail {
                    floatingChapterRail(analysis, proxy: proxy)
                        .padding(.trailing, 8)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .refreshable { await state.refresh(force: true) }
        }
    }

    private func updateFloatingRail(for offset: CGFloat) {
        guard offset > 720 else {
            floatingRailHideWorkItem?.cancel()
            if showFloatingRail {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { showFloatingRail = false }
            }
            return
        }

        floatingRailHideWorkItem?.cancel()
        if !showFloatingRail {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { showFloatingRail = true }
        }

        let workItem = DispatchWorkItem {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.28)) { showFloatingRail = false }
        }
        floatingRailHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: workItem)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                Text("今日命轨")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .foregroundStyle(OrbitTheme.primary)
                Text(Self.dateText)
                    .font(.caption.monospaced())
                    .foregroundStyle(OrbitTheme.secondary)
            }
            Spacer()
            NavigationLink { DivinationView().environmentObject(state) } label: {
                Image(systemName: "scroll.fill")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(OrbitTheme.surface, in: Circle())
                    .foregroundStyle(OrbitTheme.gold)
            }
            .buttonStyle(OrbitPressStyle())
            .accessibilityLabel("今日求签")
            Button { showingProfile = true } label: {
                Image(systemName: "person.crop.circle")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(OrbitTheme.surface, in: Circle())
                    .foregroundStyle(OrbitTheme.gold)
            }
            .buttonStyle(OrbitPressStyle())
            .accessibilityLabel("个人资料")
        }
    }

    private var loadingState: some View {
        VStack(spacing: 20) {
            ReadingLoader()
                .frame(width: 88, height: 88)
            VStack(spacing: 8) {
                Text(state.loadingMessage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(OrbitTheme.primary)
                    .contentTransition(.opacity)
                    .id(state.loadingMessage)
                Text("八字为主线，健康摘要只用于今天的节奏建议")
                    .font(.caption)
                    .foregroundStyle(OrbitTheme.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 340)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: state.loadingMessage)
    }

    private func scoreHero(_ report: DailyReport) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("TODAY / RHYTHM").font(.caption2.monospaced().weight(.bold)).tracking(1.8).foregroundStyle(OrbitTheme.gold)
                    Text("\(report.fortune.overallScore)").font(.system(size: 42, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(OrbitTheme.primary)
                    Text("/ 100 · 今日节律").font(.caption.weight(.medium)).foregroundStyle(OrbitTheme.secondary)
                }
                Spacer()
                Text(dayMode(report.fortune.overallScore)).font(.headline.weight(.semibold)).foregroundStyle(OrbitTheme.gold)
            }
            Text(report.fortune.overallText.components(separatedBy: "\n").last ?? report.fortune.overallText)
                .font(.subheadline).foregroundStyle(OrbitTheme.secondary).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 5) {
                ForEach(0..<10, id: \.self) { index in
                    Capsule().fill(index < report.fortune.overallScore / 10 ? OrbitTheme.gold : OrbitTheme.background).frame(height: 4)
                }
            }
        }
        .padding(22).background(OrbitTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .topTrailing) { Image(systemName: "moon.stars.fill").foregroundStyle(OrbitTheme.gold.opacity(0.12)).font(.system(size: 46)).padding(14) }
    }

    private func guidanceList(_ report: DailyReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今天这样做")
                .font(.title3.weight(.semibold))
                .foregroundStyle(OrbitTheme.primary)
            ForEach(Array(report.fortune.practicalGuidance.prefix(3).enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 14) {
                    Text(String(format: "%02d", index + 1))
                        .font(.caption.monospaced().weight(.bold))
                        .foregroundStyle(OrbitTheme.gold)
                        .frame(width: 28, alignment: .leading)
                    Rectangle().fill(OrbitTheme.gold.opacity(0.42)).frame(width: 2).padding(.vertical, 2)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(guidanceLabel(index)).font(.caption.weight(.semibold)).foregroundStyle(OrbitTheme.secondary)
                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(OrbitTheme.primary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    if index < min(report.fortune.practicalGuidance.count, 3) - 1 {
                        Rectangle().fill(OrbitTheme.secondary.opacity(0.16)).frame(height: 1).padding(.leading, 44)
                    }
                }
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 18)
                .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.85).delay(Double(index) * 0.09), value: isVisible)
            }
        }
    }

    private var healthSummary: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("健康摘要").font(.title3.weight(.semibold)).foregroundStyle(OrbitTheme.primary)
                Spacer()
                Label(state.usesDemoHealthData ? "演示数据" : "今日", systemImage: state.usesDemoHealthData ? "testtube.2" : "heart.fill")
                    .font(.caption)
                    .foregroundStyle(state.usesDemoHealthData ? OrbitTheme.gold : OrbitTheme.secondary)
            }
            HStack(spacing: 10) {
                healthMetric("figure.walk", "步数", stepsText)
                healthMetric("bed.double.fill", "睡眠", sleepText)
                healthMetric("flame.fill", "活跃", energyText)
            }
        }
    }

    private func fullReading(_ report: DailyReport, proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("今日解读")
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(OrbitTheme.primary)
                        .background {
                            GeometryReader { proxy in
                                Color.clear.preference(key: ReadingStartOffsetKey.self, value: proxy.frame(in: .named("dashboardScroll")).minY)
                            }
                        }
                    Text("从八字主线到可执行的日常安排")
                        .font(.caption)
                        .foregroundStyle(OrbitTheme.secondary)
                }
                Spacer()
                Image(systemName: "text.book.closed.fill")
                    .foregroundStyle(OrbitTheme.gold)
                    .font(.title3)
            }

            if let analysis = report.analysis {
                VStack(alignment: .leading, spacing: 24) {
                        readingLead(report.fortune.overallText)
                        Label(analysis.disclaimer, systemImage: "info.circle")
                            .font(.footnote).foregroundStyle(OrbitTheme.secondary).lineSpacing(3).padding(14)
                            .background(OrbitTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        if let actionable = analysis.actionable { actionableTips(actionable) }
                        ReadingChapter(section: analysis.bazi, icon: "seal.fill", number: "01", index: 0, appeared: isVisible).id("chapter-01")
                        ReadingChapter(section: analysis.meihua, icon: "arrow.triangle.branch", number: "02", index: 1, appeared: isVisible).id("chapter-02")
                        ReadingChapter(section: analysis.fengshui, icon: "house.and.flag.fill", number: "03", index: 2, appeared: isVisible).id("chapter-03")
                        ReadingChapter(section: analysis.astrology, icon: "moon.stars.fill", number: "04", index: 3, appeared: isVisible).id("chapter-04")
                        if let wellbeing = analysis.wellbeing { ReadingChapter(section: wellbeing, icon: "figure.mind.and.body", number: "05", index: 4, appeared: isVisible).id("chapter-05") }
                }
            } else {
                Text(report.fortune.overallText).font(.body).foregroundStyle(OrbitTheme.secondary).lineSpacing(5)
            }
        }
        .padding(.top, 14)
    }

    private func readingLead(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Rectangle().fill(OrbitTheme.gold).frame(width: 3, height: 18)
                Text("综合节奏").font(.headline.weight(.semibold)).foregroundStyle(OrbitTheme.primary)
                Spacer()
                Text("01 / 05").font(.caption2.monospaced().weight(.bold)).foregroundStyle(OrbitTheme.gold)
            }
            Text(text)
                .font(.body)
                .foregroundStyle(OrbitTheme.secondary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 11)
        }
    }

    private func floatingChapterRail(_ analysis: Analysis, proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 0) {
            ForEach(["01", "02", "03", "04", "05"], id: \.self) { number in
                let exists = number != "05" || analysis.wellbeing != nil
                if exists {
                    Button(number) {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.4)) { proxy.scrollTo("chapter-\(number)", anchor: .top) }
                    }
                    .font(.caption2.monospaced().weight(.bold))
                    .foregroundStyle(OrbitTheme.gold)
                    .frame(width: 30, height: 36)
                    .buttonStyle(.plain)
                    if number != "05" { Rectangle().fill(OrbitTheme.gold.opacity(0.28)).frame(width: 1, height: 18) }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(OrbitTheme.gold.opacity(0.28), lineWidth: 1))
        .shadow(color: .black.opacity(0.28), radius: 12, y: 4)
        .accessibilityLabel("每日解读章节导航")
    }

    private func actionableTips(_ tips: ActionableTips) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(tips.title, systemImage: "sparkles.rectangle.stack.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(OrbitTheme.primary)
                Spacer()
                Text("八字 x 星座 x 黄历")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(OrbitTheme.gold)
            }
            ForEach(tips.items) { tip in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: tip.icon)
                            .foregroundStyle(OrbitTheme.gold)
                            .frame(width: 22)
                        Text(tip.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(OrbitTheme.secondary)
                        Text(tip.value)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(OrbitTheme.primary)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    Text(tip.reason)
                        .font(.caption)
                        .foregroundStyle(OrbitTheme.secondary)
                        .lineSpacing(3)
                        .padding(.leading, 32)
                }
                .padding(.vertical, 7)
            }
        }
        .padding(16)
        .background(OrbitTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var stepsText: String {
        guard let steps = state.healthSummary?.steps else { return "--" }
        return "\(steps)"
    }

    private var sleepText: String {
        guard let hours = state.healthSummary?.sleepHours else { return "--" }
        return String(format: "%.1fh", hours)
    }

    private var energyText: String {
        guard let energy = state.healthSummary?.activeEnergyKcal else { return "--" }
        return String(format: "%.0f", energy)
    }

    private func healthMetric(_ icon: String, _ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(OrbitTheme.gold)
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(OrbitTheme.primary).frame(height: 24, alignment: .leading)
            Text(label).font(.caption2).foregroundStyle(OrbitTheme.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(14)
        .background(OrbitTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var unavailableState: some View {
        ContentUnavailableView {
            Label("暂时无法生成建议", systemImage: "wifi.exclamationmark")
        } description: {
            Text(state.errorMessage ?? "下拉刷新后再试一次")
        } actions: {
            Button("重新尝试") { Task { await state.refresh(force: true) } }.tint(OrbitTheme.gold)
        }
        .foregroundStyle(OrbitTheme.primary)
        .frame(maxWidth: .infinity, minHeight: 340)
    }

    private func dayMode(_ score: Int) -> String {
        switch score { case 78...100: return "顺势推进"; case 66...77: return "稳步布局"; case 55...65: return "收拢蓄力"; default: return "留白养势" }
    }

    private func modeIcon(_ score: Int) -> String {
        switch score { case 78...100: return "arrow.up.right.circle.fill"; case 66...77: return "circle.grid.cross.fill"; case 55...65: return "arrow.down.left.circle.fill"; default: return "leaf.circle.fill" }
    }


    private func guidanceLabel(_ index: Int) -> String { ["先做这一件", "沟通与推进", "留意边界"][index % 3] }

    private static var dateText: String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "zh_CN"); formatter.dateFormat = "M月d日 · EEEE"; return formatter.string(from: Date())
    }
}

private struct RhythmSeal: View {
    let score: Int

    var body: some View {
        VStack(spacing: 1) {
            Text(sealCharacter).font(.system(size: 34, weight: .medium, design: .serif)).foregroundStyle(OrbitTheme.gold)
            Text(modeLabel).font(.system(size: 7, weight: .bold, design: .monospaced)).tracking(1.2).foregroundStyle(OrbitTheme.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay { RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(OrbitTheme.gold.opacity(0.5), lineWidth: 1) }
    }

    private var modeLabel: String {
        switch score { case 8...10: return "ADVANCE"; case 6...7: return "STEADY"; case 4...5: return "GATHER"; default: return "RESTORE" }
    }
    private var sealCharacter: String {
        switch score { case 8...10: return "进"; case 6...7: return "定"; case 4...5: return "收"; default: return "养" }
    }
}

private struct OrbitBackdrop: View {
    @State private var rotation = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().stroke(OrbitTheme.gold.opacity(0.12), lineWidth: 1).frame(width: 460, height: 460).offset(x: 180, y: -290).rotationEffect(.degrees(rotation))
            Circle().stroke(OrbitTheme.gold.opacity(0.18), lineWidth: 1).frame(width: 270, height: 270).offset(x: -170, y: 255).rotationEffect(.degrees(-rotation * 0.7))
            Image(systemName: "circle.fill").font(.system(size: 7)).foregroundStyle(OrbitTheme.gold).offset(x: 128, y: -134)
        }
        .onAppear { guard !reduceMotion else { return }; withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) { rotation = 360 } }
    }
}

struct OrbitPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label.scaleEffect(configuration.isPressed ? 0.97 : 1).opacity(configuration.isPressed ? 0.86 : 1).animation(.easeOut(duration: 0.14), value: configuration.isPressed) }
}

enum OrbitTheme {
    static let background = Color(red: 0.055, green: 0.071, blue: 0.078)
    static let surface = Color(red: 0.11, green: 0.135, blue: 0.143)
    static let primary = Color(red: 0.96, green: 0.95, blue: 0.90)
    static let secondary = Color(red: 0.62, green: 0.66, blue: 0.66)
    static let gold = Color(red: 0.95, green: 0.68, blue: 0.25)
}

private struct ReadingChapter: View {
    private static let evidenceSymbols = ["doc.text", "arrow.triangle.branch", "circle.dotted", "sparkles", "checkmark.seal"]
    private static let bodyLeading: CGFloat = 70

    let section: AnalysisSection
    let icon: String
    let number: String
    let index: Int
    let appeared: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .center, spacing: 12) {
                Text(number)
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(OrbitTheme.gold)
                    .frame(width: 28, alignment: .leading)
                Rectangle().fill(OrbitTheme.gold.opacity(0.62)).frame(width: 2, height: 34)
                Image(systemName: icon).font(.subheadline.weight(.semibold)).foregroundStyle(OrbitTheme.gold).frame(width: 22)
                Text(section.title).font(.title3.weight(.semibold)).foregroundStyle(OrbitTheme.primary)
                Spacer(minLength: 0)
            }
            .frame(minHeight: 36)

            Rectangle().fill(OrbitTheme.secondary.opacity(0.2)).frame(height: 1)

            ReadingFieldLabel(title: "摘要", symbol: "text.alignleft")
            Text(section.summary)
                .font(.body)
                .foregroundStyle(OrbitTheme.primary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, Self.bodyLeading)

            ReadingFieldLabel(title: "依据", symbol: "checklist")
            VStack(spacing: 0) {
                ForEach(Array(section.evidence.enumerated()), id: \.offset) { evidenceIndex, evidence in
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: Self.evidenceSymbols[evidenceIndex % Self.evidenceSymbols.count])
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(OrbitTheme.gold)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(OrbitTheme.gold.opacity(0.1)))
                            .accessibilityHidden(true)
                        Text(String(format: "%02d", evidenceIndex + 1))
                            .font(.caption2.monospaced().weight(.bold))
                            .foregroundStyle(OrbitTheme.gold)
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(width: 32, alignment: .leading)
                        Text(evidence)
                            .font(.subheadline)
                            .foregroundStyle(OrbitTheme.secondary)
                            .lineSpacing(4)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        if evidenceIndex < section.evidence.count - 1 {
                            Rectangle().fill(OrbitTheme.secondary.opacity(0.14)).frame(height: 1).padding(.leading, Self.bodyLeading)
                        }
                    }
                }
            }

            ReadingFieldLabel(title: "今日行动", symbol: "arrow.turn.down.right")
            ZStack(alignment: .topLeading) {
                Text(section.guidance)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(OrbitTheme.primary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, Self.bodyLeading)
                HStack(spacing: 5) {
                    Rectangle().fill(OrbitTheme.gold.opacity(0.7)).frame(width: 3)
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(OrbitTheme.gold)
                }
                .frame(width: Self.bodyLeading - 10, alignment: .leading)
            }
        }
        .padding(20)
        .background(OrbitTheme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(OrbitTheme.secondary.opacity(0.12), lineWidth: 1))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
        .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.85).delay(Double(index) * 0.08), value: appeared)
    }
}

private struct ReadingFieldLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .frame(width: 18, alignment: .center)
            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(OrbitTheme.gold)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ReadingLoader: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation = 0.0
    var body: some View {
        ZStack {
            Circle().stroke(OrbitTheme.gold.opacity(0.18), lineWidth: 2)
            Circle().trim(from: 0.08, to: 0.34).stroke(OrbitTheme.gold, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(rotation))
            Image(systemName: "sparkles").foregroundStyle(OrbitTheme.gold)
        }
        .onAppear { guard !reduceMotion else { return }; withAnimation(.linear(duration: 1.25).repeatForever(autoreverses: false)) { rotation = 360 } }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var year = "1990"; @State private var month = "6"; @State private var day = "15"; @State private var hour = 12; @State private var gender = "male"; @State private var place = "北京"

    var body: some View {
        NavigationStack {
            Form {
                Section("出生资料") {
                    TextField("出生年份", text: $year).keyboardType(.numberPad)
                    HStack { TextField("月", text: $month).keyboardType(.numberPad); TextField("日", text: $day).keyboardType(.numberPad) }
                    Picker("出生时刻", selection: $hour) { ForEach(0..<24) { Text("\($0):00").tag($0) } }
                    Picker("性别", selection: $gender) { Text("男").tag("male"); Text("女").tag("female") }
                    TextField("出生地", text: $place)
                }
                if state.profile != nil {
                    Section("Apple 健康") {
                        Button {
                            Task { await state.authorizeHealthAndRefresh() }
                        } label: {
                            Label("授权并同步健康摘要", systemImage: "heart.text.square")
                        }
                        LabeledContent("授权状态", value: statusText)
                        if case .authorized = state.healthKit.authorizationState {
                            Text(state.healthDataStatusText())
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if case .error(let message) = state.healthKit.authorizationState {
                            Text(message).font(.footnote).foregroundStyle(.red)
                        }
                    }
                    Section("测试数据") {
                        Toggle(isOn: Binding(get: { state.usesDemoHealthData }, set: { state.setUsesDemoHealthData($0) })) {
                            Label("使用演示健康数据", systemImage: "testtube.2")
                        }
                        Text("仅用于测试建议效果。开启后不读取 Apple 健康，发送固定的模拟健康汇总。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section { Button(state.profile == nil ? "保存并生成今日建议" : "保存资料") { save() }.frame(maxWidth: .infinity).foregroundStyle(.orange) }
            }
            .navigationTitle("个人资料").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("取消") { dismiss() } } }
            .onAppear { if let p = state.profile { year = String(p.birthYear); month = String(p.birthMonth); day = String(p.birthDay); hour = p.birthHour; gender = p.gender; place = p.birthPlace } }
        }
    }

    private func save() { state.save(profile: BirthProfile(birthYear: Int(year) ?? 1990, birthMonth: Int(month) ?? 6, birthDay: Int(day) ?? 15, birthHour: hour, gender: gender, birthPlace: place)); dismiss(); Task { await state.refresh(force: true) } }
    private var statusText: String { switch state.healthKit.authorizationState { case .authorized: return "已授权"; case .unavailable: return "设备不可用"; case .denied: return "未授权"; case .error(let value): return value; case .notRequested: return "尚未请求" } }
}
