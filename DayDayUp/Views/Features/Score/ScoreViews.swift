import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ScoreDashboardView: View {
    let tasks: [LearningTask]
    @Query(sort: \AchievementRecord.unlockedAt, order: .reverse) private var achievements: [AchievementRecord]
    let metrics: AppMetrics
    let now: Date
    @Binding var selectedTaskID: UUID?
    @State private var displayedMonth = Date.now.monthStart()

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 160), spacing: 12)]
    }

    private var summaryMetrics: [ScoreMetricItem] {
        [
            ScoreMetricItem(title: "完成度", value: metrics.completionRate.percentText, subtitle: "已完成 / 计划任务", tint: DayColor.primary),
            ScoreMetricItem(title: "准时完成率", value: metrics.onTimeRate.percentText, subtitle: "deadline 前闭环", tint: DayColor.success),
            ScoreMetricItem(title: "提前完成率", value: metrics.earlyRate.percentText, subtitle: "早于 deadline", tint: DayColor.success),
            ScoreMetricItem(title: "延迟完成率", value: metrics.delayedRate.percentText, subtitle: "逾期未完成 + 补完成", tint: DayColor.danger),
            ScoreMetricItem(title: "本周学习", value: "\(metrics.weeklyFocusMinutes)", subtitle: "分钟", tint: DayColor.primaryDeep),
            ScoreMetricItem(title: "未闭环任务", value: "\(metrics.unfinishedCount)", subtitle: "仍需处理", tint: metrics.unfinishedCount > 0 ? DayColor.warning : DayColor.success),
            ScoreMetricItem(title: "平均延期", value: String(format: "%.1f", metrics.averageDelayDays), subtitle: "天", tint: metrics.averageDelayDays > 0 ? DayColor.danger : DayColor.success),
            ScoreMetricItem(title: "复盘完整度", value: metrics.reviewRate.percentText, subtitle: "完成后写复盘", tint: DayColor.recovered)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageTitle(title: "数据评分", subtitle: "用评分、雷达图和任务日历复盘执行质量，不做焦虑型排名。")

                if tasks.isEmpty {
                    EmptyStateView(
                        title: "暂无评分数据",
                        subtitle: "创建任务并记录执行后，这里会计算执行力评分、完成率和任务日历。"
                    )
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        ScoreCard(metrics: metrics)
                        RadarChartPanel(metrics: metrics)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        ScoreCard(metrics: metrics)
                        RadarChartPanel(metrics: metrics)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                AchievementShelfView(achievements: achievements, tasks: tasks)

                LazyVGrid(columns: metricColumns, spacing: 12) {
                    ForEach(summaryMetrics) { item in
                        MetricCard(title: item.title, value: item.value, subtitle: item.subtitle, tint: item.tint)
                    }
                }

                DirectionFocusPanel(metrics: metrics)

                TaskCalendarView(
                    tasks: tasks,
                    now: now,
                    displayedMonth: $displayedMonth,
                    selectedTaskID: $selectedTaskID
                )
            }
            .padding(28)
        }
        .dayGlassMotionEnabled(false)
        .dayPageBackground()
    }
}

private struct ScoreMetricItem: Identifiable {
    let title: String
    let value: String
    let subtitle: String
    let tint: Color

    var id: String { title }
}

struct DirectionFocusPanel: View {
    let metrics: AppMetrics

    private var rows: [(String, Int)] {
        metrics.directionFocusMinutes
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }
                return lhs.key < rhs.key
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "学习方向投入", systemImage: "square.stack.3d.up")
            if rows.isEmpty {
                Text("还没有专注记录。")
                    .font(.callout)
                    .foregroundStyle(DayColor.muted)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                    ForEach(rows, id: \.0) { direction, minutes in
                        HStack {
                            Text(direction)
                                .font(.callout.weight(.medium))
                                .foregroundStyle(DayColor.text)
                                .lineLimit(1)
                            Spacer()
                            Text("\(minutes) 分钟")
                                .font(.system(.callout, design: .monospaced).weight(.semibold))
                                .foregroundStyle(DayColor.primary)
                        }
                        .padding(12)
                        .dayPanel(cornerRadius: 10)
                    }
                }
            }
        }
        .padding(20)
        .dayLiquidPanel(cornerRadius: 14)
    }
}

