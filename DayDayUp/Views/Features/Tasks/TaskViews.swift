import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct TaskManagementView: View {
    let tasks: [LearningTask]
    @Binding var selectedTaskID: UUID?
    let onNewTask: () -> Void
    let onEditTask: (LearningTask) -> Void
    let onBeginFocus: (LearningTask) -> Void
    let onMarkComplete: (LearningTask) -> Void

    @State private var filter: TaskFilter = .all
    @State private var searchText = ""

    private var filteredTasks: [LearningTask] {
        tasks
            .filter { task in
                switch filter {
                case .all: true
                case .today: task.isRelevantToday()
                case .incomplete: task.completedAt == nil || !task.isClosedLoop
                case .active: task.status() == .active || task.status() == .warning
                case .overdue: task.status() == .overdue
                case .completed: task.status() == .completed
                case .recovered: task.status() == .recovered
                case .early: task.isEarlyCompleted
                }
            }
            .filter { task in
                let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty else { return true }
                return task.name.localizedCaseInsensitiveContains(query)
                    || task.details.localizedCaseInsensitiveContains(query)
                    || task.direction.localizedCaseInsensitiveContains(query)
                    || task.completionCriteria.localizedCaseInsensitiveContains(query)
                    || task.resourceLink.localizedCaseInsensitiveContains(query)
                    || task.notes.localizedCaseInsensitiveContains(query)
            }
            .sortedForExecution()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageTitle(title: "任务管理", subtitle: "只负责录入、编辑、筛选和监督，不替你拆解学习路线。")

            HStack(spacing: 12) {
                Picker("筛选", selection: $filter) {
                    ForEach(TaskFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minWidth: 520, idealWidth: 640, maxWidth: 660)
                .accessibilityLabel("任务筛选")

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(DayColor.muted)
                        .accessibilityHidden(true)
                    TextField("搜索任务", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 10)
                .frame(width: 260, height: 30)
                .background(DayColor.workbench.opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DayColor.border.opacity(0.68), lineWidth: 1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("搜索任务")

                Spacer()

                Button(action: onNewTask) {
                    Label("新建任务", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("n", modifiers: [.command])
            }

            if filteredTasks.isEmpty {
                EmptyStateView(
                    title: tasks.isEmpty ? "还没有任务" : "没有匹配任务",
                    subtitle: tasks.isEmpty ? "新建任务后，这里会显示任务列表和状态。" : "调整筛选条件，或者新建一个任务。"
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredTasks, id: \.id) { task in
                            TaskManagementRow(
                                task: task,
                                isSelected: selectedTaskID == task.id,
                                onSelect: { selectedTaskID = task.id },
                                onEdit: { onEditTask(task) },
                                onBeginFocus: { onBeginFocus(task) },
                                onMarkComplete: { onMarkComplete(task) }
                            )
                        }
                    }
                    .padding(10)
                }
                .scrollContentBackground(.hidden)
                .background(DayColor.workbench.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DayColor.border.opacity(0.58), lineWidth: 1)
                }
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
        }
        .padding(28)
        .dayPageBackground()
    }
}

struct TaskEditorSheet: View {
    let task: LearningTask?
    let onSave: (TaskDraft) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var details: String
    @State private var direction: String
    @State private var deadline: Date
    @State private var estimatedMinutes: Int
    @State private var progress: Double
    @State private var completionCriteria: String
    @State private var resourceLink: String
    @State private var notes: String

    init(task: LearningTask?, onSave: @escaping (TaskDraft) -> Void) {
        self.task = task
        self.onSave = onSave
        let draft = TaskDraft(task: task)
        _name = State(initialValue: draft.name)
        _details = State(initialValue: draft.details)
        _direction = State(initialValue: draft.direction)
        _deadline = State(initialValue: draft.deadline)
        _estimatedMinutes = State(initialValue: draft.estimatedMinutes)
        _progress = State(initialValue: draft.progress)
        _completionCriteria = State(initialValue: draft.completionCriteria)
        _resourceLink = State(initialValue: draft.resourceLink)
        _notes = State(initialValue: draft.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基础信息") {
                    TextField("任务名称", text: $name)
                        .accessibilityLabel("任务名称")
                    TextField("学习方向", text: $direction)
                        .accessibilityLabel("学习方向")
                    DeadlinePicker(deadline: $deadline)
                    Stepper(value: $estimatedMinutes, in: 15...1440, step: 15) {
                        Text("预计时长 \(estimatedMinutes) 分钟")
                    }
                }

                Section("任务内容") {
                    DayTextEditor(text: $details, minHeight: 92, label: "任务内容")
                    TextField("完成标准", text: $completionCriteria, axis: .vertical)
                    TextField("资料链接", text: $resourceLink)
                }

                Section("当前完成度") {
                    HStack {
                        Slider(value: $progress, in: 0...1, step: 0.05)
                        Text(progress.percentText)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 52, alignment: .trailing)
                    }
                    .accessibilityLabel("当前完成度 \(progress.percentText)")
                }

                Section("备注") {
                    DayTextEditor(text: $notes, minHeight: 70, label: "备注")
                }
            }
            .formStyle(.grouped)
            .navigationTitle(task == nil ? "新建任务" : "编辑任务")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(task == nil ? "创建任务" : "保存任务") {
                        var draft = TaskDraft(task: task)
                        draft.name = name
                        draft.details = details
                        draft.direction = direction
                        draft.deadline = deadline
                        draft.estimatedMinutes = estimatedMinutes
                        draft.progress = progress
                        draft.completionCriteria = completionCriteria
                        draft.resourceLink = resourceLink
                        draft.notes = notes
                        onSave(draft)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
    }
}

