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
            VStack(alignment: .leading, spacing: 20) {
                PageTitle(
                    title: "启动倒计时",
                    subtitle: "先看时间，再收下一颗松果。"
                )

                launchHero

                if let nextUpcomingTask, nextUpcomingTask.id != task?.id {
                    NextDeadlineStrip(task: nextUpcomingTask, now: now)
                }

                LaunchMetricLedger(metrics: metrics)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                    LaunchNextActionPanel(
                        task: task,
                        now: now,
                        onStartToday: onStartToday,
                        onTaskDetail: onTaskDetail,
                        onNewTask: onNewTask,
                        onCreateSampleTask: onCreateSampleTask,
                        onBeginFocus: onBeginFocus
                    )
                    LaunchClosureSnapshotPanel(task: task, now: now)
                }
            }
            .padding(28)
        }
        .dayPageBackground()
    }

    private var launchHero: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 9) {
                    statusBadge

                    Text(task?.name ?? "今天的篮子还空着")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(DayColor.text)
                        .lineLimit(2)

                    Text(task?.details.nilIfBlank ?? "创建一个有明确截止时间和完成标准的学习任务。")
                        .font(.callout)
                        .foregroundStyle(DayColor.muted)
                        .lineLimit(2)

                    Text(squirrelTitle)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(statusColor)
                }

                Spacer(minLength: 12)

                SquirrelImage(mood: squirrelMood, size: 108, animated: true)
                    .padding(8)
                    .background(DayColor.squirrelSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Divider()

            HStack(alignment: .bottom, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    if let task {
                        CountdownText(deadline: task.deadline, completedAt: task.completedAt)
                        Label(task.deadline.formattedDateTime(), systemImage: "calendar.badge.clock")
                            .font(.caption)
                            .foregroundStyle(DayColor.muted)
                    } else {
                        Text("00 天 00:00:00")
                            .font(.system(size: 42, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DayColor.muted)
                        Text("没有待监督的任务")
                            .font(.callout)
                            .foregroundStyle(DayColor.muted)
                    }
                }

                Spacer(minLength: 12)

                VStack(spacing: 10) {
                    heroPrimaryAction
                    heroSecondaryAction
                }
                .frame(width: 220)
            }

            AcornProgressTrack(
                progress: task?.progress ?? 0,
                tint: task?.status(now: now).color ?? DayColor.squirrel
            )
        }
        .padding(24)
        .background(DayColor.focusSurface.opacity(0.88), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .dayLiquidPanel(cornerRadius: 16, interactive: true, emphasized: task != nil)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: task?.status(now: now).rawValue)
    }

    @ViewBuilder
    private var heroPrimaryAction: some View {
        if let task {
            Button {
                task.completedAt == nil ? onBeginFocus(task) : onStartToday()
            } label: {
                Label(task.completedAt == nil ? "开始专注" : "查看今日执行", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else {
            Button(action: onNewTask) {
                Label("创建学习任务", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("n", modifiers: [.command])
        }
    }

    private var heroSecondaryAction: some View {
        Button(action: task == nil ? onCreateSampleTask : onTaskDetail) {
            Label(task == nil ? "载入示例" : "查看任务详情", systemImage: task == nil ? "sparkles" : "sidebar.right")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
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

private struct LaunchMetricLedger: View {
    let metrics: AppMetrics

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            Label("本周节奏", systemImage: "waveform.path.ecg")
                .font(.callout.weight(.semibold))
                .foregroundStyle(DayColor.primaryDeep)
                .frame(width: 112, alignment: .leading)

            Divider()
                .padding(.vertical, 2)

            ledgerItem(title: "执行力", value: metrics.scoreText, detail: metrics.scoreLabel, tint: DayColor.primaryDeep)
            ledgerItem(title: "闭环", value: metrics.closedLoopRate.percentText, detail: "达到标准", tint: DayColor.success)
            ledgerItem(title: "补完成", value: metrics.recoveredRate.percentText, detail: "逾期补回", tint: DayColor.recovered)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .dayPanel(cornerRadius: 12)
        .accessibilityElement(children: .contain)
    }

    private func ledgerItem(title: String, value: String, detail: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Text(value)
                .font(.system(size: 23, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : DayMotion.state, value: value)
                .frame(minWidth: 54, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DayColor.text)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(DayColor.muted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)，\(detail)")
    }
}

private struct LaunchNextActionPanel: View {
    let task: LearningTask?
    let now: Date
    let onStartToday: () -> Void
    let onTaskDetail: () -> Void
    let onNewTask: () -> Void
    let onCreateSampleTask: () -> Void
    let onBeginFocus: (LearningTask) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "下一步行动", systemImage: "figure.run")

            VStack(alignment: .leading, spacing: 10) {
                ForEach(actionRows) { row in
                    LaunchChecklistRow(row: row)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                if let task, task.completedAt == nil {
                    Button {
                        onBeginFocus(task)
                    } label: {
                        Label("开始专注", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else if task != nil {
                    Button(action: onStartToday) {
                        Label("查看今日执行", systemImage: "play.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(action: onNewTask) {
                        Label("创建任务", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button(action: task == nil ? onCreateSampleTask : onTaskDetail) {
                    Label(task == nil ? "体验示例" : "查看详情", systemImage: task == nil ? "sparkles" : "sidebar.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
        .dayPanel(cornerRadius: 12)
    }

    private var actionRows: [LaunchActionRow] {
        guard let task else {
            return [
                LaunchActionRow(icon: "1.circle.fill", title: "录入第一条学习任务", detail: "写清学习方向、内容、deadline 和完成标准。", tint: DayColor.primary),
                LaunchActionRow(icon: "2.circle.fill", title: "不确定怎么填就体验示例", detail: "示例只会在点击后创建，不会自动污染学习记录。", tint: DayColor.squirrel),
                LaunchActionRow(icon: "3.circle.fill", title: "回到今日执行开始专注", detail: "任务创建后，专注、进度和复盘都集中到执行页。", tint: DayColor.success)
            ]
        }

        switch task.status(now: now) {
        case .completed, .recovered:
            return [
                LaunchActionRow(icon: "checkmark.circle.fill", title: "任务已经完成", detail: "补上一句复盘，记录最有价值的收获。", tint: DayColor.success),
                LaunchActionRow(icon: "text.bubble.fill", title: task.reviewNote.nilIfBlank == nil ? "复盘备注待填写" : "复盘备注已记录", detail: task.reviewNote.nilIfBlank ?? "写一句就够，保持闭环习惯。", tint: DayColor.recovered),
                LaunchActionRow(icon: "plus.circle.fill", title: "安排下一颗松果", detail: "继续录入下一条明确 deadline 的学习任务。", tint: DayColor.primary)
            ]
        case .overdue:
            return [
                LaunchActionRow(icon: "exclamationmark.triangle.fill", title: "先处理逾期任务", detail: "记录卡住原因，再决定补完成或调整任务。", tint: DayColor.danger),
                LaunchActionRow(icon: "text.badge.checkmark", title: "对照完成标准推进", detail: task.completionCriteria.nilIfBlank ?? "这个任务还没有完成标准。", tint: DayColor.warning),
                LaunchActionRow(icon: "arrow.triangle.2.circlepath", title: "留下补救记录", detail: task.recoveryNote.nilIfBlank ?? "补救记录为空，后续复盘会缺少依据。", tint: DayColor.recovered)
            ]
        case .warning:
            return [
                LaunchActionRow(icon: "timer", title: "deadline 已经接近", detail: "现在开始一次专注，先推进最小可交付结果。", tint: DayColor.warning),
                LaunchActionRow(icon: "checkmark.seal.fill", title: "确认完成标准", detail: task.completionCriteria.nilIfBlank ?? "这个任务还没有完成标准。", tint: DayColor.primary),
                LaunchActionRow(icon: "chart.line.uptrend.xyaxis", title: "更新进度", detail: "完成一段学习后记录进度，避免只靠记忆判断。", tint: DayColor.success)
            ]
        case .active:
            return [
                LaunchActionRow(icon: "play.circle.fill", title: "开始一次专注", detail: "把当前任务推进一小段，再回到今日执行记录。", tint: DayColor.primary),
                LaunchActionRow(icon: "checkmark.seal.fill", title: "对照完成标准", detail: task.completionCriteria.nilIfBlank ?? "这个任务还没有完成标准。", tint: DayColor.success),
                LaunchActionRow(icon: "calendar.badge.clock", title: "盯住截止时间", detail: task.deadline.formattedDateTime(), tint: DayColor.warning)
            ]
        }
    }
}

private struct LaunchClosureSnapshotPanel: View {
    let task: LearningTask?
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "闭环字段快照", systemImage: "checklist")

            VStack(spacing: 10) {
                LaunchChecklistRow(row: criteriaRow)
                LaunchChecklistRow(row: blockRow)
                LaunchChecklistRow(row: recoveryRow)
                LaunchChecklistRow(row: reviewRow)
            }

            Spacer(minLength: 0)

            Text(summary)
                .font(.callout)
                .foregroundStyle(DayColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .topLeading)
        .dayPanel(cornerRadius: 12)
    }

    private var criteriaRow: LaunchActionRow {
        guard let task else {
            return LaunchActionRow(icon: "circle", title: "完成标准", detail: "还没有任务", tint: DayColor.muted)
        }
        return LaunchActionRow(
            icon: task.completionCriteria.nilIfBlank == nil ? "circle" : "checkmark.circle.fill",
            title: "完成标准",
            detail: task.completionCriteria.nilIfBlank ?? "未填写",
            tint: task.completionCriteria.nilIfBlank == nil ? DayColor.warning : DayColor.success
        )
    }

    private var blockRow: LaunchActionRow {
        guard let task else {
            return LaunchActionRow(icon: "circle", title: "卡住原因", detail: "还没有任务", tint: DayColor.muted)
        }
        return LaunchActionRow(
            icon: task.blockReason.nilIfBlank == nil ? "circle" : "exclamationmark.triangle.fill",
            title: "卡住原因",
            detail: task.blockReason.nilIfBlank ?? "暂无",
            tint: task.blockReason.nilIfBlank == nil ? DayColor.muted : DayColor.warning
        )
    }

    private var recoveryRow: LaunchActionRow {
        guard let task else {
            return LaunchActionRow(icon: "circle", title: "补救记录", detail: "还没有任务", tint: DayColor.muted)
        }
        return LaunchActionRow(
            icon: task.recoveryNote.nilIfBlank == nil ? "circle" : "arrow.triangle.2.circlepath.circle.fill",
            title: "补救记录",
            detail: task.recoveryNote.nilIfBlank ?? "暂无",
            tint: task.recoveryNote.nilIfBlank == nil ? DayColor.muted : DayColor.recovered
        )
    }

    private var reviewRow: LaunchActionRow {
        guard let task else {
            return LaunchActionRow(icon: "circle", title: "复盘备注", detail: "还没有任务", tint: DayColor.muted)
        }
        return LaunchActionRow(
            icon: task.reviewNote.nilIfBlank == nil ? "circle" : "text.bubble.fill",
            title: "复盘备注",
            detail: task.reviewNote.nilIfBlank ?? "暂无",
            tint: task.reviewNote.nilIfBlank == nil ? DayColor.muted : DayColor.primary
        )
    }

    private var summary: String {
        guard let task else {
            return "创建任务后，这里会显示完成标准、卡住原因、补救记录和复盘备注。"
        }
        switch task.status(now: now) {
        case .completed:
            return "任务已按时闭环。复盘为空时，建议补一句收获或下次改进点。"
        case .recovered:
            return "任务已补完成。保留补救记录和复盘，后续评分才有依据。"
        case .overdue:
            return "任务逾期未闭环。优先补齐卡住原因和下一步补救动作。"
        case .warning:
            return "任务接近 deadline。先按完成标准推进，避免只记录进度。"
        case .active:
            return "任务仍在推进。完成标准越清楚，后面的评分和复盘越可信。"
        }
    }
}

private struct LaunchActionRow: Identifiable {
    var id: String { title }
    let icon: String
    let title: String
    let detail: String
    let tint: Color
}

private struct LaunchChecklistRow: View {
    let row: LaunchActionRow

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: row.icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(row.tint)
                .frame(width: 18, height: 18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(DayColor.text)
                    .lineLimit(1)
                Text(row.detail)
                    .font(.caption)
                    .foregroundStyle(DayColor.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
