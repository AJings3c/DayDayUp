import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum AppSection: String, CaseIterable, Identifiable, Hashable {
    case launch
    case today
    case tasks
    case score
    case journey
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .launch: "启动倒计时"
        case .today: "今日执行"
        case .tasks: "任务管理"
        case .score: "数据评分"
        case .journey: "学习历程"
        case .settings: "设置与备份"
        }
    }

    var symbolName: String {
        switch self {
        case .launch: "timer"
        case .today: "play.circle"
        case .tasks: "checklist"
        case .score: "chart.xyaxis.line"
        case .journey: "point.topleft.down.curvedto.point.bottomright.up"
        case .settings: "gearshape"
        }
    }
}

enum TaskFilter: String, CaseIterable, Identifiable {
    case all
    case today
    case incomplete
    case active
    case overdue
    case completed
    case recovered
    case early

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .today: "今日"
        case .incomplete: "未完成"
        case .active: "进行中"
        case .overdue: "逾期"
        case .completed: "已完成"
        case .recovered: "补完成"
        case .early: "提前完成"
        }
    }
}

struct TaskDraft {
    var name: String
    var details: String
    var direction: String
    var deadline: Date
    var estimatedMinutes: Int
    var progress: Double
    var completionCriteria: String
    var resourceLink: String
    var notes: String

    init(task: LearningTask? = nil) {
        let calendar = Calendar.current
        let defaultDeadline = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: .now.addingTimeInterval(24 * 60 * 60))
            ?? .now.addingTimeInterval(24 * 60 * 60)

        name = task?.name ?? ""
        details = task?.details ?? ""
        direction = task?.direction ?? ""
        deadline = task?.deadline ?? defaultDeadline
        estimatedMinutes = task?.estimatedMinutes ?? 60
        progress = task?.progress ?? 0
        completionCriteria = task?.completionCriteria ?? ""
        resourceLink = task?.resourceLink ?? ""
        notes = task?.notes ?? ""
    }
}

