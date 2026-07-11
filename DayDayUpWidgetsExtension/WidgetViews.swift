import AppIntents
import AppKit
import SwiftUI
import WidgetKit

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
