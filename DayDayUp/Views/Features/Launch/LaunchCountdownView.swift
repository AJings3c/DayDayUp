import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LaunchCountdownView: View {
    let task: LearningTask?
    let nextUpcomingTask: LearningTask?
    let metrics: AppMetrics
    let now: Date
    let onStartToday: () -> Void
    let onTaskDetail: () -> Void
    let onNewTask: () -> Void
    let onCreateSampleTask: () -> Void
    let onBeginFocus: (LearningTask) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageTitle(
                    title: "启动倒计时",
                    subtitle: "打开后先看最近一个未完成任务的 deadline，把下一步学习行动放到眼前。"
                )

                GlassHost(spacing: 18) {
                    HStack(alignment: .center, spacing: 28) {
                        squirrelPanel
                        deadlinePanel
                    }
                    .padding(24)
                    .dayGlass(cornerRadius: 16, interactive: true)
                }

                if let nextUpcomingTask, nextUpcomingTask.id != task?.id {
                    NextDeadlineStrip(task: nextUpcomingTask, now: now)
                }

                HStack(spacing: 12) {
                    MetricCard(title: "执行力评分", value: metrics.scoreText, subtitle: metrics.scoreLabel, tint: DayColor.primaryDeep)
                    MetricCard(title: "任务闭环率", value: metrics.closedLoopRate.percentText, subtitle: "完成并达到标准", tint: DayColor.success)
                    MetricCard(title: "补完成率", value: metrics.recoveredRate.percentText, subtitle: "逾期后补上的比例", tint: DayColor.recovered)
                }
            }
            .padding(28)
        }
        .dayPageBackground()
    }

    private var squirrelPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            SquirrelImage(mood: squirrelMood, size: 176, animated: true)
                .frame(maxWidth: .infinity, alignment: .center)

            statusBadge

            Text(squirrelTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(statusColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(squirrelSubtitle)
                .font(.body)
                .foregroundStyle(DayColor.muted)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Text(task?.name ?? "任务名称")
                .font(.headline)
                .foregroundStyle(DayColor.text)
            Text(task?.details.nilIfBlank ?? "还没有任务，先收下第一颗松果。")
                .font(.body)
                .foregroundStyle(DayColor.muted)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("小松鼠状态，\(squirrelTitle)，\(squirrelSubtitle)")
    }

    @ViewBuilder
    private var statusBadge: some View {
        if let task {
            StatusBadge(status: task.status(now: now))
        } else {
            Label("暂无任务", systemImage: "basket")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DayColor.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(DayColor.surface, in: Capsule())
        }
    }

    private var deadlinePanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let task {
                CountdownText(deadline: task.deadline, completedAt: task.completedAt)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Label("截止时间：\(task.deadline.formattedDateTime())", systemImage: "calendar.badge.clock")
                    Label("完成度：\(task.progress.percentText)", systemImage: "chart.line.uptrend.xyaxis")
                    Label("完成标准：\(task.completionCriteria.nilIfBlank ?? "用户未填写")", systemImage: "checkmark.seal")
                }
                .font(.callout)
                .foregroundStyle(DayColor.text)
                .labelStyle(.titleAndIcon)

                HStack(spacing: 10) {
                    Button {
                        if task.completedAt == nil {
                            onBeginFocus(task)
                        } else {
                            onStartToday()
                        }
                    } label: {
                        Label(task.completedAt == nil ? "开始今日执行" : "查看今日执行", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: onTaskDetail) {
                        Label("查看任务详情", systemImage: "sidebar.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            } else {
                Text("00 天 00:00:00")
                    .font(.system(size: 44, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DayColor.muted)
                Text("没有待监督的任务。")
                    .foregroundStyle(DayColor.muted)
                VStack(spacing: 10) {
                    Button(action: onNewTask) {
                        Label("创建第一个学习任务", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut("n", modifiers: [.command])

                    Button(action: onCreateSampleTask) {
                        Label("用示例任务体验", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
        .frame(width: 420, alignment: .leading)
        .padding(20)
        .dayLiquidPanel(cornerRadius: 16, interactive: true, emphasized: task != nil)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: task?.status(now: now).rawValue)
    }

    private var squirrelTitle: String {
        guard let task else { return "空篮子，等你放入任务" }
        switch task.status(now: now) {
        case .active: return "还差一颗松果"
        case .warning: return "快到饭点了"
        case .overdue: return "小松鼠闹脾气中"
        case .completed, .recovered: return "任务完成啦，开始干饭！"
        }
    }

    private var squirrelSubtitle: String {
        guard let task else { return "先写下任务名称、内容和 deadline，DayDayUp 会帮你盯住时间。" }
        switch task.status(now: now) {
        case .active: return "空篮子还在等你收尾，先把这颗松果放稳。"
        case .warning: return "轻提醒：deadline 已经很近，今天最好推进一次。"
        case .overdue: return "deadline 已过，先记录卡住原因，再补上闭环。"
        case .completed: return "小松鼠抱着松果笑脸盈盈，这个任务已经按时闭环。"
        case .recovered: return "晚了一点，但松果已经补回仓库，记得写下复盘。"
        }
    }

    private var statusColor: Color {
        task?.status(now: now).color ?? DayColor.muted
    }

    private var squirrelMood: SquirrelMood {
        SquirrelMood(status: task?.status(now: now))
    }
}

private struct NextDeadlineStrip: View {
    let task: LearningTask
    let now: Date

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "timer")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DayColor.primary)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("下一截止")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DayColor.muted)
                Text(task.name)
                    .font(.headline)
                    .foregroundStyle(DayColor.text)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: task.status(now: now))
                Text(task.deadline.formattedDateTime())
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(DayColor.muted)
            }
        }
        .padding(14)
        .dayPanel(cornerRadius: 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("下一截止任务，\(task.name)，截止时间 \(task.deadline.formattedDateTime())")
    }
}
