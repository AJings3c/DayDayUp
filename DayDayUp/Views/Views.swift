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

struct AppBootstrapView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \LearningTask.deadline) private var tasks: [LearningTask]
    @Query private var focusStates: [ActiveFocusState]
    @Query(sort: \AppSettings.createdAt) private var appSettings: [AppSettings]

    @State private var router = AppRouter()
    @State private var focusController = FocusSessionController()
    @State private var didBootstrap = false
    @State private var activeAchievementToast: AchievementRecord?
    @State private var currentNow = Date.now
    @State private var cachedMetrics = AppMetrics.empty
    @State private var metricsCalculatedDay = Date.distantPast
    @State private var lastReminderScanAt: Date?
    @State private var activeReminderToast: TaskEvent?

    private var settings: AppSettings? {
        appSettings.first
    }

    private var focusState: ActiveFocusState? {
        focusStates.first
    }

    private var appearanceMode: AppAppearanceMode {
        settings?.appearanceMode ?? .light
    }

    private var glassTransparency: Double {
        settings?.resolvedGlassTransparency ?? AppSettings.defaultGlassTransparency
    }

    private var reminderScheduleID: String {
        let taskPart = tasks.map {
            "\($0.id.uuidString):\($0.deadline.timeIntervalSinceReferenceDate):\($0.completedAt?.timeIntervalSinceReferenceDate ?? -1)"
        }.joined(separator: "|")
        return "\(didBootstrap)#\(taskPart)#\(settings?.reminderLeadMinutes ?? 30)#\(settings?.overdueReminderEnabled ?? true)"
    }

    var body: some View {
        @Bindable var router = router
        ShellView(
            tasks: tasks,
            settings: settings,
            focusState: focusState,
            router: router,
            focusController: focusController,
            metrics: cachedMetrics,
            currentNow: currentNow,
            lastReminderScanAt: lastReminderScanAt,
            taskActions: TaskActionSet(
                newTask: openNewTask,
                edit: openEditor,
                beginFocus: beginFocus,
                updateProgress: updateProgress,
                complete: { markComplete($0) },
                recordBlock: recordBlock,
                recordRecovery: recordRecovery,
                saveReview: saveReview,
                delete: deleteTask,
                createSample: createSampleTask
            ),
            focusActions: FocusActionSet(
                pause: pauseFocus,
                resume: resumeFocus,
                finish: finishFocus,
                updateNote: updateFocusNote
            ),
            settingsActions: SettingsActionSet(
                appearanceChanged: appearanceChanged,
                settingsChanged: settingsChanged,
                requestNotifications: requestNotificationAuthorization,
                exportBackup: exportBackup,
                previewImport: previewImport,
                importBackup: importBackup
            )
        )
        .environment(\.dayGlassTransparency, glassTransparency)
        .preferredColorScheme(appearanceMode.colorScheme)
        .background(ApplicationAppearanceSync(mode: appearanceMode))
        .overlay(alignment: .topTrailing) {
            if activeReminderToast != nil || (activeAchievementToast != nil && (router.selectedSection == .launch || router.selectedSection == .today)) {
                VStack(alignment: .trailing, spacing: 12) {
                    if let activeReminderToast {
                        ReminderToastView(
                            event: activeReminderToast,
                            relatedTask: tasks.first(where: { $0.id == activeReminderToast.taskID }),
                            onDismiss: { dismissReminderToast(activeReminderToast) }
                        )
                    }

                    if let activeAchievementToast,
                       router.selectedSection == .launch || router.selectedSection == .today {
                        AchievementToastView(
                            record: activeAchievementToast,
                            relatedTask: activeAchievementToast.relatedTaskID.flatMap { id in
                                tasks.first(where: { $0.id == id })
                            },
                            onDismiss: { dismissAchievementToast(activeAchievementToast) }
                        )
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $router.showingTaskEditor) {
            TaskEditorSheet(task: router.editingTask) { draft in
                saveTask(draft)
            }
            .frame(width: 760, height: 760)
        }
        .onAppear {
            bootstrap()
            consumePendingWidgetIntent()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            performReminderScan()
            performRescheduleAll()
            consumePendingWidgetIntent()
        }
        .onChange(of: tasks.map(\.id)) { _, _ in
            ensureTaskSelection()
            writeWidgetSnapshot()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now in
            currentNow = now
            refreshMetrics(now: now)
        }
        .task(id: reminderScheduleID) {
            await runReminderScheduleLoop()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dayDayUpNewTask)) { _ in
            openNewTask()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dayDayUpStartTask)) { notification in
            guard let taskID = notification.object as? UUID,
                  let task = tasks.first(where: { $0.id == taskID }) else {
                router.selectedSection = .today
                return
            }
            beginFocus(task)
        }
        .onReceive(NotificationCenter.default.publisher(for: .dayDayUpOpenTaskFromNotification)) { notification in
            guard let route = notification.object as? ReminderNotificationRoute else {
                router.selectedSection = .today
                return
            }
            openNotificationRoute(route)
        }
        .alert(
            "操作未完成",
            isPresented: Binding(
                get: { router.errorMessage != nil },
                set: { if !$0 { router.dismissError() } }
            )
        ) {
            Button("知道了") { router.dismissError() }
        } message: {
            Text(router.errorMessage ?? "发生未知错误。")
        }
    }

    private func bootstrap() {
        guard !didBootstrap else { return }
        router.selectedSection = .launch
        router.showingTaskEditor = false
        router.editingTask = nil
        do {
            let integrity = try ModelIntegrityCoordinator.repair(modelContext: modelContext)
            let settings = integrity.settings
            let focusState = integrity.focusState
            normalize(settings)
            try repairImpossibleTaskTimelines()
            try modelContext.commitOrRollback()
            focusController.configure(modelContext: modelContext, state: focusState)
            let selectableTasks = try removeLegacyPlaceholderTasksIfPresent()
            try ensureDeadlineEvents(for: selectableTasks)
            performReminderScan()
            refreshNotificationStatus(settings)
            if !settings.didRequestNotificationAuthorization {
                requestNotificationAuthorization()
            } else {
                ReminderScheduler.rescheduleAll(tasks: selectableTasks, settings: settings)
            }
            ensureTaskSelection(from: selectableTasks)
            refreshMetrics(force: true)
            didBootstrap = true
            writeWidgetSnapshot()
        } catch {
            router.present(error: error)
        }
    }

    @discardableResult
    private func ensureAppSettings() throws -> AppSettings {
        if let settings {
            return settings
        }
        if let persisted = try modelContext.fetch(FetchDescriptor<AppSettings>()).first {
            return persisted
        }
        let settings = AppSettings()
        modelContext.insert(settings)
        try modelContext.commitOrRollback()
        return settings
    }

    @discardableResult
    private func ensureActiveFocusState() throws -> ActiveFocusState {
        if let focusState {
            return focusState
        }
        if let persisted = try modelContext.fetch(FetchDescriptor<ActiveFocusState>()).first {
            return persisted
        }
        let focusState = ActiveFocusState()
        modelContext.insert(focusState)
        try modelContext.commitOrRollback()
        return focusState
    }

    private func writeWidgetSnapshot(now: Date = .now) {
        refreshMetrics(now: now, force: true)
        do {
            try WidgetSyncCoordinator(modelContext: modelContext).synchronize(now: now)
        } catch {
            router.present(error: error)
        }
    }

    private func refreshMetrics(now: Date = .now, force: Bool = false) {
        let day = now.dayKey()
        guard force || day != metricsCalculatedDay else { return }
        do {
            let sessions = try modelContext.fetch(FetchDescriptor<LearningSession>())
            cachedMetrics = MetricCalculator.calculate(tasks: tasks, sessions: sessions, now: now)
            metricsCalculatedDay = day
        } catch {
            router.present(error: error)
        }
    }

    private func consumePendingWidgetIntent() {
        guard let intent = DayDayUpWidgetShared.consumePendingIntent() else { return }

        router.route(intent)
        if intent.kind == .startFocus {
            guard let taskID = intent.taskID,
                  let task = tasks.first(where: { $0.id == taskID }) else {
                return
            }
            beginFocus(task)
        }
    }

    private func refreshNotificationStatus(_ settings: AppSettings) {
        Task { @MainActor in
            let state = await ReminderScheduler.authorizationState()
            settings.notificationStatus = state
            do {
                try modelContext.commitOrRollback()
            } catch {
                router.present(error: error)
            }
        }
    }

    private func requestNotificationAuthorization() {
        do {
            let settings = try ensureAppSettings()
            Task { @MainActor in
                let state = await ReminderScheduler.requestAuthorization()
                settings.notificationStatus = state
                settings.didRequestNotificationAuthorization = ReminderAuthorizationPolicy.didCompleteAuthorizationRequest(state: state)
                do {
                    try modelContext.commitOrRollback()
                    try ReminderCoordinator(modelContext: modelContext).rescheduleAll()
                } catch {
                    router.present(error: error)
                }
            }
        } catch {
            router.present(error: error)
        }
    }

    private func settingsChanged() {
        do {
            let settings = try ensureAppSettings()
            normalize(settings)
            try modelContext.commitOrRollback()
            try ReminderCoordinator(modelContext: modelContext).rescheduleAll()
            performReminderScan()
            refreshNotificationStatus(settings)
            writeWidgetSnapshot()
        } catch {
            router.present(error: error)
        }
    }

    private func appearanceChanged() {
        do {
            let settings = try ensureAppSettings()
            normalize(settings)
            try modelContext.commitOrRollback()
            writeWidgetSnapshot()
        } catch {
            router.present(error: error)
        }
    }

    private func normalize(_ settings: AppSettings) {
        settings.reminderLeadMinutes = min(max(settings.reminderLeadMinutes, 1), 1440)
        settings.dailyReminderHour = min(max(settings.dailyReminderHour, 0), 23)
        settings.dailyReminderMinute = min(max(settings.dailyReminderMinute, 0), 59)
        if AppAppearanceMode(rawValue: settings.appearanceModeRaw ?? "") == nil {
            settings.appearanceModeRaw = AppAppearanceMode.light.rawValue
        }
        settings.resolvedGlassTransparency = settings.resolvedGlassTransparency
    }

    private func repairImpossibleTaskTimelines(now: Date = .now) throws {
        let persistedEvents = try modelContext.fetch(FetchDescriptor<TaskEvent>())
        var didRepair = false
        for task in tasks where task.repairImpossibleTimeline(now: now) {
            if !persistedEvents.contains(where: {
                $0.taskID == task.id && $0.type == .deadline && $0.occurredAt == task.deadline
            }) {
                modelContext.insert(TaskEventFactory.deadline(for: task))
            }
            didRepair = true
        }
        if didRepair {
            try modelContext.commitOrRollback()
        }
    }

    private func exportBackup(to url: URL) -> String {
        do {
            let settings = try ensureAppSettings()
            let sessions = try modelContext.fetch(FetchDescriptor<LearningSession>())
            let events = try modelContext.fetch(FetchDescriptor<TaskEvent>())
            let achievements = try modelContext.fetch(FetchDescriptor<AchievementRecord>())
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
            try modelContext.commitOrRollback()
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
        do {
            let settings = try ensureAppSettings()
            let focusState = try ensureActiveFocusState()
            let summary = try DayDayUpBackupService.importBackup(
                from: url,
                modelContext: modelContext,
                settings: settings,
                focusState: focusState
            )
            try repairImpossibleTaskTimelines()
            try modelContext.commitOrRollback()
            focusController.configure(modelContext: modelContext, state: focusState)
            try ReminderCoordinator(modelContext: modelContext).rescheduleAll()
            writeWidgetSnapshot()
            return "已导入备份：\(summary.text)"
        } catch {
            return "导入失败：\(error.localizedDescription)"
        }
    }

    private func ensureTaskSelection(from sourceTasks: [LearningTask]? = nil) {
        let availableTasks = sourceTasks ?? tasks
        if let selectedTaskID = router.selectedTaskID,
           availableTasks.contains(where: { $0.id == selectedTaskID }) {
            return
        }
        router.selectedTaskID = availableTasks.nearestIncomplete(now: currentNow)?.id
            ?? availableTasks.latestCompleted?.id
            ?? availableTasks.first?.id
    }

    private func removeLegacyPlaceholderTasksIfPresent() throws -> [LearningTask] {
        let tokens = ["A", "B", "C"]
        let legacyTasks = tasks.filter { task in
            tokens.contains { token in
                task.name == "任务名称 \(token)" && task.direction == "学习方向 \(token)"
            }
        }
        guard !legacyTasks.isEmpty else { return tasks }

        let legacyIDs = Set(legacyTasks.map(\.id))
        let sessions = try modelContext.fetch(FetchDescriptor<LearningSession>())
        let events = try modelContext.fetch(FetchDescriptor<TaskEvent>())
        sessions.filter { legacyIDs.contains($0.taskID) }.forEach(modelContext.delete)
        events.filter { legacyIDs.contains($0.taskID) }.forEach(modelContext.delete)
        legacyTasks.forEach(modelContext.delete)
        router.selectedTaskID = nil
        try modelContext.commitOrRollback()
        return tasks.filter { !legacyIDs.contains($0.id) }
    }

    private func ensureDeadlineEvents(for sourceTasks: [LearningTask]) throws {
        let persistedEvents = try modelContext.fetch(FetchDescriptor<TaskEvent>())
        var didInsert = false
        for task in sourceTasks where !persistedEvents.contains(where: {
            $0.taskID == task.id && $0.type == .deadline && $0.occurredAt == task.deadline
        }) {
            modelContext.insert(TaskEventFactory.deadline(for: task))
            didInsert = true
        }
        if didInsert {
            try modelContext.commitOrRollback()
        }
    }

    private func performReminderScan(now: Date = .now) {
        lastReminderScanAt = now
        do {
            let inserted = try ReminderCoordinator(modelContext: modelContext).scan(now: now)
            if let reminder = inserted.first(where: { $0.type == .leadReminder || $0.type == .overdueReminder }) {
                activeReminderToast = reminder
            }
            if !inserted.isEmpty {
                writeWidgetSnapshot(now: now)
            }
        } catch {
            router.present(error: error)
        }
    }

    private func performRescheduleAll() {
        do {
            try ReminderCoordinator(modelContext: modelContext).rescheduleAll()
        } catch {
            router.present(error: error)
        }
    }

    @MainActor
    private func runReminderScheduleLoop() async {
        guard didBootstrap else { return }
        while !Task.isCancelled {
            do {
                let now = Date.now
                let nextDate = try ReminderCoordinator(modelContext: modelContext).nextScanDate(now: now)
                let delay = max(1, nextDate.timeIntervalSince(now))
                try await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                currentNow = .now
                performReminderScan(now: currentNow)
            } catch is CancellationError {
                return
            } catch {
                router.present(error: error)
                return
            }
        }
    }

    private func openNewTask() {
        router.openNewTask()
    }

    private func createSampleTask() {
        guard tasks.isEmpty else {
            router.selectedSection = .tasks
            return
        }

        let now = Date.now
        var draft = TaskDraft(now: now)
        draft.name = "阅读 RAG 入门资料并整理 3 条笔记"
        draft.details = "阅读一篇 RAG 入门资料，理解检索增强生成的基本流程，并记录 3 条可复用的学习笔记。"
        draft.direction = "RAG / 大模型应用开发"
        draft.deadline = DeadlineShortcutPolicy.evening(daysFromToday: 1, now: now)
        draft.estimatedMinutes = 90
        draft.completionCriteria = "写下 3 条笔记，并能用自己的话说明检索、重排和生成三个环节。"
        draft.resourceLink = "https://github.com/langchain-ai/langchain"
        draft.notes = "示例任务，可随时编辑或删除。"
        do {
            let result = try TaskCommandService(modelContext: modelContext).create(
                from: draft,
                plannedNote: "制定示例学习计划",
                now: now
            )
            let settings = try ensureAppSettings()
            ReminderScheduler.scheduleTaskReminders(for: result.task, settings: settings)
            router.openTask(result.task.id)
            writeWidgetSnapshot()
        } catch {
            router.present(error: error)
        }
    }

    private func openNotificationRoute(_ route: ReminderNotificationRoute) {
        guard let taskID = route.taskID,
              tasks.contains(where: { $0.id == taskID }) else {
            router.selectedSection = .today
            return
        }
        router.openTask(taskID)
    }

    private func openEditor(_ task: LearningTask) {
        router.openEditor(task)
    }

    private func saveTask(_ draft: TaskDraft) {
        let now = Date.now
        do {
            let commands = TaskCommandService(modelContext: modelContext)
            let result: TaskMutationResult
            if let editingTask = router.editingTask {
                result = try commands.update(editingTask, from: draft, now: now)
            } else {
                result = try commands.create(from: draft, now: now)
            }
            let settings = try ensureAppSettings()
            ReminderScheduler.scheduleTaskReminders(for: result.task, settings: settings)
            router.selectedTaskID = result.task.id
            router.showingTaskEditor = false
            router.editingTask = nil
            performReminderScan(now: now)
            writeWidgetSnapshot(now: now)
        } catch {
            router.present(error: error)
        }
    }

    private func beginFocus(_ task: LearningTask) {
        do {
            let closedSession = try focusController.start(task: task)
            router.openTask(task.id, section: .today)
            writeWidgetSnapshot()
            if let closedSession {
                evaluateAchievements(relatedTask: tasks.first(where: { $0.id == closedSession.taskID }))
            }
        } catch {
            router.present(error: error)
        }
    }

    private func pauseFocus() {
        do {
            try focusController.pause()
            writeWidgetSnapshot()
        } catch {
            router.present(error: error)
        }
    }

    private func resumeFocus() {
        do {
            try focusController.resume()
            writeWidgetSnapshot()
        } catch {
            router.present(error: error)
        }
    }

    private func finishFocus(_ note: String) {
        do {
            if let session = try focusController.finish(note: note) {
                writeWidgetSnapshot()
                evaluateAchievements(relatedTask: tasks.first(where: { $0.id == session.taskID }))
            }
        } catch {
            router.present(error: error)
        }
    }

    private func updateFocusNote(_ note: String) {
        do {
            try focusController.updateDraftNote(note)
            writeWidgetSnapshot()
        } catch {
            router.present(error: error)
        }
    }

    private func updateProgress(_ task: LearningTask, _ progress: Double, _ note: String) {
        let now = Date.now
        do {
            if progress >= 1, focusController.taskID == task.id {
                _ = try focusController.finish(note: "完成任务前自动保存专注学习", at: now, save: false)
            }
            let result = try TaskCommandService(modelContext: modelContext).updateProgress(
                task,
                progress: progress,
                note: note,
                now: now
            )
            finishPostMutation(result, now: now)
        } catch {
            router.present(error: error)
        }
    }

    private func markComplete(_ task: LearningTask, note: String? = nil) {
        let now = Date.now
        do {
            if focusController.taskID == task.id {
                _ = try focusController.finish(note: "完成任务前自动保存专注学习", at: now, save: false)
            }
            let result = try TaskCommandService(modelContext: modelContext).complete(task, note: note, now: now)
            finishPostMutation(result, now: now)
        } catch {
            router.present(error: error)
        }
    }

    private func recordBlock(_ task: LearningTask, _ note: String) {
        do {
            _ = try TaskCommandService(modelContext: modelContext).recordBlock(task, note: note)
            writeWidgetSnapshot()
        } catch {
            router.present(error: error)
        }
    }

    private func recordRecovery(_ task: LearningTask, _ note: String) {
        do {
            let result = try TaskCommandService(modelContext: modelContext).recordRecovery(
                task,
                note: note,
                now: currentNow
            )
            finishPostMutation(result, now: currentNow)
        } catch {
            router.present(error: error)
        }
    }

    private func saveReview(_ task: LearningTask, _ note: String) {
        do {
            let result = try TaskCommandService(modelContext: modelContext).saveReview(task, note: note)
            writeWidgetSnapshot()
            evaluateAchievements(relatedTask: result.task)
        } catch {
            router.present(error: error)
        }
    }

    private func finishPostMutation(_ result: TaskMutationResult, now: Date) {
        if result.completionStatus != nil {
            ReminderScheduler.cancelTaskReminders(for: result.task)
        }
        performReminderScan(now: now)
        writeWidgetSnapshot(now: now)
        evaluateAchievements(relatedTask: result.task)
        if result.completionStatus != nil,
           result.task.reviewNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            router.openTask(result.task.id)
        }
    }

    private func evaluateAchievements(relatedTask: LearningTask? = nil) {
        do {
            let records = try AchievementCoordinator(modelContext: modelContext).evaluate(relatedTask: relatedTask)
            activeAchievementToast = records.first
        } catch {
            router.present(error: error)
        }
    }

    private func dismissAchievementToast(_ record: AchievementRecord) {
        record.isSeen = true
        if activeAchievementToast?.id == record.id {
            activeAchievementToast = nil
        }
        do {
            try modelContext.commitOrRollback()
        } catch {
            router.present(error: error)
        }
    }

    private func dismissReminderToast(_ event: TaskEvent) {
        if activeReminderToast?.id == event.id {
            activeReminderToast = nil
        }
    }

    private func deleteTask(_ task: LearningTask) {
        do {
            try focusController.clearIfNeeded(taskID: task.id, save: false)
            try TaskCommandService(modelContext: modelContext).delete(task)
            ReminderScheduler.cancelTaskReminders(for: task)
            if router.selectedTaskID == task.id {
                router.selectedTaskID = nil
            }
            ensureTaskSelection()
            writeWidgetSnapshot()
        } catch {
            router.present(error: error)
        }
    }
}