struct DeadlinePicker: View {
    @Binding var deadline: Date

    private var hourBinding: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.hour, from: deadline) },
            set: { hour in
                setTime(hour: hour, minute: Calendar.current.component(.minute, from: deadline))
            }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.minute, from: deadline) },
            set: { minute in
                setTime(hour: Calendar.current.component(.hour, from: deadline), minute: minute)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("截止时间", systemImage: "calendar.badge.clock")
                .font(.callout.weight(.semibold))
                .foregroundStyle(DayColor.text)

            DatePicker("截止日期", selection: $deadline, displayedComponents: [.date])
                .datePickerStyle(.graphical)
                .labelsHidden()
                .frame(maxWidth: .infinity, minHeight: 226, alignment: .leading)
                .accessibilityLabel("截止日期")

            HStack(spacing: 12) {
                Stepper(value: hourBinding, in: 0...23) {
                    Text("小时 \(Calendar.current.component(.hour, from: deadline))")
                        .frame(minWidth: 86, alignment: .leading)
                }

                Stepper(value: minuteBinding, in: 0...59, step: 5) {
                    Text("分钟 \(Calendar.current.component(.minute, from: deadline))")
                        .frame(minWidth: 86, alignment: .leading)
                }

                Spacer()

                Text(deadline.formattedDateTime())
                    .font(.system(.callout, design: .monospaced).weight(.semibold))
                    .foregroundStyle(DayColor.primary)
            }
        }
        .padding(14)
        .dayPanel(cornerRadius: 12)
        .accessibilityElement(children: .contain)
    }

    private func setTime(hour: Int, minute: Int) {
        let calendar = Calendar.current
        let clampedHour = min(max(hour, 0), 23)
        let clampedMinute = min(max(minute, 0), 59)
        deadline = calendar.date(
            bySettingHour: clampedHour,
            minute: clampedMinute,
            second: 0,
            of: deadline
        ) ?? deadline
    }
}

struct TaskDetailInspector: View {
    @Bindable var task: LearningTask
    let events: [TaskEvent]
    let sessions: [LearningSession]
    let achievements: [AchievementRecord]
    let onEditTask: (LearningTask) -> Void
    let onBeginFocus: (LearningTask) -> Void
    let onMarkComplete: (LearningTask) -> Void
    let onRecordBlock: (LearningTask, String) -> Void
    let onRecordRecovery: (LearningTask, String) -> Void
    let onSaveReview: (LearningTask, String) -> Void
    let onDeleteTask: (LearningTask) -> Void

    @State private var blockDraft = ""
    @State private var recoveryDraft = ""
    @State private var reviewDraft = ""
    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(task.name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(DayColor.text)
                            .fixedSize(horizontal: false, vertical: true)
                        StatusBadge(status: task.status())
                    }
                    Spacer()
                    Menu {
                        Button("编辑任务") { onEditTask(task) }
                        Button("开始专注") { onBeginFocus(task) }
                            .disabled(task.completedAt != nil)
                        Button("标记完成") { onMarkComplete(task) }
                            .disabled(task.completedAt != nil)
                        Divider()
                        Button("删除任务", role: .destructive) { confirmingDelete = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                    .menuStyle(.button)
                    .accessibilityLabel("任务更多操作")
                }

                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(value: task.progress)
                        .tint(task.status().color)
                        .accessibilityLabel("完成度 \(task.progress.percentText)")
                    Text("完成度 \(task.progress.percentText)")
                        .font(.caption)
                        .foregroundStyle(DayColor.muted)
                }

                InspectorFactGrid(task: task, sessions: sessions)
                RelatedAchievementsPanel(achievements: achievements)

