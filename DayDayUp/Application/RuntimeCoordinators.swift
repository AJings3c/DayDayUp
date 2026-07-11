import Foundation
import Observation
import OSLog
import SwiftData

@MainActor
@Observable
final class FocusSessionController {
    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private var state: ActiveFocusState?
    private(set) var revision = 0

    var taskID: UUID? { observed(state?.taskID) }
    var originalStartedAt: Date? { observed(state?.originalStartedAt) }
    var currentStartedAt: Date? { observed(state?.currentStartedAt) }
    var pausedAt: Date? { observed(state?.pausedAt) }
    var accumulatedSeconds: Double { observed(state?.accumulatedSeconds ?? 0) }
    var draftNote: String { observed(state?.draftNote ?? "") }
    var isConfigured: Bool { modelContext != nil && state != nil }

    func configure(modelContext: ModelContext, state: ActiveFocusState) {
        self.modelContext = modelContext
        self.state = state
        revision &+= 1
    }

    @discardableResult
    func start(task: LearningTask, at date: Date = .now) throws -> LearningSession? {
        guard task.completedAt == nil else { throw TaskCommandError.completedTask }
        guard let modelContext, let state else { throw TaskCommandError.missingStore }
        if state.taskID == task.id { return nil }

        let closedSession = try closeCurrentSession(note: "切换任务前自动保存专注学习", endedAt: date, save: false)
        if task.startedAt == nil {
            task.startedAt = date
            task.updatedAt = date
            modelContext.insert(TaskEvent(taskID: task.id, type: .started, occurredAt: date, note: "开始执行", task: task))
        }
        state.start(taskID: task.id, at: date)
        try modelContext.commitOrRollback()
        revision &+= 1
        return closedSession
    }

    func pause(at date: Date = .now) throws {
        guard let modelContext, let state else { throw TaskCommandError.missingStore }
        state.pause(at: date)
        try modelContext.commitOrRollback()
        revision &+= 1
    }

    func resume(at date: Date = .now) throws {
        guard let modelContext, let state else { throw TaskCommandError.missingStore }
        state.resume(at: date)
        try modelContext.commitOrRollback()
        revision &+= 1
    }

    func updateDraftNote(_ note: String) throws {
        guard let modelContext, let state else { throw TaskCommandError.missingStore }
        state.draftNote = note
        try modelContext.commitOrRollback()
        revision &+= 1
    }

    @discardableResult
    func finish(note: String, at date: Date = .now, save: Bool = true) throws -> LearningSession? {
        let session = try closeCurrentSession(note: note, endedAt: date, save: save)
        revision &+= 1
        return session
    }

    func clearIfNeeded(taskID: UUID, save: Bool = true) throws {
        guard let modelContext, let state else { throw TaskCommandError.missingStore }
        guard state.taskID == taskID else { return }
        state.clear()
        if save {
            try modelContext.commitOrRollback()
        }
        revision &+= 1
    }

    private func closeCurrentSession(note: String, endedAt: Date, save: Bool) throws -> LearningSession? {
        guard let modelContext, let state else { throw TaskCommandError.missingStore }
        guard let taskID = state.taskID, let originalStartedAt = state.originalStartedAt else {
            state.clear()
            if save { try modelContext.commitOrRollback() }
            return nil
        }

        let finalEndedAt = max(endedAt, originalStartedAt)
        let finalNote = note.trimmed.isEmpty ? "完成一次专注学习" : note.trimmed
        let session = LearningSession(
            taskID: taskID,
            startedAt: originalStartedAt,
            endedAt: finalEndedAt,
            note: finalNote,
            activeSeconds: state.activeSeconds(at: finalEndedAt),
            task: try modelContext.fetch(FetchDescriptor<LearningTask>()).first(where: { $0.id == taskID })
        )
        modelContext.insert(session)
        modelContext.insert(
            TaskEvent(
                taskID: taskID,
                type: .progress,
                occurredAt: finalEndedAt,
                note: finalNote,
                task: session.task
            )
        )
        state.clear()
        if save {
            try modelContext.commitOrRollback()
        }
        return session
    }

    private func observed<Value>(_ value: Value) -> Value {
        _ = revision
        return value
    }
}

@MainActor
struct AchievementCoordinator {
    let modelContext: ModelContext