struct ScoreCard: View {
    let metrics: AppMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "执行力评分", systemImage: "gauge.with.dots.needle.67percent")
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(metrics.scoreText)
                    .font(.system(size: metrics.hasTasks ? 72 : 44, weight: .bold, design: .monospaced))
                    .foregroundStyle(DayColor.primaryDeep)
                if metrics.hasTasks {
                    Text("分")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DayColor.muted)
                }
            }
            .frame(height: 88, alignment: .bottomLeading)
            Text(metrics.scoreLabel)
                .font(.headline)
                .foregroundStyle(DayColor.primary)
            Text(metrics.hasTasks ? "评分由任务完成度、准时率、提前完成率、延迟控制、专注稳定度和复盘完整度组成。" : "现在没有任务数据，评分暂不生成。")
                .font(.callout)
                .foregroundStyle(DayColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                ScoreRuleRow(label: "任务完成度", points: 30)
                ScoreRuleRow(label: "准时完成率", points: 25)
                ScoreRuleRow(label: "提前完成率", points: 10)
                ScoreRuleRow(label: "延迟控制率", points: 15)
                ScoreRuleRow(label: "专注稳定度", points: 15)
                ScoreRuleRow(label: "复盘完整度", points: 5)
            }
        }
        .frame(width: 330, alignment: .leading)
        .padding(20)
        .dayLiquidPanel(cornerRadius: 14, emphasized: metrics.hasTasks)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(metrics.hasTasks ? "执行力评分 \(metrics.score) 分，\(metrics.scoreLabel)" : "执行力评分，暂无评分")
    }
}

struct ScoreRuleRow: View {
    let label: String
    let points: Int

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(DayColor.text)
            Spacer()
            Text("\(points) 分")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(DayColor.muted)
        }
        .font(.caption)
    }
}

struct RadarChartPanel: View {
    let metrics: AppMetrics

