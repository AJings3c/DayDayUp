import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct TodayExecutionView: View {
    let tasks: [LearningTask]
    let now: Date
    @Query(sort: \LearningSession.startedAt, order: .reverse) private var sessions: [LearningSession]
    @Bindable var focusController: FocusSessionController
    @Binding var selectedTaskID: UUID?
    let onBeginFocus: (LearningTask) -> Void
    let onPauseFocus: () -> Void
    let onResumeFocus: () -> Void
    let onFinishFocus: (String) -> Void
    let onUpdateFocusNote: (String) -> Void
    let onUpdateProgress: (LearningTask, Double, String) -> Void
    let onMarkComplete: (LearningTask) -> Void
    let onNewTask: () -> Void
    let onCreateSampleTask: () -> Void

    private var incompleteTasks: [LearningTask] {
        tasks.filter { $0.completedAt == nil }
    }

    private var activeTask: LearningTask? {
        focusController.taskID.flatMap { id in tasks.first(where: { $0.id == id }) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageTitle(title: "今日执行", subtitle: "选一颗松果，专注推进，再留下记录。")

                FocusSessionPanel(
                    activeTask: activeTask,
                    originalStartedAt: focusController.originalStartedAt,
                    startedAt: focusController.currentStartedAt,
                    pausedAt: focusController.pausedAt,
                    accumulatedSeconds: focusController.accumulatedSeconds,
                    note: Binding(
                        get: { focusController.draftNote },
                        set: { note in onUpdateFocusNote(note) }
                    ),
                    onPause: onPauseFocus,
                    onResume: onResumeFocus,
                    onFinish: onFinishFocus
                )

                TodayPulseLedger(
                    incompleteCount: incompleteTasks.count,
                    focusMinutes: todayFocusMinutes,
                    overdueCount: TaskCollectionStatusPolicy.overdueOpenCount(tasks: tasks, now: now)
                )

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "执行队列", systemImage: "list.bullet.rectangle")
                    if incompleteTasks.isEmpty {
                        if tasks.isEmpty {
                            FirstTaskEmptyState(onNewTask: onNewTask, onCreateSampleTask: onCreateSampleTask)
                        } else {
                            EmptyStateView(
                                title: "任务完成啦，开始干饭！",
                                subtitle: "今天没有待完成任务，小松鼠已经抱着松果收工。"
                            )
                        }
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(incompleteTasks, id: \.id) { task in
                                TaskProgressRow(
                                    task: task,
                                    isSelected: selectedTaskID == task.id,
                                    now: now,
                                    onSelect: { selectedTaskID = task.id },
                                    onBeginFocus: onBeginFocus,
                                    onUpdateProgress: onUpdateProgress,
                                    onMarkComplete: onMarkComplete
                                )
                            }
                        }
                        TodayClosureGuidePanel(
                            selectedTask: selectedTask ?? incompleteTasks.first,
                            now: now,
                            overdueCount: TaskCollectionStatusPolicy.overdueOpenCount(tasks: tasks, now: now)
                        )
                    }
                }
            }
            .padding(28)
        }
        .dayPageBackground()
    }

    private var todayFocusMinutes: Int {
        let today = now.dayKey()
        return sessions
            .filter { $0.startedAt.dayKey() == today }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    private var selectedTask: LearningTask? {
        selectedTaskID.flatMap { id in incompleteTasks.first(where: { $0.id == id }) }
    }
}

private struct TodayPulseLedger: View {
    let incompleteCount: Int
    let focusMinutes: Int
    let overdueCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            Label("今日脉搏", systemImage: "waveform.path")
                .font(.callout.weight(.semibold))
                .foregroundStyle(DayColor.primaryDeep)
                .frame(width: 112, alignment: .leading)

