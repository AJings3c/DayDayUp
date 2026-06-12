import AppIntents
import AppKit
import SwiftUI
import WidgetKit

enum DayDayUpWidgetKind {
    static let nextTask = "NextTaskWidget"
    static let todayBasket = "TodayBasketWidget"
    static let rhythmGauge = "RhythmGaugeWidget"
}

@main
struct DayDayUpWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextTaskWidget()
        TodayBasketWidget()
        RhythmGaugeWidget()
    }
}

struct StartFocusIntent: AppIntent {
    static let title: LocalizedStringResource = "开始专注"
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "任务 ID")
    var taskID: String

    init() {
        taskID = ""
    }

    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        try? DayDayUpWidgetShared.writePendingIntent(
            WidgetPendingIntent(
                kind: .startFocus,
                taskID: UUID(uuidString: taskID),
                createdAt: .now
            )
        )
        return .result()
    }
}

struct OpenDayDayUpIntent: AppIntent {
    static let title: LocalizedStringResource = "打开 DayDayUp"
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        try? DayDayUpWidgetShared.writePendingIntent(
            WidgetPendingIntent(kind: .openApp, taskID: nil, destination: .launch, createdAt: .now)
        )
        return .result()
    }
}

struct OpenTodayExecutionIntent: AppIntent {
    static let title: LocalizedStringResource = "打开今日执行"
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        try? DayDayUpWidgetShared.writePendingIntent(
            WidgetPendingIntent(kind: .openSection, taskID: nil, destination: .today, createdAt: .now)
        )
        return .result()
    }
}

struct OpenScoreDashboardIntent: AppIntent {
    static let title: LocalizedStringResource = "查看数据"
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        try? DayDayUpWidgetShared.writePendingIntent(
            WidgetPendingIntent(kind: .openSection, taskID: nil, destination: .score, createdAt: .now)
        )
        return .result()
    }
}