    private var dimensions: [(String, Double, Color)] {
        [
            ("任务完成度", metrics.completionRate, DayColor.primary),
            ("准时完成率", metrics.onTimeRate, DayColor.success),
            ("提前完成率", metrics.earlyRate, DayColor.success),
            ("延迟控制率", max(0, 1 - metrics.delayedRate), DayColor.warning),
            ("专注稳定度", metrics.stableFocusRate, DayColor.squirrel),
            ("复盘完整度", metrics.reviewRate, DayColor.recovered)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "学习执行力雷达图", systemImage: "chart.line.uptrend.xyaxis")
            HStack(spacing: 22) {
                ZStack {
                    RadarGridShape(sides: dimensions.count)
                        .stroke(DayColor.border, lineWidth: 1)
                    RadarPolygonShape(values: dimensions.map(\.1))
                        .fill(DayColor.primary.opacity(0.18))
                    RadarPolygonShape(values: dimensions.map(\.1))
                        .stroke(DayColor.primary, lineWidth: 2)
                }
                .frame(width: 240, height: 240)
                .accessibilityLabel("雷达图显示六个执行力维度")

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(dimensions, id: \.0) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.2)
                                .frame(width: 8, height: 8)
                            Text(item.0)
                                .font(.caption)
                                .frame(width: 88, alignment: .leading)
                            ProgressView(value: item.1)
                                .tint(item.2)
                                .frame(width: 120)
                            Text(item.1.percentText)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(DayColor.muted)
                                .frame(width: 42, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .dayLiquidPanel(cornerRadius: 14, emphasized: metrics.hasTasks)
    }
}

struct TaskCalendarView: View {
    let tasks: [LearningTask]
    let now: Date
    @Binding var displayedMonth: Date
    @Binding var selectedTaskID: UUID?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.fixed(38), spacing: 7), count: 7)
    @State private var selectedDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(title: "任务日历", systemImage: "calendar")
                Spacer()
                Button {
                    shiftMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("上一个月")
                Button {
                    displayedMonth = now.monthStart(calendar: calendar)
                } label: {
                    Text("今天")
                }
                Button {
                    shiftMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("下一个月")
            }

            Text(displayedMonth.formatted(.dateTime.year().month(.wide)))
                .font(.title3.weight(.semibold))
                .foregroundStyle(DayColor.primaryDeep)

            HStack(spacing: 14) {
                CalendarLegendItem(color: DayColor.success, label: "按时/提前完成")
                CalendarLegendItem(color: DayColor.danger, label: "逾期未完成")
                CalendarLegendItem(color: DayColor.recovered, label: "逾期后补完成")
                CalendarLegendItem(color: DayColor.border, label: "普通日期")
            }

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(DayColor.muted)
                        .frame(width: 38, height: 24)
                }
                ForEach(calendarCells, id: \.id) { cell in
                    if let date = cell.date {
                        let status = calendarStatus(for: date)
                        CalendarDayCell(
                            date: date,
                            status: status,
                            isToday: date.dayKey() == now.dayKey(),
                            taskCount: taskCount(for: date)
                        ) {
                            selectedDate = date
                            if let task = primaryTask(for: date) {
                                selectedTaskID = task.id
                            }
                        }
                    } else {
                        Color.clear
                            .frame(width: 38, height: 38)
                    }
                }
            }
            .padding(16)
            .dayPanel(cornerRadius: 12)

            selectedDatePanel
        }
        .padding(20)
        .dayLiquidPanel(cornerRadius: 14)
    }

    @ViewBuilder
    private var selectedDatePanel: some View {
        if let selectedDate {
            let relatedTasks = tasksForDate(selectedDate)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(selectedDate.formatted(.dateTime.year().month().day()))
                        .font(.headline)
                        .foregroundStyle(DayColor.text)
                    Spacer()
                    Text("相关任务 \(relatedTasks.count) 个")
                        .font(.caption)
                        .foregroundStyle(DayColor.muted)
                }
                if relatedTasks.isEmpty {
                    Text("这一天没有完成记录或截止任务。")
                        .font(.callout)
                        .foregroundStyle(DayColor.muted)
                } else {
                    ForEach(relatedTasks, id: \.id) { task in
                        Button {
                            selectedTaskID = task.id
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: task.status(now: now).symbolName)
                                    .foregroundStyle(task.status(now: now).color)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.name)
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(DayColor.text)
                                    Text(calendarReason(for: task, on: selectedDate))
                                        .font(.caption)
                                        .foregroundStyle(DayColor.muted)
                                }
                                Spacer()
                                Text(task.progress.percentText)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(DayColor.muted)
                            }
                            .padding(10)
                            .dayPanel(cornerRadius: 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
            .dayPanel(cornerRadius: 12)
        }
    }

    private var calendarCells: [CalendarCell] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday + 5) % 7
        let dates = dayRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: interval.start)
        }

        let leadingCells = (0..<leading).map { CalendarCell(position: $0, date: nil) }
        let dateCells = dates.enumerated().map { offset, date in
            CalendarCell(position: leading + offset, date: date)
        }
        return leadingCells + dateCells
    }

    private func shiftMonth(_ value: Int) {
        displayedMonth = (calendar.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth).monthStart(calendar: calendar)
    }

    private func calendarStatus(for date: Date) -> TaskStatus? {
        TaskCalendarPolicy.status(for: date, tasks: tasks, now: now, calendar: calendar)
    }

    private func taskCount(for date: Date) -> Int {
        let day = date.dayKey(calendar: calendar)
        return tasks.filter { task in
            task.deadline.dayKey(calendar: calendar) == day
                || task.completedAt?.dayKey(calendar: calendar) == day
        }.count
    }

    private func primaryTask(for date: Date) -> LearningTask? {
        let day = date.dayKey(calendar: calendar)
        return tasks.sortedForExecution(now: now).first { task in
            task.deadline.dayKey(calendar: calendar) == day
                || task.completedAt?.dayKey(calendar: calendar) == day
        }
    }

    private func tasksForDate(_ date: Date) -> [LearningTask] {
        let day = date.dayKey(calendar: calendar)
        return tasks.sortedForExecution(now: now).filter { task in
            task.deadline.dayKey(calendar: calendar) == day
                || task.completedAt?.dayKey(calendar: calendar) == day
        }
    }

    private func calendarReason(for task: LearningTask, on date: Date) -> String {
        let day = date.dayKey(calendar: calendar)
        if task.status(now: now) == .overdue && task.deadline.dayKey(calendar: calendar) == day {
            return "这一天截止，当前仍未闭环"
        }
        if task.status(now: now) == .recovered && task.deadline.dayKey(calendar: calendar) == day {
            return "这一天原本逾期，后来已补完成"
        }
        if task.completedAt?.dayKey(calendar: calendar) == day {
            return "这一天完成"
        }
        return "这一天截止"
    }
}