            Divider().padding(.vertical, 2)
            item(value: "\(incompleteCount)", label: "待完成", tint: DayColor.primary)
            item(value: "\(focusMinutes)", label: "专注分钟", tint: DayColor.success)
            item(value: "\(overdueCount)", label: "逾期待补", tint: overdueCount > 0 ? DayColor.danger : DayColor.muted)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .dayPanel(cornerRadius: 12)
    }

    private func item(value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(value)
                .font(.system(size: 23, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : DayMotion.state, value: value)
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(DayColor.muted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }
}

private struct TodayClosureGuidePanel: View {
    let selectedTask: LearningTask?
    let now: Date
    let overdueCount: Int

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "今日收尾清单", systemImage: "checklist")
                ForEach(rows) { row in
                    TodayGuideRow(row: row)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .dayPanel(cornerRadius: 12)

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "执行判断", systemImage: "scope")
                Text(summaryTitle)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(summaryTint)
                Text(summaryText)
                    .font(.callout)
                    .foregroundStyle(DayColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if let selectedTask {
                    HStack {
                        StatusBadge(status: selectedTask.status(now: now))
                        Text(selectedTask.deadline.formattedDateTime())
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(DayColor.muted)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .dayPanel(cornerRadius: 12)
        }
    }

    private var rows: [TodayGuideItem] {
        guard let selectedTask else {
            return [
                TodayGuideItem(icon: "play.circle.fill", title: "选择任务", detail: "从执行队列里选择一条任务开始。", tint: DayColor.primary),
                TodayGuideItem(icon: "chart.line.uptrend.xyaxis", title: "记录进度", detail: "学习后更新完成度和备注。", tint: DayColor.success),
                TodayGuideItem(icon: "text.bubble.fill", title: "完成后复盘", detail: "闭环时补一句收获或卡点。", tint: DayColor.recovered)
            ]
        }

        return [
            TodayGuideItem(icon: "play.circle.fill", title: "先开始一次专注", detail: "当前任务：\(selectedTask.name)", tint: DayColor.primary),
            TodayGuideItem(icon: "checkmark.seal.fill", title: "对照完成标准", detail: selectedTask.completionCriteria.nilIfBlank ?? "这个任务还没有完成标准。", tint: DayColor.success),
            TodayGuideItem(icon: "square.and.pencil", title: "留下可复盘记录", detail: "进度、卡住原因和复盘备注都会进入学习历程。", tint: DayColor.recovered)
        ]
    }

    private var summaryTitle: String {
        guard let selectedTask else { return "今天还没有选中任务" }
        switch selectedTask.status(now: now) {
        case .overdue: return "先处理逾期闭环"
        case .warning: return "deadline 已经接近"
        case .active: return overdueCount > 0 ? "有逾期任务待处理" : "节奏仍可控"
        case .completed: return "任务已闭环"
        case .recovered: return "任务已补完成"
        }
    }

    private var summaryText: String {
        guard let selectedTask else {
            return "选择任务后，这里会显示今日执行判断和截止时间。"
        }
        switch selectedTask.status(now: now) {
        case .overdue:
            return "deadline 已过，先记录卡住原因，再推进补救动作。"
        case .warning:
            return "先做能接近完成标准的一小步，避免只记录无效进度。"
        case .active:
            return "任务尚未逾期。完成一次专注后，记得更新进度备注。"
        case .completed:
            return "任务已经完成，补一句复盘能让评分更完整。"
        case .recovered:
            return "任务已经补完成，补救记录会帮助后续复盘拖延原因。"
        }
    }

    private var summaryTint: Color {
        guard let selectedTask else { return DayColor.muted }
        return selectedTask.status(now: now).color
    }
}

private struct TodayGuideItem: Identifiable {
    var id: String { title }
    let icon: String
    let title: String
    let detail: String
    let tint: Color
}

private struct TodayGuideRow: View {
    let row: TodayGuideItem

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

private struct FirstTaskEmptyState: View {
    let onNewTask: () -> Void
    let onCreateSampleTask: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            EmptyStateView(
                title: "从第一颗松果开始",
                subtitle: "创建一个有 deadline 和完成标准的学习任务，DayDayUp 会帮你监督执行、提醒和复盘。"
            )
            HStack(spacing: 10) {
                Button(action: onNewTask) {
                    Label("创建第一个学习任务", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)

                Button(action: onCreateSampleTask) {
                    Label("用示例任务体验", systemImage: "sparkles")
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

struct FocusSessionPanel: View {
    let activeTask: LearningTask?
    let originalStartedAt: Date?
    let startedAt: Date?
    let pausedAt: Date?
    let accumulatedSeconds: Double
    @Binding var note: String
    let onPause: () -> Void
    let onResume: () -> Void
    let onFinish: (String) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "当前专注", systemImage: "timer")
            if let activeTask, let originalStartedAt {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(activeTask.name)
                                .font(.title3.weight(.semibold))
                            if pausedAt != nil {
                                Label("已暂停", systemImage: "pause.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(DayColor.warning)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(DayColor.warning.opacity(0.12), in: Capsule())
                            }
                        }
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            Text("已专注 \(activeDurationString(now: context.date))")
                                .font(.system(.title2, design: .monospaced).weight(.semibold))
                                .foregroundStyle(pausedAt == nil ? DayColor.primary : DayColor.warning)
                                .contentTransition(.numericText())
                                .animation(reduceMotion ? nil : DayMotion.state, value: activeDurationString(now: context.date))
                        }
                        Text("开始时间：\(originalStartedAt.formattedDateTime())")
                            .font(.caption)
                            .foregroundStyle(DayColor.muted)
                        if let pausedAt {
                            Text("暂停时间：\(pausedAt.formattedDateTime())")
                                .font(.caption)
                                .foregroundStyle(DayColor.muted)
                        }
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 8) {
                        DayTextEditor(text: $note, minHeight: 82, width: 280, label: "本次学习备注")
                        HStack(spacing: 8) {
                            Button {
                                if pausedAt == nil {
                                    onPause()
                                } else {
                                    onResume()
                                }
                            } label: {
                                Label(pausedAt == nil ? "暂停" : "继续", systemImage: pausedAt == nil ? "pause.fill" : "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                onFinish(note)
                            } label: {
                                Label("结束并记录", systemImage: "stop.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "play.circle")
                        .font(.largeTitle)
                        .foregroundStyle(DayColor.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("还没有开始专注")
                            .font(.headline)
                        Text("从下方执行队列选择一个任务，开始记录学习时段。")
                            .font(.callout)
                            .foregroundStyle(DayColor.muted)
                    }
                }
            }
        }
        .padding(18)
        .dayLiquidPanel(cornerRadius: 16, interactive: true, emphasized: activeTask != nil)
        .animation(reduceMotion ? nil : DayMotion.state, value: activeTask?.id)
        .animation(reduceMotion ? nil : DayMotion.feedback, value: pausedAt)
    }

    private func activeDurationString(now: Date) -> String {
        let runningSeconds = startedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0
        return durationString(seconds: accumulatedSeconds + runningSeconds)
    }
}

struct TaskProgressRow: View {
    @Bindable var task: LearningTask
    let isSelected: Bool
    let now: Date
    let onSelect: () -> Void
    let onBeginFocus: (LearningTask) -> Void
    let onUpdateProgress: (LearningTask, Double, String) -> Void
    let onMarkComplete: (LearningTask) -> Void

    @State private var progressDraft: Double
    @State private var noteDraft = ""
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        task: LearningTask,
        isSelected: Bool,
        now: Date,
        onSelect: @escaping () -> Void,
        onBeginFocus: @escaping (LearningTask) -> Void,
        onUpdateProgress: @escaping (LearningTask, Double, String) -> Void,
        onMarkComplete: @escaping (LearningTask) -> Void
    ) {
        self.task = task
        self.isSelected = isSelected
        self.now = now
        self.onSelect = onSelect
        self.onBeginFocus = onBeginFocus
        self.onUpdateProgress = onUpdateProgress
        self.onMarkComplete = onMarkComplete
        _progressDraft = State(initialValue: task.progress)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onSelect) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(task.name)
                                .font(.headline)
                                .foregroundStyle(DayColor.text)
                            Spacer()
                            StatusBadge(status: task.status(now: now))
                        }
                        Text(task.details.nilIfBlank ?? "未填写任务内容")
                            .font(.callout)
                            .foregroundStyle(DayColor.muted)
                            .lineLimit(2)
                        Label("截止时间：\(task.deadline.formattedDateTime())", systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(DayColor.muted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                Slider(value: $progressDraft, in: 0...1, step: 0.05)
                    .accessibilityLabel("任务完成度")
                Text(progressDraft.percentText)
                    .font(.system(.body, design: .monospaced))
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : DayMotion.feedback, value: progressDraft)
                    .frame(width: 54, alignment: .trailing)
                TextField("进度备注", text: $noteDraft)
                    .textFieldStyle(.roundedBorder)
                Button("记录") {
                    onUpdateProgress(task, progressDraft, noteDraft)
                    noteDraft = ""
                }
                Button {
                    onBeginFocus(task)
                } label: {
                    Label("开始", systemImage: "play.fill")
                }
                Button {
                    onMarkComplete(task)
                } label: {
                    Label("完成", systemImage: "checkmark")
                }
            }
        }
        .padding(16)
        .background(
            isSelected ? DayColor.selected : (isHovered ? DayColor.hover : DayColor.workbench),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? DayColor.primary.opacity(0.62) : DayColor.border, lineWidth: 1)
        )
        .scaleEffect(isHovered && !reduceMotion ? 1.002 : 1)
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : DayMotion.feedback, value: isHovered)
        .animation(reduceMotion ? nil : DayMotion.state, value: isSelected)
        .accessibilityElement(children: .contain)
    }
}