struct DayDayUpWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetDashboardSnapshot?

    static var placeholder: DayDayUpWidgetEntry {
        let now = Date()
        let taskID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let task = WidgetTaskSnapshot(
            id: taskID,
            name: "任务名称",
            deadline: now.addingTimeInterval(101_536),
            completedAt: nil,
            progress: 0.62,
            statusRaw: WidgetTaskStatus.warning.rawValue,
            completionCriteria: "完成标准"
        )
        let secondTask = WidgetTaskSnapshot(
            id: UUID(uuidString: "22222222-3333-4444-5555-666666666666")!,
            name: "任务名称",
            deadline: now.addingTimeInterval(42_000),
            completedAt: nil,
            progress: 0.2,
            statusRaw: WidgetTaskStatus.active.rawValue,
            completionCriteria: ""
        )

        return DayDayUpWidgetEntry(
            date: now,
            snapshot: WidgetDashboardSnapshot(
                updatedAt: now,
                task: task,
                activeFocus: nil,
                todayFocusMinutes: 45,
                overdueCount: 0,
                today: WidgetTodaySnapshot(
                    focusMinutes: 45,
                    incompleteCount: 2,
                    completedCount: 1,
                    overdueCount: 0,
                    queue: [task, secondTask],
                    recommendedTaskID: taskID
                ),
                rhythm: WidgetRhythmSnapshot(
                    score: 82,
                    scoreLabel: "节奏稳定",
                    weeklyFocusMinutes: 210,
                    completionRate: 0.76,
                    onTimeRate: 0.64,
                    reviewRate: 0.50,
                    overdueCount: 1,
                    riskTask: task,
                    hasTasks: true
                )
            )
        )
    }

    static var empty: DayDayUpWidgetEntry {
        let now = Date()
        return DayDayUpWidgetEntry(
            date: now,
            snapshot: WidgetDashboardSnapshot(
                updatedAt: now,
                task: nil,
                activeFocus: nil,
                todayFocusMinutes: 0,
                overdueCount: 0,
                today: WidgetTodaySnapshot(
                    focusMinutes: 0,
                    incompleteCount: 0,
                    completedCount: 0,
                    overdueCount: 0,
                    queue: [],
                    recommendedTaskID: nil
                ),
                rhythm: WidgetRhythmSnapshot(
                    score: 0,
                    scoreLabel: "暂无评分",
                    weeklyFocusMinutes: 0,
                    completionRate: 0,
                    onTimeRate: 0,
                    reviewRate: 0,
                    overdueCount: 0,
                    riskTask: nil,
                    hasTasks: false
                )
            )
        )
    }

    static var longTask: DayDayUpWidgetEntry {
        let now = Date()
        let taskID = UUID(uuidString: "33333333-4444-5555-6666-777777777777")!
        let task = WidgetTaskSnapshot(
            id: taskID,
            name: "任务名称任务名称任务名称任务名称任务名称",
            deadline: now.addingTimeInterval(5_400),
            completedAt: nil,
            progress: 0.48,
            statusRaw: WidgetTaskStatus.warning.rawValue,
            completionCriteria: "完成标准"
        )
        return DayDayUpWidgetEntry(
            date: now,
            snapshot: WidgetDashboardSnapshot(
                updatedAt: now,
                task: task,
                activeFocus: nil,
                todayFocusMinutes: 20,
                overdueCount: 0,
                today: WidgetTodaySnapshot(
                    focusMinutes: 20,
                    incompleteCount: 1,
                    completedCount: 0,
                    overdueCount: 0,
                    queue: [task],
                    recommendedTaskID: taskID
                ),
                rhythm: DayDayUpWidgetEntry.placeholder.snapshot?.rhythm
            )
        )
    }

    static var overdue: DayDayUpWidgetEntry {
        let now = Date()
        let taskID = UUID(uuidString: "44444444-5555-6666-7777-888888888888")!
        let task = WidgetTaskSnapshot(
            id: taskID,
            name: "任务名称",
            deadline: now.addingTimeInterval(-3_900),
            completedAt: nil,
            progress: 0.36,
            statusRaw: WidgetTaskStatus.overdue.rawValue,
            completionCriteria: "完成标准"
        )
        return DayDayUpWidgetEntry(
            date: now,
            snapshot: WidgetDashboardSnapshot(
                updatedAt: now,
                task: task,
                activeFocus: nil,
                todayFocusMinutes: 30,
                overdueCount: 1,
                today: WidgetTodaySnapshot(
                    focusMinutes: 30,
                    incompleteCount: 1,
                    completedCount: 0,
                    overdueCount: 1,
                    queue: [task],
                    recommendedTaskID: taskID
                ),
                rhythm: WidgetRhythmSnapshot(
                    score: 58,
                    scoreLabel: "执行风险较高",
                    weeklyFocusMinutes: 120,
                    completionRate: 0.35,
                    onTimeRate: 0.25,
                    reviewRate: 0.20,
                    overdueCount: 1,
                    riskTask: task,
                    hasTasks: true
                )
            )
        )
    }
}

struct DayDayUpTimelineProvider: TimelineProvider {
    let mode: WidgetTimelineMode

    init(mode: WidgetTimelineMode) {
        self.mode = mode
    }

    func placeholder(in context: Context) -> DayDayUpWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DayDayUpWidgetEntry) -> Void) {
        let snapshot = context.isPreview ? DayDayUpWidgetEntry.placeholder.snapshot : DayDayUpWidgetShared.loadDashboard()
        completion(DayDayUpWidgetEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayDayUpWidgetEntry>) -> Void) {
        let now = Date()
        let snapshot = DayDayUpWidgetShared.loadDashboard()
        let entry = DayDayUpWidgetEntry(date: now, snapshot: snapshot)
        completion(Timeline(
            entries: [entry],
            policy: .after(DayDayUpWidgetShared.nextRefreshDate(for: snapshot, mode: mode, now: now))
        ))
    }
}