struct AppBootstrapView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \LearningTask.deadline) private var tasks: [LearningTask]
    @Query(sort: \LearningSession.startedAt, order: .reverse) private var sessions: [LearningSession]
    @Query(sort: \TaskEvent.occurredAt, order: .reverse) private var events: [TaskEvent]
    @Query(sort: \AchievementRecord.unlockedAt, order: .reverse) private var achievements: [AchievementRecord]
    @Query private var focusStates: [ActiveFocusState]
    @Query(sort: \AppSettings.createdAt) private var appSettings: [AppSettings]

    @State private var selectedSection: AppSection = .launch
    @State private var selectedTaskID: UUID?
    @State private var showingTaskEditor = false
    @State private var editingTask: LearningTask?
    @State private var didBootstrap = false
    @State private var unlockedAchievementKindRawValues = Set<String>()
    @State private var activeAchievementToast: AchievementRecord?
    @State private var activeFocusTaskID: UUID?
    @State private var activeFocusOriginalStartedAt: Date?
    @State private var activeFocusStartedAt: Date?
    @State private var activeFocusPausedAt: Date?
    @State private var activeFocusAccumulatedSeconds: Double = 0
    @State private var activeFocusNote = ""

    private var settings: AppSettings? {
        appSettings.first
    }

    private var focusState: ActiveFocusState? {
        focusStates.first
    }

    private var appearanceMode: AppAppearanceMode {
        settings?.appearanceMode ?? .system
    }

    private var glassTransparency: Double {
        settings?.resolvedGlassTransparency ?? AppSettings.defaultGlassTransparency
    }

    var body: some View {
        ShellView(
            tasks: tasks,
            sessions: sessions,
            events: events,
            achievements: achievements,
            settings: settings,
            focusState: focusState,
            selectedSection: $selectedSection,
            selectedTaskID: $selectedTaskID,
            activeFocusTaskID: $activeFocusTaskID,
            activeFocusOriginalStartedAt: $activeFocusOriginalStartedAt,
            activeFocusStartedAt: $activeFocusStartedAt,
            activeFocusPausedAt: $activeFocusPausedAt,
            activeFocusAccumulatedSeconds: $activeFocusAccumulatedSeconds,
            activeFocusNote: $activeFocusNote,
            onNewTask: openNewTask,
            onEditTask: openEditor,
            onBeginFocus: beginFocus,
            onPauseFocus: pauseFocus,
            onResumeFocus: resumeFocus,
            onFinishFocus: finishFocus,
            onUpdateProgress: updateProgress,
            onMarkComplete: { markComplete($0) },
            onRecordBlock: recordBlock,
            onRecordRecovery: recordRecovery,
            onSaveReview: saveReview,
            onDeleteTask: deleteTask,
            onAppearanceChanged: appearanceChanged,
            onSettingsChanged: settingsChanged,
            onRequestNotifications: requestNotificationAuthorization,
            onExportBackup: exportBackup,
            onPreviewImport: previewImport,
            onImportBackup: importBackup
        )
        .environment(\.dayGlassTransparency, glassTransparency)
        .preferredColorScheme(appearanceMode.colorScheme)
        .background(ApplicationAppearanceSync(mode: appearanceMode))
        .overlay(alignment: .topTrailing) {
            if let activeAchievementToast,
               selectedSection == .launch || selectedSection == .today {
                AchievementToastView(
                    record: activeAchievementToast,
                    relatedTask: activeAchievementToast.relatedTaskID.flatMap { id in
                        tasks.first(where: { $0.id == id })
                    },
                    onDismiss: { dismissAchievementToast(activeAchievementToast) }
                )
                .padding(24)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .sheet(isPresented: $showingTaskEditor) {
            TaskEditorSheet(task: editingTask) { draft in
                saveTask(draft)
            }
            .frame(width: 580, height: 720)
        }
        .onAppear {
            bootstrap()
            consumePendingWidgetIntent()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            consumePendingWidgetIntent()
        }
        .onChange(of: tasks.map(\.id)) { _, _ in
            ensureTaskSelection()
            writeWidgetSnapshot()
        }
        .onChange(of: achievements.map(\.kindRaw)) { _, values in
            unlockedAchievementKindRawValues = Set(values)
        }
        .onChange(of: activeFocusNote) { _, note in
            focusState?.draftNote = note
            try? modelContext.save()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dayDayUpNewTask)) { _ in
            selectedSection = .tasks
            openNewTask()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dayDayUpStartTask)) { notification in
            guard let taskID = notification.object as? UUID,
                  let task = tasks.first(where: { $0.id == taskID }) else {
                selectedSection = .today
                return
            }
            beginFocus(task)
        }
    }

    private func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true
        selectedSection = .launch
        showingTaskEditor = false
        editingTask = nil
        unlockedAchievementKindRawValues = Set(achievements.map(\.kindRaw))
        let settings = ensureAppSettings()
        let focusState = ensureActiveFocusState()
        normalize(settings)
        try? modelContext.save()
        restoreActiveFocus(from: focusState)
        let selectableTasks = removeLegacyPlaceholderTasksIfPresent()
        ensureDeadlineEvents(for: selectableTasks)
        refreshNotificationStatus(settings)
        if !settings.didRequestNotificationAuthorization {
            requestNotificationAuthorization()
        } else {
            ReminderScheduler.rescheduleAll(tasks: selectableTasks, settings: settings)
        }
        ensureTaskSelection(from: selectableTasks)
        writeWidgetSnapshot()
    }

    @discardableResult
    private func ensureAppSettings() -> AppSettings {
        if let settings {
            return settings
        }
        let settings = AppSettings()
        modelContext.insert(settings)
        try? modelContext.save()
        return settings
    }

    @discardableResult
    private func ensureActiveFocusState() -> ActiveFocusState {
        if let focusState {
            return focusState
        }
        let focusState = ActiveFocusState()
        modelContext.insert(focusState)
        try? modelContext.save()
        return focusState
    }

    private func restoreActiveFocus(from focusState: ActiveFocusState) {
        activeFocusTaskID = focusState.taskID
        activeFocusOriginalStartedAt = focusState.originalStartedAt
        activeFocusStartedAt = focusState.currentStartedAt
        activeFocusPausedAt = focusState.pausedAt
        activeFocusAccumulatedSeconds = focusState.accumulatedSeconds
        activeFocusNote = focusState.draftNote
    }

    private func writeWidgetSnapshot(now: Date = .now) {
        WidgetSnapshotWriter.write(
            tasks: tasks,
            sessions: sessions,
            focusState: focusState,
            glassTransparency: glassTransparency,
            now: now
        )
    }

    private func consumePendingWidgetIntent() {
        guard let intent = DayDayUpWidgetShared.consumePendingIntent() else { return }

        switch intent.kind {
        case .openApp:
            selectedSection = section(for: intent.destination) ?? .launch
        case .startFocus:
            guard let taskID = intent.taskID,
                  let task = tasks.first(where: { $0.id == taskID }) else {
                selectedSection = .today
                return
            }
            beginFocus(task)
        case .openSection:
            selectedSection = section(for: intent.destination) ?? .launch
        }
    }

    private func section(for destination: WidgetPendingIntent.Destination?) -> AppSection? {
        switch destination {
        case .launch: .launch
        case .today: .today
        case .score: .score
        case nil: nil
        }
    }

    private func persistActiveFocusToStore() {
        let focusState = ensureActiveFocusState()
        focusState.taskID = activeFocusTaskID
        focusState.originalStartedAt = activeFocusOriginalStartedAt
        focusState.currentStartedAt = activeFocusStartedAt
        focusState.pausedAt = activeFocusPausedAt
        focusState.accumulatedSeconds = activeFocusAccumulatedSeconds
        focusState.draftNote = activeFocusNote
        try? modelContext.save()
    }

    private func refreshNotificationStatus(_ settings: AppSettings) {
        Task { @MainActor in
            let state = await ReminderScheduler.authorizationState()
            settings.notificationStatus = state
            try? modelContext.save()
        }
    }

    private func requestNotificationAuthorization() {
        let settings = ensureAppSettings()
        Task { @MainActor in
            let state = await ReminderScheduler.requestAuthorization()
            settings.notificationStatus = state
            settings.didRequestNotificationAuthorization = true
            try? modelContext.save()
            ReminderScheduler.rescheduleAll(tasks: tasks, settings: settings)
        }
    }

    private func settingsChanged() {
        let settings = ensureAppSettings()
        normalize(settings)
        try? modelContext.save()
        ReminderScheduler.rescheduleAll(tasks: tasks, settings: settings)
        refreshNotificationStatus(settings)
        writeWidgetSnapshot()
    }

    private func appearanceChanged() {
        let settings = ensureAppSettings()
        normalize(settings)
        try? modelContext.save()
        writeWidgetSnapshot()
    }

    private func normalize(_ settings: AppSettings) {
        settings.reminderLeadMinutes = min(max(settings.reminderLeadMinutes, 1), 1440)
        settings.dailyReminderHour = min(max(settings.dailyReminderHour, 0), 23)
        settings.dailyReminderMinute = min(max(settings.dailyReminderMinute, 0), 59)
        if AppAppearanceMode(rawValue: settings.appearanceModeRaw ?? "") == nil {
            settings.appearanceModeRaw = AppAppearanceMode.system.rawValue
        }
        settings.resolvedGlassTransparency = settings.resolvedGlassTransparency
    }

    private func exportBackup(to url: URL) -> String {
        let settings = ensureAppSettings()
        do {
            try DayDayUpBackupService.exportBackup(
                to: url,
                tasks: tasks,
                sessions: sessions,
                events: events,
                achievements: achievements,
                settings: settings,
                focusState: focusState
            )
            settings.lastBackupURL = url.path
            try? modelContext.save()
            return "已导出备份：\(url.lastPathComponent)"
        } catch {
            return "导出失败：\(error.localizedDescription)"
        }
    }

    private func previewImport(from url: URL) -> String {
        do {
            let summary = try DayDayUpBackupService.previewBackup(at: url)
            return "备份预检通过：\(summary.text)"
        } catch {
            return "备份预检失败：\(error.localizedDescription)"
        }
    }

    private func importBackup(from url: URL) -> String {
        let settings = ensureAppSettings()
        let focusState = ensureActiveFocusState()
        do {
            let summary = try DayDayUpBackupService.importBackup(
                from: url,
                modelContext: modelContext,
                tasks: tasks,
                sessions: sessions,
                events: events,
                achievements: achievements,
                settings: settings,
                focusState: focusState
            )
            try? modelContext.save()
            restoreActiveFocus(from: focusState)
            ReminderScheduler.rescheduleAll(tasks: tasks, settings: settings)
            writeWidgetSnapshot()
            return "已导入备份：\(summary.text)"
        } catch {
            return "导入失败：\(error.localizedDescription)"
        }
    }

    private func ensureTaskSelection(from sourceTasks: [LearningTask]? = nil) {
        let availableTasks = sourceTasks ?? tasks
        if let selectedTaskID, availableTasks.contains(where: { $0.id == selectedTaskID }) {
            return
        }
        selectedTaskID = availableTasks.nearestIncomplete?.id ?? availableTasks.latestCompleted?.id ?? availableTasks.first?.id
    }

    private func removeLegacyPlaceholderTasksIfPresent() -> [LearningTask] {
        let tokens = ["A", "B", "C"]
        let legacyTasks = tasks.filter { task in
            tokens.contains { token in
                task.name == "任务名称 \(token)" && task.direction == "学习方向 \(token)"
            }
        }
        guard !legacyTasks.isEmpty else { return tasks }

        let legacyIDs = Set(legacyTasks.map(\.id))
        sessions.filter { legacyIDs.contains($0.taskID) }.forEach(modelContext.delete)
        events.filter { legacyIDs.contains($0.taskID) }.forEach(modelContext.delete)
        legacyTasks.forEach(modelContext.delete)
        selectedTaskID = nil
        try? modelContext.save()
        return tasks.filter { !legacyIDs.contains($0.id) }
    }

    private func ensureDeadlineEvents(for sourceTasks: [LearningTask]) {
        var didInsert = false
        for task in sourceTasks where !hasDeadlineEvent(for: task) {
            modelContext.insert(deadlineEvent(for: task))
            didInsert = true
        }
        if didInsert {
            try? modelContext.save()
        }
    }

    private func hasDeadlineEvent(for task: LearningTask) -> Bool {
        events.contains { $0.taskID == task.id && $0.type == .deadline }
    }

    private func replaceDeadlineEvent(for task: LearningTask) {
        events
            .filter { $0.taskID == task.id && $0.type == .deadline }
            .forEach(modelContext.delete)
        modelContext.insert(deadlineEvent(for: task))
    }

    private func deadlineEvent(for task: LearningTask) -> TaskEvent {
        TaskEvent(
            taskID: task.id,
            type: .deadline,
            occurredAt: task.deadline,
            note: "截止时间：\(task.deadline.formattedDateTime())"
        )
    }

    private func openNewTask() {
        editingTask = nil
        showingTaskEditor = true
    }

    private func openEditor(_ task: LearningTask) {
        editingTask = task
        selectedTaskID = task.id
        showingTaskEditor = true
    }

    private func saveTask(_ draft: TaskDraft) {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let clampedProgress = min(max(draft.progress, 0), 1)
        let clampedEstimatedMinutes = min(max(draft.estimatedMinutes, 15), 1440)

        if let editingTask {
            editingTask.name = trimmedName
            editingTask.details = draft.details.trimmingCharacters(in: .whitespacesAndNewlines)
            editingTask.direction = draft.direction.trimmingCharacters(in: .whitespacesAndNewlines)
            editingTask.deadline = draft.deadline
            editingTask.estimatedMinutes = clampedEstimatedMinutes
            editingTask.progress = editingTask.completedAt == nil ? clampedProgress : 1
            editingTask.completionCriteria = draft.completionCriteria.trimmingCharacters(in: .whitespacesAndNewlines)
            editingTask.resourceLink = draft.resourceLink.trimmingCharacters(in: .whitespacesAndNewlines)
            editingTask.notes = draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            editingTask.updatedAt = .now
            modelContext.insert(TaskEvent(taskID: editingTask.id, type: .progress, note: "更新任务信息"))
            replaceDeadlineEvent(for: editingTask)
            ReminderScheduler.scheduleTaskReminders(for: editingTask, settings: ensureAppSettings())
        } else {
            let task = LearningTask(
                name: trimmedName,
                details: draft.details.trimmingCharacters(in: .whitespacesAndNewlines),
                direction: draft.direction.trimmingCharacters(in: .whitespacesAndNewlines),
                deadline: draft.deadline,
                estimatedMinutes: clampedEstimatedMinutes,
                progress: clampedProgress,
                completionCriteria: draft.completionCriteria.trimmingCharacters(in: .whitespacesAndNewlines),
                resourceLink: draft.resourceLink.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            modelContext.insert(task)
            modelContext.insert(TaskEvent(taskID: task.id, type: .planned, occurredAt: task.plannedAt, note: "制定计划"))
            modelContext.insert(deadlineEvent(for: task))
            ReminderScheduler.scheduleTaskReminders(for: task, settings: ensureAppSettings())
            selectedTaskID = task.id
        }

        try? modelContext.save()
        writeWidgetSnapshot()
        showingTaskEditor = false
        editingTask = nil
    }

    private func beginFocus(_ task: LearningTask) {
        guard task.completedAt == nil else { return }
        let now = Date.now
        var closedSession: LearningSession?
        if activeFocusTaskID == task.id {
            selectedTaskID = task.id
            selectedSection = .today
            return
        }
        if activeFocusTaskID != nil {
            closedSession = closeActiveFocusSession(note: "切换任务前自动保存专注学习", endedAt: now)
        }
        if task.startedAt == nil {
            task.startedAt = now
            task.updatedAt = now
            modelContext.insert(TaskEvent(taskID: task.id, type: .started, occurredAt: now, note: "开始执行"))
        }
        selectedTaskID = task.id
        selectedSection = .today
        activeFocusTaskID = task.id
        activeFocusOriginalStartedAt = now
        activeFocusStartedAt = now
        activeFocusPausedAt = nil
        activeFocusAccumulatedSeconds = 0
        activeFocusNote = ""
        persistActiveFocusToStore()
        try? modelContext.save()
        writeWidgetSnapshot()
        if let closedSession {
            evaluateAchievements(relatedTask: tasks.first(where: { $0.id == closedSession.taskID }), extraSessions: [closedSession])
        }
    }

    private func pauseFocus() {
        guard activeFocusTaskID != nil,
              activeFocusPausedAt == nil else { return }
        let now = Date.now
        if let activeFocusStartedAt {
            activeFocusAccumulatedSeconds += max(0, now.timeIntervalSince(activeFocusStartedAt))
        }
        activeFocusStartedAt = nil
        activeFocusPausedAt = now
        persistActiveFocusToStore()
        writeWidgetSnapshot()
    }

    private func resumeFocus() {
        guard activeFocusTaskID != nil,
              activeFocusPausedAt != nil else { return }
        activeFocusStartedAt = .now
        activeFocusPausedAt = nil
        persistActiveFocusToStore()
        writeWidgetSnapshot()
    }

    private func finishFocus(_ note: String) {
        if let session = closeActiveFocusSession(note: note, endedAt: .now) {
            try? modelContext.save()
            writeWidgetSnapshot()
            evaluateAchievements(relatedTask: tasks.first(where: { $0.id == session.taskID }), extraSessions: [session])
        }
    }

    @discardableResult
    private func closeActiveFocusSession(note: String, endedAt: Date) -> LearningSession? {
        guard let taskID = activeFocusTaskID,
              let originalStartedAt = activeFocusOriginalStartedAt,
              tasks.contains(where: { $0.id == taskID }) else {
            activeFocusTaskID = nil
            activeFocusOriginalStartedAt = nil
            self.activeFocusStartedAt = nil
            activeFocusPausedAt = nil
            activeFocusAccumulatedSeconds = 0
            activeFocusNote = ""
            persistActiveFocusToStore()
            return nil
        }

        let finalEndedAt = max(endedAt, originalStartedAt)
        let totalActiveSeconds = activeFocusAccumulatedSeconds + (activeFocusStartedAt.map { max(0, finalEndedAt.timeIntervalSince($0)) } ?? 0)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalNote = trimmedNote.isEmpty ? "完成一次专注学习" : trimmedNote
        let session = LearningSession(
            taskID: taskID,
            startedAt: originalStartedAt,
            endedAt: finalEndedAt,
            note: finalNote,
            activeSeconds: totalActiveSeconds
        )
        modelContext.insert(session)
        modelContext.insert(TaskEvent(taskID: taskID, type: .progress, occurredAt: finalEndedAt, note: finalNote))
        activeFocusTaskID = nil
        activeFocusOriginalStartedAt = nil
        self.activeFocusStartedAt = nil
        activeFocusPausedAt = nil
        activeFocusAccumulatedSeconds = 0
        activeFocusNote = ""
        persistActiveFocusToStore()
        return session
    }

    private func updateProgress(_ task: LearningTask, _ progress: Double, _ note: String) {
        guard task.completedAt == nil else { return }
        let clamped = min(max(progress, 0), 1)
        task.progress = clamped
        task.updatedAt = .now
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalNote = trimmedNote.isEmpty ? "完成度更新为 \(clamped.percentText)" : trimmedNote
        modelContext.insert(TaskEvent(taskID: task.id, type: .progress, note: finalNote))
        if clamped >= 1 {
            markComplete(task, note: trimmedNote)
            return
        }
        try? modelContext.save()
        writeWidgetSnapshot()
        evaluateAchievements(relatedTask: task)
    }

    private func markComplete(_ task: LearningTask, note: String? = nil) {
        guard task.completedAt == nil else { return }
        let now = Date.now
        var closedSession: LearningSession?
        if activeFocusTaskID == task.id {
            closedSession = closeActiveFocusSession(note: "完成任务前自动保存专注学习", endedAt: now)
        }
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        task.progress = 1
        task.completedAt = now
        task.updatedAt = now
        let recovered = now > task.deadline
        if recovered && !trimmedNote.isEmpty {
            task.recoveryNote = trimmedNote
        }
        if recovered && task.recoveryNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            task.recoveryNote = "逾期后补完成。"
        }
        modelContext.insert(
            TaskEvent(
                taskID: task.id,
                type: recovered ? .recovered : .completed,
                occurredAt: now,
                note: completionNote(recovered: recovered, note: trimmedNote)
            )
        )
        ReminderScheduler.cancelTaskReminders(for: task)
        try? modelContext.save()
        writeWidgetSnapshot()
        evaluateAchievements(relatedTask: task, extraSessions: closedSession.map { [$0] } ?? [])
    }

    private func completionNote(recovered: Bool, note: String) -> String {
        if !note.isEmpty {
            return recovered ? "逾期后补完成：\(note)" : "任务完成啦，开始干饭！备注：\(note)"
        }
        return recovered ? "逾期后补完成：任务完成啦，开始干饭！" : "任务完成啦，开始干饭！"
    }

    private func recordBlock(_ task: LearningTask, _ note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        task.blockReason = trimmed
        task.updatedAt = .now
        modelContext.insert(TaskEvent(taskID: task.id, type: .blocked, note: trimmed))
        try? modelContext.save()
        writeWidgetSnapshot()
    }

    private func recordRecovery(_ task: LearningTask, _ note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let shouldCompleteAsRecovery = task.completedAt == nil && task.status() == .overdue

        if shouldCompleteAsRecovery {
            markComplete(task, note: trimmed)
            return
        }

        guard !trimmed.isEmpty else { return }
        task.recoveryNote = trimmed
        task.updatedAt = .now
        let eventType: TaskEventType = task.status() == .recovered ? .recovered : .progress
        modelContext.insert(TaskEvent(taskID: task.id, type: eventType, note: "补救记录：\(trimmed)"))
        try? modelContext.save()
        writeWidgetSnapshot()
        evaluateAchievements(relatedTask: task)
    }

    private func saveReview(_ task: LearningTask, _ note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        task.reviewNote = trimmed
        task.updatedAt = .now
        let event = TaskEvent(taskID: task.id, type: .reviewed, note: trimmed)
        modelContext.insert(event)
        try? modelContext.save()
        writeWidgetSnapshot()
        evaluateAchievements(relatedTask: task, extraEvents: [event])
    }

    private func evaluateAchievements(
        relatedTask: LearningTask? = nil,
        extraSessions: [LearningSession] = [],
        extraEvents: [TaskEvent] = []
    ) {
        let existing = Set(achievements.map(\.kindRaw)).union(unlockedAchievementKindRawValues)
        let allSessions = sessions.merging(extraSessions)
        let allEvents = events.merging(extraEvents)
        let unlockedKinds = AchievementRuleEngine.newlyUnlockedKinds(
            tasks: tasks,
            sessions: allSessions,
            events: allEvents,
            existingKindRawValues: existing
        )
        guard !unlockedKinds.isEmpty else { return }

        var newRecords: [AchievementRecord] = []
        for kind in unlockedKinds {
            let record = AchievementRecord(
                kind: kind,
                relatedTaskID: AchievementRuleEngine.relatedTaskID(for: kind, preferredTask: relatedTask, tasks: tasks)
            )
            modelContext.insert(record)
            unlockedAchievementKindRawValues.insert(kind.rawValue)
            newRecords.append(record)
        }
        try? modelContext.save()
        activeAchievementToast = newRecords.first
    }

    private func dismissAchievementToast(_ record: AchievementRecord) {
        record.isSeen = true
        if activeAchievementToast?.id == record.id {
            activeAchievementToast = nil
        }
        try? modelContext.save()
    }

    private func deleteTask(_ task: LearningTask) {
        ReminderScheduler.cancelTaskReminders(for: task)
        if activeFocusTaskID == task.id {
            activeFocusTaskID = nil
            activeFocusOriginalStartedAt = nil
            activeFocusStartedAt = nil
            activeFocusPausedAt = nil
            activeFocusAccumulatedSeconds = 0
            activeFocusNote = ""
            persistActiveFocusToStore()
        }
        sessions.filter { $0.taskID == task.id }.forEach(modelContext.delete)
        events.filter { $0.taskID == task.id }.forEach(modelContext.delete)
        modelContext.delete(task)
        if selectedTaskID == task.id {
            selectedTaskID = nil
        }
        try? modelContext.save()
        ensureTaskSelection()
        writeWidgetSnapshot()
    }
}

