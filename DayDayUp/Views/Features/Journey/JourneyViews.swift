import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct LearningJourneyView: View {
    let tasks: [LearningTask]
    let sessions: [LearningSession]
    let events: [TaskEvent]
    let achievements: [AchievementRecord]
    @Binding var selectedTaskID: UUID?
    @State private var filter: TaskFilter = .all
    @State private var showsOpenLoopsOnly = false

    private var selectedTask: LearningTask? {
        selectedTaskID.flatMap { id in filteredTasks.first(where: { $0.id == id }) }
            ?? filteredTasks.first
    }

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
                showsOpenLoopsOnly ? !task.isClosedLoop : true
            }
            .sortedForJourney()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageTitle(title: "学习历程", subtitle: "以每个任务为单位归档，查看从制定计划到闭环复盘的完整链路。")

            HStack {
                Picker("历程筛选", selection: $filter) {
                    ForEach(TaskFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 660)

                Spacer()

                Toggle("只看未闭环", isOn: $showsOpenLoopsOnly)
                    .toggleStyle(.switch)
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "任务归档", systemImage: "archivebox")
                    if filteredTasks.isEmpty {
                        EmptyStateView(title: "暂无归档", subtitle: "完成一次任务后，这里会沉淀完整学习历程。")
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredTasks, id: \.id) { task in
                                    JourneyArchiveRow(
                                        task: task,
                                        isSelected: selectedTaskID == task.id,
                                        onSelect: { selectedTaskID = task.id }
                                    )
                                }
                            }
                        }
                    }
                }
                .frame(width: 300)

                if let selectedTask {
                    JourneyTaskDetail(
                        task: selectedTask,
                        events: events.filter { $0.taskID == selectedTask.id },
                        sessions: sessions.filter { $0.taskID == selectedTask.id },
                        achievements: achievements.filter { $0.relatedTaskID == selectedTask.id }
                    )
                } else {
                    EmptyStateView(title: "选择一个任务", subtitle: "查看闭环、完成度、延期时长、卡住原因、补救记录和复盘。")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(28)
        .dayPageBackground()
    }
}

struct JourneyArchiveRow: View {
    let task: LearningTask
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(task.name)
                        .font(.headline)
                        .foregroundStyle(DayColor.text)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: task.status().symbolName)
                        .foregroundStyle(task.status().color)
                }
                Text(task.isClosedLoop ? "已闭环" : "未闭环")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(task.isClosedLoop ? DayColor.success : DayColor.danger)
                HStack {
                    Text("完成度 \(task.progress.percentText)")
                    Spacer()
                    Text(task.delayedDays > 0 ? "延期 \(task.delayedDays) 天" : "未延期")
                }
                .font(.caption)
                .foregroundStyle(DayColor.muted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? DayColor.selected : DayColor.workbench, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? DayColor.primary.opacity(0.5) : DayColor.border))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(task.name)，\(task.isClosedLoop ? "已闭环" : "未闭环")，\(task.status().accessibilityText)")
    }
}

struct JourneyTaskDetail: View {
    let task: LearningTask
    let events: [TaskEvent]
    let sessions: [LearningSession]
    let achievements: [AchievementRecord]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(task.name)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(DayColor.primaryDeep)
                        Text(task.direction.nilIfBlank ?? "未填写学习方向")
                            .font(.callout)
                            .foregroundStyle(DayColor.muted)
                    }
                    Spacer()
                    StatusBadge(status: task.status())
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    JourneyMetric(title: "闭环状态", value: task.isClosedLoop ? "已闭环" : "未闭环", tint: task.isClosedLoop ? DayColor.success : DayColor.danger)
                    JourneyMetric(title: "完成度", value: task.progress.percentText, tint: task.status().color)
                    JourneyMetric(title: "延期时长", value: task.delayedDays > 0 ? "\(task.delayedDays) 天" : "0 天", tint: task.delayedDays > 0 ? DayColor.danger : DayColor.success)
                    JourneyMetric(title: "专注时长", value: "\(sessions.reduce(0) { $0 + $1.durationMinutes }) 分钟", tint: DayColor.primary)
                }

                RelatedAchievementsPanel(achievements: achievements)

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "关键日期", systemImage: "calendar.badge.clock")
                    JourneyDateRow(label: "制定计划", date: task.plannedAt)
                    JourneyDateRow(label: "开始执行", date: task.startedAt)
                    JourneyDateRow(label: "截止时间", date: task.deadline)
                    JourneyDateRow(label: task.status() == .recovered ? "补完成时间" : "完成时间", date: task.completedAt)
                }
                .padding(16)
                .dayPanel(cornerRadius: 12)

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "时间线", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    EventTimelineList(events: timelineEvents)
                }
                .padding(16)
                .dayPanel(cornerRadius: 12)

                HStack(alignment: .top, spacing: 12) {
                    InspectorTextBlock(title: "卡住原因", text: task.blockReason.nilIfBlank ?? "暂无记录")
                    InspectorTextBlock(title: "补救记录", text: task.recoveryNote.nilIfBlank ?? "暂无记录")
                    InspectorTextBlock(title: "复盘备注", text: task.reviewNote.nilIfBlank ?? "暂无记录")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timelineEvents: [TaskEvent] {
        events.sorted { $0.occurredAt < $1.occurredAt }
    }
}

struct EventTimelineList: View {
    let events: [TaskEvent]

    var body: some View {
        if events.isEmpty {
            Text("暂无事件记录")
                .font(.callout)
                .foregroundStyle(DayColor.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Image(systemName: event.type.symbolName)
                                .foregroundStyle(eventColor(event))
                                .frame(width: 24, height: 24)
                            if index < events.count - 1 {
                                Rectangle()
                                    .fill(DayColor.border)
                                    .frame(width: 1, height: 42)
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.type.title)
                                .font(.headline)
                                .foregroundStyle(eventColor(event))
                            Text(event.occurredAt.formattedDateTime())
                                .font(.caption)
                                .foregroundStyle(DayColor.muted)
                            Text(event.note.nilIfBlank ?? "无备注")
                                .font(.callout)
                                .foregroundStyle(DayColor.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func eventColor(_ event: TaskEvent) -> Color {
        switch event.type {
        case .completed: DayColor.success
        case .recovered: DayColor.recovered
        case .deadline, .blocked: DayColor.danger
        case .started: DayColor.primary
        case .planned, .progress, .reviewed: DayColor.muted
        }
    }
}

struct JourneyMetric: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DayColor.muted)
            Text(value)
                .font(.system(.title3, design: .monospaced).weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(tint.opacity(0.35)))
    }
}

struct JourneyDateRow: View {
    let label: String
    let date: Date?

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(DayColor.muted)
            Spacer()
            Text(date?.formattedDateTime() ?? "暂无")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(DayColor.text)
        }
        .font(.callout)
    }
}