                InspectorTextBlock(title: "任务内容", text: task.details.nilIfBlank ?? "未填写")
                InspectorTextBlock(title: "完成标准", text: task.completionCriteria.nilIfBlank ?? "未填写")
                if let resourceURL {
                    Link(destination: resourceURL) {
                        Label("打开学习资料", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "卡住原因", systemImage: "exclamationmark.triangle")
                    DayTextEditor(text: $blockDraft, minHeight: 76, label: "卡住原因")
                    Button {
                        onRecordBlock(task, blockDraft)
                        blockDraft = ""
                    } label: {
                        Label("记录卡住原因", systemImage: "square.and.pencil")
                    }
                    .disabled(blockDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    InspectorTextBlock(title: "已记录", text: task.blockReason.nilIfBlank ?? "暂无")
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "补救记录", systemImage: "arrow.triangle.2.circlepath")
                    DayTextEditor(text: $recoveryDraft, minHeight: 72, label: "补救记录")
                    Button {
                        onRecordRecovery(task, recoveryDraft)
                        recoveryDraft = ""
                    } label: {
                        Label(task.completedAt == nil && task.status() == .overdue ? "补完成" : "保存补救记录", systemImage: "checkmark.circle")
                    }
                    InspectorTextBlock(title: "已记录", text: task.recoveryNote.nilIfBlank ?? "暂无")
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "复盘备注", systemImage: "text.bubble")
                    DayTextEditor(text: $reviewDraft, minHeight: 84, label: "复盘备注")
                    Button {
                        onSaveReview(task, reviewDraft)
                        reviewDraft = ""
                    } label: {
                        Label("保存复盘", systemImage: "tray.and.arrow.down")
                    }
                    .disabled(reviewDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    InspectorTextBlock(title: "已记录", text: task.reviewNote.nilIfBlank ?? "暂无")
                }
            }
            .padding(20)
        }
        .dayPageBackground()
        .confirmationDialog("确认删除这个任务？", isPresented: $confirmingDelete) {
            Button("删除任务", role: .destructive) {
                onDeleteTask(task)
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("任务、学习时段和学习历程事件都会被删除。")
        }
        .onAppear {
            blockDraft = task.blockReason
            recoveryDraft = task.recoveryNote
            reviewDraft = task.reviewNote
        }
    }

    private var resourceURL: URL? {
        guard let link = task.resourceLink.nilIfBlank else { return nil }
        if let url = URL(string: link), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(link)")
    }
}

struct TaskManagementRow: View {
    let task: LearningTask
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onBeginFocus: () -> Void
    let onMarkComplete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: task.status().symbolName)
                .font(.title3)
                .foregroundStyle(task.status().color)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(task.name)
                        .font(.headline)
                    StatusBadge(status: task.status())
                }
                Text(task.details.nilIfBlank ?? "未填写任务内容")
                    .font(.callout)
                    .foregroundStyle(DayColor.muted)
                    .lineLimit(1)
                HStack(spacing: 12) {
                    Label(task.deadline.formattedDateTime(), systemImage: "calendar")
                    Label(task.progress.percentText, systemImage: "chart.line.uptrend.xyaxis")
                    Label(task.isClosedLoop ? "已闭环" : "未闭环", systemImage: task.isClosedLoop ? "link.circle.fill" : "link.circle")
                }
                .font(.caption)
                .foregroundStyle(DayColor.muted)
            }
            Spacer()
            Button("编辑", action: onEdit)
            Button("开始", action: onBeginFocus)
                .disabled(task.completedAt != nil)
            Button("完成", action: onMarkComplete)
                .disabled(task.completedAt != nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? DayColor.primary.opacity(0.56) : Color.clear, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture(perform: onSelect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.name)，\(task.status().accessibilityText)，完成度 \(task.progress.percentText)")
    }

    private var rowBackground: Color {
        if isSelected {
            return DayColor.selected.opacity(0.82)
        }
        return DayColor.workbench.opacity(0.64)
    }
}

struct InspectorFactGrid: View {
    let task: LearningTask
    let sessions: [LearningSession]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            FactTile(title: "制定日期", value: task.plannedAt.formattedShortDate())
            FactTile(title: "开始日期", value: task.startedAt?.formattedShortDate() ?? "未开始")
            FactTile(title: "Deadline", value: task.deadline.formattedShortDate())
            FactTile(title: "完成日期", value: task.completedAt?.formattedShortDate() ?? "未完成")
            FactTile(title: "延期时长", value: task.delayedDays > 0 ? "\(task.delayedDays) 天" : "0 天")
            FactTile(title: "专注时长", value: "\(sessions.reduce(0) { $0 + $1.durationMinutes }) 分钟")
        }
    }
}

struct FactTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DayColor.muted)
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(DayColor.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .dayPanel(cornerRadius: 8)
    }
}

struct InspectorTextBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DayColor.muted)
            Text(text)
                .font(.callout)
                .foregroundStyle(DayColor.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .dayPanel(cornerRadius: 10)
    }
}
