import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct TodayExecutionView: View {
    let tasks: [LearningTask]
    let sessions: [LearningSession]
    let now: Date
    @Binding var activeFocusTaskID: UUID?
    @Binding var activeFocusOriginalStartedAt: Date?
    @Binding var activeFocusStartedAt: Date?
    @Binding var activeFocusPausedAt: Date?
    @Binding var activeFocusAccumulatedSeconds: Double
    @Binding var activeFocusNote: String
    @Binding var selectedTaskID: UUID?
    let onBeginFocus: (LearningTask) -> Void
    let onPauseFocus: () -> Void
    let onResumeFocus: () -> Void
    let onFinishFocus: (String) -> Void
    let onUpdateProgress: (LearningTask, Double, String) -> Void
    let onMarkComplete: (LearningTask) -> Void

    private var incompleteTasks: [LearningTask] {
        tasks.filter { $0.completedAt == nil }
    }

    private var activeTask: LearningTask? {
        activeFocusTaskID.flatMap { id in tasks.first(where: { $0.id == id }) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageTitle(title: "今日执行", subtitle: "开始专注、记录学习时段、更新完成度，动作都集中在这里。")

                FocusSessionPanel(
                    activeTask: activeTask,
                    originalStartedAt: activeFocusOriginalStartedAt,
                    startedAt: activeFocusStartedAt,
                    pausedAt: activeFocusPausedAt,
                    accumulatedSeconds: activeFocusAccumulatedSeconds,
                    note: $activeFocusNote,
                    onPause: onPauseFocus,
                    onResume: onResumeFocus,
                    onFinish: onFinishFocus
                )

                HStack(spacing: 12) {
                    MetricCard(title: "待完成任务", value: "\(incompleteTasks.count)", subtitle: "未闭环任务", tint: DayColor.primary)
                    MetricCard(title: "今日专注", value: "\(todayFocusMinutes)", subtitle: "分钟", tint: DayColor.success)
                    MetricCard(title: "逾期未完成", value: "\(TaskCollectionStatusPolicy.overdueOpenCount(tasks: tasks, now: now))", subtitle: "优先处理", tint: DayColor.danger)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "执行队列", systemImage: "list.bullet.rectangle")
                    if incompleteTasks.isEmpty {
                        EmptyStateView(
                            title: tasks.isEmpty ? "还没有任务" : "任务完成啦，开始干饭！",
                            subtitle: tasks.isEmpty ? "先新建一个任务，再开始记录学习时段。" : "今天没有待完成任务，小松鼠已经抱着松果收工。"
                        )
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
        .background(isSelected ? DayColor.selected : DayColor.workbench, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? DayColor.primary.opacity(0.45) : DayColor.border, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}