    func evaluate(relatedTask: LearningTask? = nil, now: Date = .now) throws -> [AchievementRecord] {
        let tasks = try modelContext.fetch(FetchDescriptor<LearningTask>())
        let sessions = try modelContext.fetch(FetchDescriptor<LearningSession>())
        let events = try modelContext.fetch(FetchDescriptor<TaskEvent>())
        let achievements = try modelContext.fetch(FetchDescriptor<AchievementRecord>())
        let unlockedKinds = AchievementRuleEngine.newlyUnlockedKinds(
            tasks: tasks,
            sessions: sessions,
            events: events,
            existingKindRawValues: Set(achievements.map(\.kindRaw)),
            now: now
        )
        let records = unlockedKinds.map { kind in
            AchievementRecord(
                kind: kind,
                unlockedAt: now,
                relatedTaskID: AchievementRuleEngine.relatedTaskID(
                    for: kind,
                    preferredTask: relatedTask,
                    tasks: tasks
                )
            )
        }
        records.forEach(modelContext.insert)
        if !records.isEmpty {
            try modelContext.commitOrRollback()
        }
        return records
    }
}

@MainActor
struct ReminderCoordinator {
    let modelContext: ModelContext

    func scan(now: Date = .now) throws -> [TaskEvent] {
        let tasks = try modelContext.fetch(FetchDescriptor<LearningTask>())
        let events = try modelContext.fetch(FetchDescriptor<TaskEvent>())
        guard let settings = try modelContext.fetch(FetchDescriptor<AppSettings>()).first else {
            throw TaskCommandError.missingStore
        }
        let missed = DeadlineEventRecorder.missingEvents(tasks: tasks, events: events, now: now)
        let reminders = ReminderRuntimePolicy.dueReminders(
            tasks: tasks,
            events: events + missed,
            settings: settings,
            notificationState: settings.notificationStatus,
            now: now
        )
        let inserted = missed + reminders
        let taskByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        inserted.forEach { event in
            event.task = taskByID[event.taskID]
            modelContext.insert(event)
        }
        if !inserted.isEmpty {
            try modelContext.commitOrRollback()
        }
        return inserted
    }

    func rescheduleAll() throws {
        let tasks = try modelContext.fetch(FetchDescriptor<LearningTask>())
        guard let settings = try modelContext.fetch(FetchDescriptor<AppSettings>()).first else {
            throw TaskCommandError.missingStore
        }
        ReminderScheduler.rescheduleAll(tasks: tasks, settings: settings)
    }

    func nextScanDate(now: Date = .now) throws -> Date {
        let tasks = try modelContext.fetch(FetchDescriptor<LearningTask>()).filter { $0.completedAt == nil }
        let settings = try modelContext.fetch(FetchDescriptor<AppSettings>()).first
        let leadMinutes = max(1, settings?.reminderLeadMinutes ?? 30)
        let candidates = tasks.flatMap { task -> [Date] in
            [
                task.deadline.addingTimeInterval(-Double(leadMinutes) * 60),
                task.deadline.addingTimeInterval(1),
                task.deadline.addingTimeInterval(5 * 60)
            ].filter { $0 > now }
        }
        return candidates.min() ?? now.addingTimeInterval(15 * 60)
    }
}

@MainActor
struct WidgetSyncCoordinator {
    let modelContext: ModelContext

    func synchronize(now: Date = .now) throws {
        let tasks = try modelContext.fetch(FetchDescriptor<LearningTask>())
        let sessions = try modelContext.fetch(FetchDescriptor<LearningSession>())
        let focusState = try modelContext.fetch(FetchDescriptor<ActiveFocusState>()).first
        let transparency = try modelContext.fetch(FetchDescriptor<AppSettings>()).first?.resolvedGlassTransparency
            ?? DayDayUpWidgetShared.defaultGlassTransparency
        WidgetSnapshotWriter.write(
            tasks: tasks,
            sessions: sessions,
            focusState: focusState,
            glassTransparency: transparency,
            now: now
        )
    }
}

extension ModelContext {
    @MainActor
    func commitOrRollback() throws {
        do {
            try save()
        } catch {
            rollback()
            Logger(subsystem: "com.daydayup.app", category: "Persistence")
                .error("SwiftData save failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