struct ShellView: View {
    let tasks: [LearningTask]
    let sessions: [LearningSession]
    let events: [TaskEvent]
    let achievements: [AchievementRecord]
    let settings: AppSettings?
    let focusState: ActiveFocusState?
    @Binding var selectedSection: AppSection
    @Binding var selectedTaskID: UUID?
    @Binding var activeFocusTaskID: UUID?
    @Binding var activeFocusOriginalStartedAt: Date?
    @Binding var activeFocusStartedAt: Date?
    @Binding var activeFocusPausedAt: Date?
    @Binding var activeFocusAccumulatedSeconds: Double
    @Binding var activeFocusNote: String
    let onNewTask: () -> Void
    let onEditTask: (LearningTask) -> Void
    let onBeginFocus: (LearningTask) -> Void
    let onPauseFocus: () -> Void
    let onResumeFocus: () -> Void
    let onFinishFocus: (String) -> Void
    let onUpdateProgress: (LearningTask, Double, String) -> Void
    let onMarkComplete: (LearningTask) -> Void
    let onRecordBlock: (LearningTask, String) -> Void
    let onRecordRecovery: (LearningTask, String) -> Void
    let onSaveReview: (LearningTask, String) -> Void
    let onDeleteTask: (LearningTask) -> Void
    let onAppearanceChanged: () -> Void
    let onSettingsChanged: () -> Void
    let onRequestNotifications: () -> Void
    let onExportBackup: (URL) -> String
    let onPreviewImport: (URL) -> String
    let onImportBackup: (URL) -> String