struct NextTaskWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: DayDayUpWidgetKind.nextTask, provider: DayDayUpTimelineProvider(mode: .nextTask)) { entry in
            NextTaskWidgetView(entry: entry)
        }
        .configurationDisplayName("下一颗松果")
        .description("查看最近任务倒计时并快速开始专注。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TodayBasketWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: DayDayUpWidgetKind.todayBasket, provider: DayDayUpTimelineProvider(mode: .todayBasket)) { entry in
            TodayBasketWidgetView(entry: entry)
        }
        .configurationDisplayName("今日篮子")
        .description("查看今日专注、完成情况和执行队列。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct RhythmGaugeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: DayDayUpWidgetKind.rhythmGauge, provider: DayDayUpTimelineProvider(mode: .rhythmGauge)) { entry in
            RhythmGaugeWidgetView(entry: entry)
        }
        .configurationDisplayName("节奏仪表")
        .description("查看执行力评分、本周专注和学习节奏风险。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NextTaskWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayDayUpWidgetEntry

    private var glassTransparency: Double {
        entry.snapshot?.glassTransparency ?? DayDayUpWidgetShared.defaultGlassTransparency
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumContent
            default:
                smallContent
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }

    @ViewBuilder
    private var smallContent: some View {
        if let snapshot = entry.snapshot, let task = snapshot.task {
            SmallNextTaskView(task: task, date: entry.date, glassTransparency: snapshot.glassTransparency)
        } else {
            EmptyWidgetView(title: "暂无任务", subtitle: "先在 DayDayUp 新建一个任务。", isMedium: false, glassTransparency: glassTransparency)
        }
    }

    @ViewBuilder
    private var mediumContent: some View {
        if let snapshot = entry.snapshot, let task = snapshot.task {
            MediumNextTaskView(snapshot: snapshot, task: task, date: entry.date)
        } else {
            EmptyWidgetView(title: "暂无任务", subtitle: "先在 DayDayUp 新建一个任务。", isMedium: true, glassTransparency: glassTransparency)
        }
    }
}

struct TodayBasketWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayDayUpWidgetEntry

    private var glassTransparency: Double {
        entry.snapshot?.glassTransparency ?? DayDayUpWidgetShared.defaultGlassTransparency
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumContent
            default:
                smallContent
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }

    @ViewBuilder
    private var smallContent: some View {
        if let snapshot = entry.snapshot, let today = snapshot.today, today.hasContent {
            SmallTodayBasketView(today: today, glassTransparency: snapshot.glassTransparency)
        } else {
            EmptyWidgetView(title: "今日暂无任务", subtitle: "先在 DayDayUp 新建一个任务。", isMedium: false, glassTransparency: glassTransparency)
        }
    }

    @ViewBuilder
    private var mediumContent: some View {
        if let snapshot = entry.snapshot, let today = snapshot.today, today.hasContent {
            MediumTodayBasketView(today: today, date: entry.date, glassTransparency: snapshot.glassTransparency)
        } else {
            EmptyWidgetView(title: "今日暂无任务", subtitle: "先在 DayDayUp 新建一个任务。", isMedium: true, glassTransparency: glassTransparency)
        }
    }
}

struct RhythmGaugeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayDayUpWidgetEntry

    private var glassTransparency: Double {
        entry.snapshot?.glassTransparency ?? DayDayUpWidgetShared.defaultGlassTransparency
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                mediumContent
            default:
                smallContent
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }

    @ViewBuilder
    private var smallContent: some View {
        if let snapshot = entry.snapshot, let rhythm = snapshot.rhythm, rhythm.hasTasks {
            SmallRhythmGaugeView(rhythm: rhythm, glassTransparency: snapshot.glassTransparency)
        } else {
            EmptyRhythmView(isMedium: false, glassTransparency: glassTransparency)
        }
    }

    @ViewBuilder
    private var mediumContent: some View {
        if let snapshot = entry.snapshot, let rhythm = snapshot.rhythm, rhythm.hasTasks {
            MediumRhythmGaugeView(rhythm: rhythm, glassTransparency: snapshot.glassTransparency)
        } else {
            EmptyRhythmView(isMedium: true, glassTransparency: glassTransparency)
        }
    }
}