struct CalendarCell: Identifiable {
    let position: Int
    let date: Date?

    var id: String {
        if let date {
            return "day-\(Int(date.timeIntervalSinceReferenceDate))"
        }
        return "empty-\(position)"
    }
}

struct CalendarDayCell: View {
    let date: Date
    let status: TaskStatus?
    let isToday: Bool
    let taskCount: Int
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(.caption, design: .monospaced).weight(isToday ? .bold : .regular))
                if let status {
                    Image(systemName: status.symbolName)
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(status.color)
                        .accessibilityHidden(true)
                } else if taskCount > 0 {
                    Circle()
                        .fill(DayColor.muted)
                        .frame(width: 5, height: 5)
                        .accessibilityHidden(true)
                } else {
                    Color.clear.frame(width: 5, height: 5)
                }
            }
            .frame(width: 38, height: 38)
            .foregroundStyle(status?.color ?? DayColor.text)
            .background((status?.backgroundColor ?? Color.clear), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday ? DayColor.primary : DayColor.border.opacity(status == nil ? 0.4 : 0.9), lineWidth: isToday ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let base = date.formatted(.dateTime.year().month().day())
        let statusText = status?.accessibilityText ?? "普通日期"
        return "\(base)，\(statusText)，相关任务 \(taskCount) 个"
    }
}

struct CalendarLegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.24))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(color, lineWidth: 1))
                .frame(width: 16, height: 16)
            Text(label)
                .font(.caption)
                .foregroundStyle(DayColor.muted)
        }
    }
}

struct RadarGridShape: Shape {
    let sides: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard sides > 2 else { return path }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        for ring in 1...4 {
            let ringRadius = radius * CGFloat(ring) / 4
            addPolygon(to: &path, center: center, radius: ringRadius)
        }

        for index in 0..<sides {
            let point = point(index: index, value: 1, center: center, radius: radius)
            path.move(to: center)
            path.addLine(to: point)
        }
        return path
    }

    private func addPolygon(to path: inout Path, center: CGPoint, radius: CGFloat) {
        for index in 0..<sides {
            let p = point(index: index, value: 1, center: center, radius: radius)
            if index == 0 {
                path.move(to: p)
            } else {
                path.addLine(to: p)
            }
        }
        path.closeSubpath()
    }

    private func point(index: Int, value: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = (Double(index) / Double(sides) * 2 * .pi) - (.pi / 2)
        let scaledRadius = radius * CGFloat(value)
        return CGPoint(x: center.x + cos(angle) * scaledRadius, y: center.y + sin(angle) * scaledRadius)
    }
}

struct RadarPolygonShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 2 else { return path }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        for index in values.indices {
            let angle = (Double(index) / Double(values.count) * 2 * .pi) - (.pi / 2)
            let value = min(max(values[index], 0), 1)
            let scaledRadius = radius * CGFloat(value)
            let point = CGPoint(x: center.x + cos(angle) * scaledRadius, y: center.y + sin(angle) * scaledRadius)
            if index == values.startIndex {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