    private var selectedTask: LearningTask? {
        selectedTaskID.flatMap { id in tasks.first(where: { $0.id == id }) }
            ?? tasks.nearestIncomplete
            ?? tasks.latestCompleted
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarNavigation(
                settings: settings,
                selectedSection: $selectedSection,
                onAppearanceChanged: onAppearanceChanged,
                onNewTask: onNewTask
            )
            .frame(width: 300)
            .layoutPriority(2)
            .clipped()

            Divider()

            VStack(spacing: 0) {
                Group {
                    switch selectedSection {
                    case .launch:
                        LaunchCountdownView(
                            task: tasks.nearestIncomplete ?? tasks.latestCompleted,
                            metrics: MetricCalculator.calculate(tasks: tasks, sessions: sessions),
                            onStartToday: { selectedSection = .today },
                            onTaskDetail: {
                                selectedTaskID = (tasks.nearestIncomplete ?? tasks.latestCompleted)?.id
                                selectedSection = .tasks
                            },
                            onNewTask: onNewTask,
                            onBeginFocus: onBeginFocus
                        )
                    case .today:
                        TodayExecutionView(
                            tasks: tasks.sortedForExecution(),
                            sessions: sessions,
                            activeFocusTaskID: $activeFocusTaskID,
                            activeFocusOriginalStartedAt: $activeFocusOriginalStartedAt,
                            activeFocusStartedAt: $activeFocusStartedAt,
                            activeFocusPausedAt: $activeFocusPausedAt,
                            activeFocusAccumulatedSeconds: $activeFocusAccumulatedSeconds,
                            activeFocusNote: $activeFocusNote,
                            selectedTaskID: $selectedTaskID,
                            onBeginFocus: onBeginFocus,
                            onPauseFocus: onPauseFocus,
                            onResumeFocus: onResumeFocus,
                            onFinishFocus: onFinishFocus,
                            onUpdateProgress: onUpdateProgress,
                            onMarkComplete: onMarkComplete
                        )
                    case .tasks:
                        TaskManagementView(
                            tasks: tasks,
                            selectedTaskID: $selectedTaskID,
                            onNewTask: onNewTask,
                            onEditTask: onEditTask,
                            onBeginFocus: onBeginFocus,
                            onMarkComplete: onMarkComplete
                        )
                    case .score:
                        ScoreDashboardView(tasks: tasks, sessions: sessions, achievements: achievements, selectedTaskID: $selectedTaskID)
                    case .journey:
                        LearningJourneyView(
                            tasks: tasks,
                            sessions: sessions,
                            events: events,
                            achievements: achievements,
                            selectedTaskID: $selectedTaskID
                        )
                    case .settings:
                        SettingsBackupView(
                            settings: settings,
                            tasks: tasks,
                            sessions: sessions,
                            events: events,
                            achievements: achievements,
                            focusState: focusState,
                            onAppearanceChanged: onAppearanceChanged,
                            onSettingsChanged: onSettingsChanged,
                            onRequestNotifications: onRequestNotifications,
                            onExportBackup: onExportBackup,
                            onPreviewImport: onPreviewImport,
                            onImportBackup: onImportBackup
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .dayGlassMotionEnabled(selectedSection != .score)
            .dayPageBackground()
            .frame(minWidth: 780, maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
            .clipped()

            Divider()

            Group {
                if let selectedTask {
                    TaskDetailInspector(
                        task: selectedTask,
                        events: events.filter { $0.taskID == selectedTask.id },
                        sessions: sessions.filter { $0.taskID == selectedTask.id },
                        achievements: achievements.filter { $0.relatedTaskID == selectedTask.id },
                        onEditTask: onEditTask,
                        onBeginFocus: onBeginFocus,
                        onMarkComplete: onMarkComplete,
                        onRecordBlock: onRecordBlock,
                        onRecordRecovery: onRecordRecovery,
                        onSaveReview: onSaveReview,
                        onDeleteTask: onDeleteTask
                    )
                } else {
                    EmptyInspectorView(onNewTask: onNewTask)
                }
            }
            .frame(width: 360)
            .frame(maxHeight: .infinity)
            .layoutPriority(2)
            .clipped()
        }
    }
}

struct SidebarNavigation: View {
    let settings: AppSettings?
    @Binding var selectedSection: AppSection
    let onAppearanceChanged: () -> Void
    let onNewTask: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                SquirrelImage(mood: .active, size: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("DayDayUp")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DayColor.primaryDeep)
                        .lineLimit(1)
                    Text("学习执行监督台")
                        .font(.caption)
                        .foregroundStyle(DayColor.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            VStack(spacing: 4) {
                ForEach(AppSection.allCases) { section in
                    SidebarNavigationRow(
                        section: section,
                        isSelected: selectedSection == section
                    ) {
                        selectedSection = section
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 0)

            if let settings {
                SidebarAppearanceControls(settings: settings, onAppearanceChanged: onAppearanceChanged)
                    .padding(.horizontal, 14)
            }

            Button {
                onNewTask()
            } label: {
                Label("新建任务", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("n", modifiers: [.command])
            .accessibilityHint("打开任务录入表单")
            .padding([.horizontal, .bottom], 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dayGlassMotionEnabled(false)
        .dayGlass(cornerRadius: 18, interactive: false)
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .dayPageBackground()
    }
}

private struct SidebarNavigationRow: View {
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(section.title)
                    .font(.callout.weight(isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            } icon: {
                Image(systemName: section.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 20, alignment: .center)
            }
            .foregroundStyle(isSelected ? Color.white : DayColor.text)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .padding(.horizontal, 12)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? DayColor.primary : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct SidebarAppearanceControls: View {
    @Bindable var settings: AppSettings
    let onAppearanceChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("外观", systemImage: "circle.lefthalf.filled")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DayColor.muted)

            Picker("外观模式", selection: appearanceModeBinding) {
                Text("系统").tag(AppAppearanceMode.system)
                Text("浅色").tag(AppAppearanceMode.light)
                Text("深色").tag(AppAppearanceMode.dark)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 5) {
                Text("\(Int(settings.resolvedGlassTransparency * 100))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(DayColor.muted)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                HStack(spacing: 8) {
                    Text("实体")

                    Slider(
                        value: glassTransparencyBinding,
                        in: 0...1,
                        step: 0.01,
                        onEditingChanged: { editing in
                            if !editing {
                                onAppearanceChanged()
                            }
                        }
                    )
                    .accessibilityLabel("界面透明度")

                    Text("通透")
                }
                .font(.caption)
                .foregroundStyle(DayColor.muted)
            }
        }
        .padding(12)
        .dayPanel(cornerRadius: 12)
    }

    private var appearanceModeBinding: Binding<AppAppearanceMode> {
        Binding(
            get: { settings.appearanceMode },
            set: { mode in
                settings.appearanceMode = mode
                onAppearanceChanged()
            }
        )
    }

    private var glassTransparencyBinding: Binding<Double> {
        Binding(
            get: { settings.resolvedGlassTransparency },
            set: { settings.resolvedGlassTransparency = $0 }
        )
    }
}