struct SmallNextTaskView: View {
    let task: WidgetTaskSnapshot
    let date: Date
    let glassTransparency: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(trailing: DayDayUpWidgetShared.percentText(task.progress))

            Text(task.name)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .foregroundStyle(WidgetPalette.primaryText)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 3) {
                Text(DayDayUpWidgetShared.countdownText(
                    deadline: task.deadline,
                    completedAt: task.completedAt,
                    now: date,
                    compact: true
                ))
                .font(.system(.body, design: .rounded, weight: .bold))
                .monospacedDigit()

                Text("截止 \(DayDayUpWidgetShared.deadlineText(task.deadline))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            StartFocusButton(taskID: task.id)
        }
        .padding(14)
        .dayDayUpWidgetGlass(transparency: glassTransparency)
    }
}

struct MediumNextTaskView: View {
    let snapshot: WidgetDashboardSnapshot
    let task: WidgetTaskSnapshot
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("DayDayUp")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                Spacer(minLength: 8)
                StatusBadge(status: task.status, progress: task.progress)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(task.name)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text("完成标准: \(criteriaText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            HStack(alignment: .firstTextBaseline) {
                Text("剩余时间")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Text(DayDayUpWidgetShared.countdownText(
                    deadline: task.deadline,
                    completedAt: task.completedAt,
                    now: date,
                    compact: false
                ))
                .font(.system(.body, design: .rounded, weight: .bold))
                .monospacedDigit()
            }

            Spacer(minLength: 0)

            HStack {
                StartFocusButton(taskID: task.id)

                Spacer(minLength: 12)

                Text("今日专注 \(snapshot.todayFocusMinutes) 分钟")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .dayDayUpWidgetGlass(transparency: snapshot.glassTransparency)
    }

    private var criteriaText: String {
        let trimmed = task.completionCriteria.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未填写" : trimmed
    }
}

struct SmallTodayBasketView: View {
    let today: WidgetTodaySnapshot
    let glassTransparency: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(trailing: "今日")

            VStack(alignment: .leading, spacing: 7) {
                WidgetValueLine(title: "今日专注", value: "\(today.focusMinutes) 分钟", tint: WidgetPalette.success)
                WidgetValueLine(title: "完成", value: "\(today.completedCount)/\(today.totalCount)", tint: WidgetPalette.accent)
                WidgetValueLine(title: "逾期", value: "\(today.overdueCount)", tint: today.overdueCount > 0 ? WidgetPalette.danger : WidgetPalette.secondaryText)
            }

            Spacer(minLength: 0)

            if let recommendedTaskID = today.recommendedTaskID {
                StartFocusButton(taskID: recommendedTaskID)
            } else {
                OpenTodayButton()
            }
        }
        .padding(14)
        .dayDayUpWidgetGlass(transparency: glassTransparency)
    }
}

struct MediumTodayBasketView: View {
    let today: WidgetTodaySnapshot
    let date: Date
    let glassTransparency: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            WidgetHeader(trailing: "今日篮子")

            HStack(spacing: 12) {
                CompactMetric(label: "专注", value: "\(today.focusMinutes) 分钟", tint: WidgetPalette.success)
                CompactMetric(label: "完成", value: "\(today.completedCount)/\(today.totalCount)", tint: WidgetPalette.accent)
                CompactMetric(label: "逾期", value: "\(today.overdueCount)", tint: today.overdueCount > 0 ? WidgetPalette.danger : WidgetPalette.secondaryText)
            }

            VStack(spacing: 6) {
                ForEach(today.queue.prefix(3)) { task in
                    TaskQueueRow(task: task, date: date)
                }
            }

            Spacer(minLength: 0)

            HStack {
                if let recommendedTaskID = today.recommendedTaskID {
                    StartFocusButton(taskID: recommendedTaskID)
                }
                Spacer(minLength: 8)
                OpenTodayButton()
            }
        }
        .padding(16)
        .dayDayUpWidgetGlass(transparency: glassTransparency)
    }
}

struct SmallRhythmGaugeView: View {
    let rhythm: WidgetRhythmSnapshot
    let glassTransparency: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeader(trailing: "本周")

