import Foundation
import SwiftData

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

    init(task: LearningTask? = nil, now: Date = .now) {
        name = task?.name ?? ""
        details = task?.details ?? ""
        direction = task?.direction ?? ""
        deadline = task?.deadline ?? TaskDeadlinePolicy.defaultDeadline(now: now)
        estimatedMinutes = task?.estimatedMinutes ?? 60
        progress = task?.progress ?? 0
        completionCriteria = task?.completionCriteria ?? ""
        resourceLink = task?.resourceLink ?? ""
        notes = task?.notes ?? ""
    }
}

enum TaskCommandError: LocalizedError {
    case emptyName
    case completedTask
    case missingStore

    var errorDescription: String? {
        switch self {
        case .emptyName:
            "任务名称不能为空。"
        case .completedTask:
            "已完成任务不能执行该操作。"
        case .missingStore:
            "应用数据尚未准备完成，请稍后重试。"
        }
    }
}

struct TaskMutationResult {
    let task: LearningTask
    let didChangeDeadline: Bool
    let completionStatus: TaskStatus?

    init(task: LearningTask, didChangeDeadline: Bool = false, completionStatus: TaskStatus? = nil) {
        self.task = task
        self.didChangeDeadline = didChangeDeadline
        self.completionStatus = completionStatus
    }
}

@MainActor
struct TaskActionSet {
    let newTask: () -> Void
    let edit: (LearningTask) -> Void
    let beginFocus: (LearningTask) -> Void
    let updateProgress: (LearningTask, Double, String) -> Void
    let complete: (LearningTask) -> Void
    let recordBlock: (LearningTask, String) -> Void
    let recordRecovery: (LearningTask, String) -> Void
    let saveReview: (LearningTask, String) -> Void
    let delete: (LearningTask) -> Void
    let createSample: () -> Void
}

@MainActor
struct FocusActionSet {
    let pause: () -> Void
    let resume: () -> Void
    let finish: (String) -> Void
    let updateNote: (String) -> Void
}

@MainActor
struct SettingsActionSet {
    let appearanceChanged: () -> Void
    let settingsChanged: () -> Void
    let requestNotifications: () -> Void
    let exportBackup: (URL) -> String
    let previewImport: (URL) -> String
    let importBackup: (URL) -> String
}

enum TaskEventFactory {
    static func deadline(for task: LearningTask) -> TaskEvent {
        TaskEvent(
            taskID: task.id,
            type: .deadline,
            occurredAt: task.deadline,
            note: "截止时间：\(task.deadline.formattedDateTime())",
            task: task
        )
    }
}

@MainActor
struct TaskCommandService {
    let modelContext: ModelContext

    func create(
        from draft: TaskDraft,
        plannedNote: String = "制定计划",
        now: Date = .now
    ) throws -> TaskMutationResult {
        let normalized = try normalizedDraft(draft, task: nil, now: now)
        let task = LearningTask(
            name: normalized.name,
            details: normalized.details,
            direction: normalized.direction,
            plannedAt: now,
            deadline: normalized.deadline,
            estimatedMinutes: normalized.estimatedMinutes,
            progress: normalized.progress,
            completionCriteria: normalized.completionCriteria,
            resourceLink: normalized.resourceLink,
            notes: normalized.notes,
            updatedAt: now
        )
        modelContext.insert(task)
        modelContext.insert(TaskEvent(taskID: task.id, type: .planned, occurredAt: now, note: plannedNote, task: task))
        modelContext.insert(TaskEventFactory.deadline(for: task))
        try modelContext.commitOrRollback()
        return TaskMutationResult(task: task, didChangeDeadline: true)
    }

    func update(_ task: LearningTask, from draft: TaskDraft, now: Date = .now) throws -> TaskMutationResult {
        let normalized = try normalizedDraft(draft, task: task, now: now)
        let previousDeadline = task.deadline
        task.name = normalized.name
        task.details = normalized.details
        task.direction = normalized.direction
        task.deadline = normalized.deadline
        task.estimatedMinutes = normalized.estimatedMinutes
        task.progress = task.completedAt == nil ? normalized.progress : 1
        task.completionCriteria = normalized.completionCriteria
        task.resourceLink = normalized.resourceLink
        task.notes = normalized.notes
        task.updatedAt = now
        modelContext.insert(TaskEvent(taskID: task.id, type: .progress, occurredAt: now, note: "更新任务信息", task: task))
        let didChangeDeadline = previousDeadline != task.deadline
        if didChangeDeadline {
            modelContext.insert(TaskEventFactory.deadline(for: task))
        }
        try modelContext.commitOrRollback()
        return TaskMutationResult(task: task, didChangeDeadline: didChangeDeadline)
    }

