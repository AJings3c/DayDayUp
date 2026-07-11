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
        try DayDayUpWidgetShared.writePendingIntent(
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
        try DayDayUpWidgetShared.writePendingIntent(
            WidgetPendingIntent(kind: .openApp, taskID: nil, destination: .launch, createdAt: .now)
        )
        return .result()
    }
}

struct OpenTodayExecutionIntent: AppIntent {
    static let title: LocalizedStringResource = "打开今日执行"
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        try DayDayUpWidgetShared.writePendingIntent(
            WidgetPendingIntent(kind: .openSection, taskID: nil, destination: .today, createdAt: .now)
        )
        return .result()
    }
}

struct OpenScoreDashboardIntent: AppIntent {
    static let title: LocalizedStringResource = "查看数据"
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        try DayDayUpWidgetShared.writePendingIntent(
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