            VStack(alignment: .leading, spacing: 4) {
                Text("\(rhythm.score) 分")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(scoreTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(rhythm.scoreLabel)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text("本周专注 \(rhythm.weeklyFocusMinutes) 分钟")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            OpenScoreButton()
        }
        .padding(14)
        .dayDayUpWidgetGlass(transparency: glassTransparency)
    }

    private var scoreTint: Color {
        WidgetPalette.scoreTint(for: rhythm.score)
    }
}

struct MediumRhythmGaugeView: View {
    let rhythm: WidgetRhythmSnapshot
    let glassTransparency: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(trailing: "节奏仪表")

            HStack(alignment: .firstTextBaseline) {
                Text("执行力 \(rhythm.score) 分")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(WidgetPalette.scoreTint(for: rhythm.score))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 10)
                Text(rhythm.scoreLabel)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                CompactMetric(label: "完成率", value: DayDayUpWidgetShared.percentText(rhythm.completionRate), tint: WidgetPalette.accent)
                CompactMetric(label: "准时", value: DayDayUpWidgetShared.percentText(rhythm.onTimeRate), tint: WidgetPalette.success)
                CompactMetric(label: "复盘", value: DayDayUpWidgetShared.percentText(rhythm.reviewRate), tint: WidgetPalette.recovered)
            }

            HStack {
                Text("本周专注 \(rhythm.weeklyFocusMinutes) 分钟")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 10)
                Text("逾期 \(rhythm.overdueCount)")
                    .font(.caption)
                    .foregroundStyle(rhythm.overdueCount > 0 ? WidgetPalette.danger : .secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack {
                OpenScoreButton()
                Spacer(minLength: 10)
                if let riskTask = rhythm.riskTask {
                    Text("最近风险: \(riskTask.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
        }
        .padding(16)
        .dayDayUpWidgetGlass(transparency: glassTransparency)
    }
}

struct WidgetHeader: View {
    let trailing: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("DayDayUp")
                .font(.system(.caption, design: .rounded, weight: .semibold))
            Spacer(minLength: 8)
            Text(trailing)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(WidgetPalette.accent)
                .lineLimit(1)
        }
    }
}

struct WidgetValueLine: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}