    func updateProgress(
        _ task: LearningTask,
        progress: Double,
        note: String,
        now: Date = .now
    ) throws -> TaskMutationResult {
        guard task.completedAt == nil else { throw TaskCommandError.completedTask }
        let clamped = min(max(progress, 0), 1)
        let trimmedNote = note.trimmed
        if clamped >= 1 {
            return try complete(task, note: trimmedNote, now: now)
        }
        task.progress = clamped
        task.updatedAt = now
        let finalNote = trimmedNote.isEmpty ? "完成度更新为 \(clamped.percentText)" : trimmedNote
        modelContext.insert(TaskEvent(taskID: task.id, type: .progress, occurredAt: now, note: finalNote, task: task))
        try modelContext.commitOrRollback()
        return TaskMutationResult(task: task)
    }

    func complete(_ task: LearningTask, note: String? = nil, now: Date = .now) throws -> TaskMutationResult {
        guard task.completedAt == nil else { throw TaskCommandError.completedTask }
        let trimmedNote = note?.trimmed ?? ""
        task.progress = 1
        task.completedAt = now
        task.updatedAt = now
        let recovered = now > task.deadline
        if recovered {
            task.recoveryNote = trimmedNote.isEmpty ? "逾期后补完成。" : trimmedNote
        }
        modelContext.insert(
            TaskEvent(
                taskID: task.id,
                type: recovered ? .recovered : .completed,
                occurredAt: now,
                note: completionNote(recovered: recovered, note: trimmedNote),
                task: task
            )
        )
        try modelContext.commitOrRollback()
        return TaskMutationResult(
            task: task,
            completionStatus: recovered ? .recovered : .completed
        )
    }

    func recordBlock(_ task: LearningTask, note: String, now: Date = .now) throws -> TaskMutationResult {
        let trimmed = note.trimmed
        guard !trimmed.isEmpty else { return TaskMutationResult(task: task) }
        task.blockReason = trimmed
        task.updatedAt = now
        modelContext.insert(TaskEvent(taskID: task.id, type: .blocked, occurredAt: now, note: trimmed, task: task))
        try modelContext.commitOrRollback()
        return TaskMutationResult(task: task)
    }

    func recordRecovery(_ task: LearningTask, note: String, now: Date = .now) throws -> TaskMutationResult {
        let trimmed = note.trimmed
        if task.completedAt == nil, task.status(now: now) == .overdue {
            return try complete(task, note: trimmed, now: now)
        }
        guard !trimmed.isEmpty else { return TaskMutationResult(task: task) }
        task.recoveryNote = trimmed
        task.updatedAt = now
        let eventType: TaskEventType = task.status(now: now) == .recovered ? .recovered : .progress
        modelContext.insert(TaskEvent(taskID: task.id, type: eventType, occurredAt: now, note: "补救记录：\(trimmed)", task: task))
        try modelContext.commitOrRollback()
        return TaskMutationResult(task: task)
    }

    func saveReview(_ task: LearningTask, note: String, now: Date = .now) throws -> TaskMutationResult {
        let trimmed = note.trimmed
        guard !trimmed.isEmpty else { return TaskMutationResult(task: task) }
        task.reviewNote = trimmed
        task.updatedAt = now
        modelContext.insert(TaskEvent(taskID: task.id, type: .reviewed, occurredAt: now, note: trimmed, task: task))
        try modelContext.commitOrRollback()
        return TaskMutationResult(task: task)
    }

    func delete(_ task: LearningTask) throws {
        modelContext.delete(task)
        try modelContext.commitOrRollback()
    }

    private func normalizedDraft(_ draft: TaskDraft, task: LearningTask?, now: Date) throws -> TaskDraft {
        var normalized = draft
        normalized.name = draft.name.trimmed
        guard !normalized.name.isEmpty else { throw TaskCommandError.emptyName }
        normalized.details = draft.details.trimmed
        normalized.direction = draft.direction.trimmed
        normalized.deadline = TaskDeadlinePolicy.normalizedDeadline(draft.deadline, for: task, now: now)
        normalized.estimatedMinutes = min(max(draft.estimatedMinutes, 15), 1440)
        normalized.progress = min(max(draft.progress, 0), 1)
        normalized.completionCriteria = draft.completionCriteria.trimmed
        normalized.resourceLink = draft.resourceLink.trimmed
        normalized.notes = draft.notes.trimmed
        return normalized
    }

    private func completionNote(recovered: Bool, note: String) -> String {
        if !note.isEmpty {
            return recovered ? "逾期后补完成：\(note)" : "任务完成啦，开始干饭！备注：\(note)"
        }
        return recovered ? "逾期后补完成：任务完成啦，开始干饭！" : "任务完成啦，开始干饭！"
    }
}