struct CompactMetric: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TaskQueueRow: View {
    let task: WidgetTaskSnapshot
    let date: Date

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(WidgetPalette.tint(for: task.status))
                .frame(width: 6, height: 6)
            Text(task.name)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 10)
            Text(timeText)
                .font(.caption2)
                .foregroundStyle(task.status == .overdue ? WidgetPalette.danger : .secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    private var timeText: String {
        if task.status == .overdue {
            return DayDayUpWidgetShared.countdownText(
                deadline: task.deadline,
                completedAt: task.completedAt,
                now: date,
                compact: true
            )
        }
        if Calendar.current.isDate(task.deadline, inSameDayAs: date) {
            return "今天 \(Self.timeFormatter.string(from: task.deadline))"
        }
        return DayDayUpWidgetShared.deadlineText(task.deadline)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

struct StartFocusButton: View {
    let taskID: UUID

    var body: some View {
        Button(intent: StartFocusIntent(taskID: taskID.uuidString)) {
            Label("开始专注", systemImage: "play.fill")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }
}

struct OpenTodayButton: View {
    var body: some View {
        Button(intent: OpenTodayExecutionIntent()) {
            Label("打开今日执行", systemImage: "play.circle")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

struct OpenScoreButton: View {
    var body: some View {
        Button(intent: OpenScoreDashboardIntent()) {
            Label("查看数据", systemImage: "chart.xyaxis.line")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }
}

struct StatusBadge: View {
    let status: WidgetTaskStatus
    let progress: Double

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbolName)
                .font(.caption2.weight(.bold))
            Text("\(status.title) \(DayDayUpWidgetShared.percentText(progress))")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(WidgetPalette.tint(for: status))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.thinMaterial, in: Capsule())
    }

    private var symbolName: String {
        switch status {
        case .active: "circle.dotted"
        case .warning: "exclamationmark.triangle.fill"
        case .overdue: "xmark.octagon.fill"
        case .completed: "checkmark.circle.fill"
        case .recovered: "arrow.triangle.2.circlepath.circle.fill"
        }
    }
}

struct EmptyWidgetView: View {
    let title: String
    let subtitle: String
    let isMedium: Bool
    let glassTransparency: Double

    var body: some View {
        VStack(alignment: .leading, spacing: isMedium ? 14 : 10) {
            WidgetHeader(trailing: "")

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(isMedium ? .title3 : .headline, design: .rounded, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(isMedium ? 1 : 2)
            }

            Spacer(minLength: 0)

            Button(intent: OpenDayDayUpIntent()) {
                Label("打开 DayDayUp", systemImage: "macwindow")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(isMedium ? 16 : 14)
        .dayDayUpWidgetGlass(transparency: glassTransparency)
    }
}

struct EmptyRhythmView: View {
    let isMedium: Bool
    let glassTransparency: Double

    var body: some View {
        VStack(alignment: .leading, spacing: isMedium ? 14 : 10) {
            WidgetHeader(trailing: isMedium ? "节奏仪表" : "本周")

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 6) {
                Text("暂无评分")
                    .font(.system(isMedium ? .title3 : .headline, design: .rounded, weight: .semibold))
                Text("创建任务后会生成学习节奏。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(isMedium ? 1 : 2)
            }

            Spacer(minLength: 0)

            Button(intent: OpenDayDayUpIntent()) {
                Label("打开 DayDayUp", systemImage: "macwindow")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(isMedium ? 16 : 14)
        .dayDayUpWidgetGlass(transparency: glassTransparency)
    }
}

enum WidgetPalette {
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let accent = Color.dayWidgetAdaptive(light: 0x3F6FA8, dark: 0x8EB8EC)
    static let warning = Color.dayWidgetAdaptive(light: 0xB46919, dark: 0xD9A15C)
    static let danger = Color.dayWidgetAdaptive(light: 0xB54848, dark: 0xE47378)
    static let success = Color.dayWidgetAdaptive(light: 0x247C5E, dark: 0x65C8A0)
    static let recovered = Color.dayWidgetAdaptive(light: 0x7A5CCF, dark: 0xA993F4)
    static let glass = Color.dayWidgetAdaptive(light: 0xEEF3F8, dark: 0x2A3340)
    static let surface = Color.dayWidgetAdaptive(light: 0xF6F8FB, dark: 0x202733)
    static let border = Color.dayWidgetAdaptive(light: 0xD8E0EA, dark: 0x374454)
    static let primaryDeep = Color.dayWidgetAdaptive(light: 0x18324D, dark: 0xC7DDF7)

    static func tint(for status: WidgetTaskStatus) -> Color {
        switch status {
        case .active: accent
        case .warning: warning
        case .overdue: danger
        case .completed: success
        case .recovered: recovered
        }
    }

    static func scoreTint(for score: Int) -> Color {
        switch score {
        case 90...100: success
        case 75..<90: accent
        case 60..<75: warning
        default: danger
        }
    }
}

private extension Color {
    static func dayWidgetAdaptive(
        light: UInt32,
        dark: UInt32,
        lightAlpha: Double = 1,
        darkAlpha: Double? = nil
    ) -> Color {
        Color(nsColor: .dayWidgetAdaptive(
            light: light,
            dark: dark,
            lightAlpha: CGFloat(lightAlpha),
            darkAlpha: CGFloat(darkAlpha ?? lightAlpha)
        ))
    }
}

private extension NSColor {
    convenience init(dayWidgetHex hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xff) / 255
        let green = CGFloat((hex >> 8) & 0xff) / 255
        let blue = CGFloat(hex & 0xff) / 255
        self.init(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }

    static func dayWidgetAdaptive(
        light: UInt32,
        dark: UInt32,
        lightAlpha: CGFloat = 1,
        darkAlpha: CGFloat = 1
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(dayWidgetHex: isDark ? dark : light, alpha: isDark ? darkAlpha : lightAlpha)
        }
    }
}

extension WidgetTodaySnapshot {
    var totalCount: Int {
        max(completedCount + incompleteCount, 1)
    }

    var hasContent: Bool {
        incompleteCount > 0 || completedCount > 0 || focusMinutes > 0
    }
}

private struct WidgetGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let transparency: Double

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let resolvedTransparency = DayDayUpWidgetShared.clampedGlassTransparency(transparency)
        let tintOpacity = min(max(0.46 - resolvedTransparency * 0.50, 0.07), 0.46)
        let highlightOpacity = 0.06 + resolvedTransparency * 0.26
        let borderOpacity = 0.34 + resolvedTransparency * 0.24
        let shadowOpacity = max(0.02, 0.08 - resolvedTransparency * 0.04)

        if #available(macOSApplicationExtension 26.0, *) {
            content
                .background {
                    shape.fill(.regularMaterial)
                    shape.fill(WidgetPalette.glass.opacity(tintOpacity))
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(highlightOpacity),
                                    WidgetPalette.accent.opacity(max(0.04, tintOpacity * 0.42)),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.screen)
                }
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(borderOpacity),
                                WidgetPalette.accent.opacity(max(0.08, tintOpacity * 0.55)),
                                WidgetPalette.border.opacity(max(0.28, tintOpacity))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
                }
                .overlay(alignment: .topLeading) {
                    shape
                        .trim(from: 0.03, to: 0.30)
                        .stroke(Color.white.opacity(highlightOpacity * 0.86), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                        .blur(radius: 0.7)
                        .padding(1)
                }
                .shadow(color: WidgetPalette.primaryDeep.opacity(shadowOpacity), radius: 5, x: 0, y: 2)
                .glassEffect(.regular.tint(WidgetPalette.glass.opacity(tintOpacity)), in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background {
                    shape.fill(.regularMaterial)
                    shape.fill(WidgetPalette.glass.opacity(tintOpacity))
                }
                .overlay {
                    shape.stroke(WidgetPalette.border.opacity(0.55), lineWidth: 1)
                }
        }
    }
}

extension View {
    func dayDayUpWidgetGlass(transparency: Double = DayDayUpWidgetShared.defaultGlassTransparency) -> some View {
        modifier(WidgetGlassModifier(cornerRadius: 22, transparency: transparency))
    }
}

#Preview("下一颗松果 Small", as: .systemSmall) {
    NextTaskWidget()
} timeline: {
    DayDayUpWidgetEntry.placeholder
}

#Preview("下一颗松果 Medium", as: .systemMedium) {
    NextTaskWidget()
} timeline: {
    DayDayUpWidgetEntry.placeholder
}

#Preview("今日篮子 Small", as: .systemSmall) {
    TodayBasketWidget()
} timeline: {
    DayDayUpWidgetEntry.placeholder
}

#Preview("今日篮子 Medium", as: .systemMedium) {
    TodayBasketWidget()
} timeline: {
    DayDayUpWidgetEntry.placeholder
}

#Preview("节奏仪表 Small", as: .systemSmall) {
    RhythmGaugeWidget()
} timeline: {
    DayDayUpWidgetEntry.placeholder
}

#Preview("节奏仪表 Medium", as: .systemMedium) {
    RhythmGaugeWidget()
} timeline: {
    DayDayUpWidgetEntry.placeholder
}

#Preview("空状态 Small", as: .systemSmall) {
    NextTaskWidget()
} timeline: {
    DayDayUpWidgetEntry.empty
}

#Preview("长任务 Medium", as: .systemMedium) {
    TodayBasketWidget()
} timeline: {
    DayDayUpWidgetEntry.longTask
}

#Preview("逾期 Medium", as: .systemMedium) {
    TodayBasketWidget()
} timeline: {
    DayDayUpWidgetEntry.overdue
}

#Preview("无评分 Small", as: .systemSmall) {
    RhythmGaugeWidget()
} timeline: {
    DayDayUpWidgetEntry.empty
}
