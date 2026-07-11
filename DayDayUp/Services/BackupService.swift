import Foundation
import SwiftData

struct DayDayUpBackupDocument: Codable {
    var version: Int
    var exportedAt: Date
    var settings: AppSettingsSnapshot
    var activeFocus: ActiveFocusSnapshot?
    var tasks: [LearningTaskSnapshot]
    var sessions: [LearningSessionSnapshot]
    var events: [TaskEventSnapshot]
    var achievements: [AchievementSnapshot]
}

struct AppSettingsSnapshot: Codable {
    var reminderLeadMinutes: Int
    var dailyReminderEnabled: Bool
    var dailyReminderHour: Int
    var dailyReminderMinute: Int
    var overdueReminderEnabled: Bool
    var didRequestNotificationAuthorization: Bool
    var notificationStatusRaw: String
    var lastBackupURL: String
    var appearanceModeRaw: String?
    var glassTransparency: Double?
}

struct ActiveFocusSnapshot: Codable {
    var taskID: UUID?
    var originalStartedAt: Date?
    var currentStartedAt: Date?
    var pausedAt: Date?
    var accumulatedSeconds: Double
    var draftNote: String
}

struct LearningTaskSnapshot: Codable {
    var id: UUID
    var name: String
    var details: String
    var direction: String
    var plannedAt: Date
    var startedAt: Date?
    var deadline: Date
    var completedAt: Date?
    var estimatedMinutes: Int
    var progress: Double
    var completionCriteria: String
    var resourceLink: String
    var notes: String
    var blockReason: String
    var recoveryNote: String
    var reviewNote: String
    var updatedAt: Date
}

struct LearningSessionSnapshot: Codable {
    var id: UUID
    var taskID: UUID
    var startedAt: Date
    var endedAt: Date
    var note: String
    var activeSeconds: Double?
}

struct TaskEventSnapshot: Codable {
    var id: UUID
    var taskID: UUID
    var typeRaw: String
    var occurredAt: Date
    var note: String
}

struct AchievementSnapshot: Codable {
    var id: UUID
    var kindRaw: String
    var unlockedAt: Date
    var relatedTaskID: UUID?
    var isSeen: Bool
}

struct BackupImportSummary {
    var taskCount: Int
    var sessionCount: Int
    var eventCount: Int
    var achievementCount: Int
    var skippedOlderTaskCount: Int = 0

    var text: String {
        let base = "任务 \(taskCount) 个，学习时段 \(sessionCount) 条，历程事件 \(eventCount) 条，里程碑 \(achievementCount) 个"
        guard skippedOlderTaskCount > 0 else { return base }
        return "\(base)，保留本地较新任务 \(skippedOlderTaskCount) 个"
    }
}

enum BackupValidationError: LocalizedError, Equatable {
    case unsupportedVersion(Int)
    case duplicateIdentifier(String)
    case invalidTask(String)
    case invalidSession(String)
    case invalidEvent(String)
    case invalidAchievement(String)
    case invalidSettings(String)
    case invalidFocus(String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version):
            "不支持的备份版本：\(version)。"
        case let .duplicateIdentifier(type):
            "备份中存在重复的\(type)标识。"
        case let .invalidTask(reason):
            "任务数据无效：\(reason)"
        case let .invalidSession(reason):
            "学习时段数据无效：\(reason)"
        case let .invalidEvent(reason):
            "历程事件数据无效：\(reason)"
        case let .invalidAchievement(reason):
            "里程碑数据无效：\(reason)"
        case let .invalidSettings(reason):
            "设置数据无效：\(reason)"
        case let .invalidFocus(reason):
            "专注状态无效：\(reason)"
        }
    }
}

enum DayDayUpBackupService {
    static let currentVersion = 1
    static let supportedVersions = Set([currentVersion])

    static func exportBackup(
        to url: URL,
        tasks: [LearningTask],
        sessions: [LearningSession],
        events: [TaskEvent],
        achievements: [AchievementRecord],
        settings: AppSettings,
        focusState: ActiveFocusState?
    ) throws {
        let document = DayDayUpBackupDocument(
            version: currentVersion,
            exportedAt: .now,
            settings: AppSettingsSnapshot(settings),
            activeFocus: focusState.map(ActiveFocusSnapshot.init),
            tasks: tasks.map(LearningTaskSnapshot.init),
            sessions: sessions.map(LearningSessionSnapshot.init),
            events: events.map(TaskEventSnapshot.init),
            achievements: achievements.map(AchievementSnapshot.init)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(document).write(to: url, options: .atomic)
    }

    static func previewBackup(at url: URL) throws -> BackupImportSummary {
        let document = try decodeBackup(at: url)
        return BackupImportSummary(
            taskCount: document.tasks.count,
            sessionCount: document.sessions.count,
            eventCount: document.events.count,
            achievementCount: document.achievements.count
        )
    }

    @MainActor
    static func importBackup(
        from url: URL,
        modelContext: ModelContext,
        settings: AppSettings,
        focusState: ActiveFocusState?
    ) throws -> BackupImportSummary {
        let document = try decodeBackup(at: url)
        let persistedTasks = try modelContext.fetch(FetchDescriptor<LearningTask>())
        let persistedSessions = try modelContext.fetch(FetchDescriptor<LearningSession>())
        let persistedEvents = try modelContext.fetch(FetchDescriptor<TaskEvent>())
        let persistedAchievements = try modelContext.fetch(FetchDescriptor<AchievementRecord>())
        var taskByID = Dictionary(persistedTasks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var sessionByID = Dictionary(persistedSessions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var eventByID = Dictionary(persistedEvents.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var achievementByID = Dictionary(persistedAchievements.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var skippedOlderTaskCount = 0

        apply(document.settings, to: settings)

        if let snapshot = document.activeFocus, let focusState {
            apply(snapshot, to: focusState)
        } else {
            focusState?.clear()
        }

        for snapshot in document.tasks {
            if let task = taskByID[snapshot.id] {
                if snapshot.updatedAt >= task.updatedAt {
                    apply(snapshot, to: task)
                } else {
                    skippedOlderTaskCount += 1
                }
            } else {
                let task = LearningTask(snapshot)
                modelContext.insert(task)
                taskByID[task.id] = task
            }
        }

        for snapshot in document.sessions {
            if sessionByID[snapshot.id] == nil {
                let session = LearningSession(snapshot)
                session.task = taskByID[snapshot.taskID]
                modelContext.insert(session)
                sessionByID[session.id] = session
            }
        }

        for snapshot in document.events {
            if eventByID[snapshot.id] == nil {
                let event = TaskEvent(snapshot)
                event.task = taskByID[snapshot.taskID]
                modelContext.insert(event)
                eventByID[event.id] = event
            }
        }

        for snapshot in document.achievements {
            if achievementByID[snapshot.id] == nil {
                let achievement = AchievementRecord(snapshot)
                modelContext.insert(achievement)
                achievementByID[achievement.id] = achievement
            }
        }

        for session in sessionByID.values {
            session.task = taskByID[session.taskID]
        }
        for event in eventByID.values {
            event.task = taskByID[event.taskID]
        }

        try modelContext.commitOrRollback()

        return BackupImportSummary(
            taskCount: document.tasks.count,
            sessionCount: document.sessions.count,
            eventCount: document.events.count,
            achievementCount: document.achievements.count,
            skippedOlderTaskCount: skippedOlderTaskCount
        )
    }

    private static func decodeBackup(at url: URL) throws -> DayDayUpBackupDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(DayDayUpBackupDocument.self, from: Data(contentsOf: url))
        try validateBackup(document)
        return document
    }

    static func validateBackup(_ document: DayDayUpBackupDocument) throws {
        guard supportedVersions.contains(document.version) else {
            throw BackupValidationError.unsupportedVersion(document.version)
        }
        guard unique(document.tasks.map(\.id)) else {
            throw BackupValidationError.duplicateIdentifier("任务")
        }
        guard unique(document.sessions.map(\.id)) else {
            throw BackupValidationError.duplicateIdentifier("学习时段")
        }
        guard unique(document.events.map(\.id)) else {
            throw BackupValidationError.duplicateIdentifier("历程事件")
        }
        guard unique(document.achievements.map(\.id)) else {
            throw BackupValidationError.duplicateIdentifier("里程碑")
        }

        let taskByID = Dictionary(uniqueKeysWithValues: document.tasks.map { ($0.id, $0) })
        for task in document.tasks {
            guard !task.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw BackupValidationError.invalidTask("名称不能为空")
            }
            guard task.progress.isFinite, (0...1).contains(task.progress) else {
                throw BackupValidationError.invalidTask("完成度必须在 0 到 1 之间")
            }
            guard (15...1440).contains(task.estimatedMinutes) else {
                throw BackupValidationError.invalidTask("预计时长超出范围")
            }
            guard task.deadline >= task.plannedAt else {
                throw BackupValidationError.invalidTask("deadline 早于计划时间")
            }
            if let completedAt = task.completedAt {
                guard task.progress >= 1 else {
                    throw BackupValidationError.invalidTask("已完成任务的完成度不足 100%")
                }
                guard completedAt >= task.plannedAt else {
                    throw BackupValidationError.invalidTask("完成时间早于计划时间")
                }
            }
        }

        for session in document.sessions {
            guard taskByID[session.taskID] != nil else {
                throw BackupValidationError.invalidSession("引用了不存在的任务")
            }
            guard session.endedAt >= session.startedAt,
                  session.activeSeconds.map({ $0.isFinite && $0 >= 0 }) ?? true else {
                throw BackupValidationError.invalidSession("时长或时间线不合法")
            }
        }

        for event in document.events {
            guard taskByID[event.taskID] != nil else {
                throw BackupValidationError.invalidEvent("引用了不存在的任务")
            }
            guard TaskEventType(rawValue: event.typeRaw) != nil else {
                throw BackupValidationError.invalidEvent("包含未知事件类型 \(event.typeRaw)")
            }
        }

        for achievement in document.achievements {
            guard AchievementKind(rawValue: achievement.kindRaw) != nil else {
                throw BackupValidationError.invalidAchievement("包含未知里程碑类型 \(achievement.kindRaw)")
            }
            if let relatedTaskID = achievement.relatedTaskID, taskByID[relatedTaskID] == nil {
                throw BackupValidationError.invalidAchievement("引用了不存在的任务")
            }
        }

        guard (1...1440).contains(document.settings.reminderLeadMinutes),
              (0...23).contains(document.settings.dailyReminderHour),
              (0...59).contains(document.settings.dailyReminderMinute),
              ReminderAuthorizationState(rawValue: document.settings.notificationStatusRaw) != nil,
              AppAppearanceMode(rawValue: document.settings.appearanceModeRaw ?? AppAppearanceMode.light.rawValue) != nil,
              document.settings.glassTransparency.map({ $0.isFinite && (0...1).contains($0) }) ?? true else {
            throw BackupValidationError.invalidSettings("范围或枚举值不合法")
        }

        if let focus = document.activeFocus {
            guard focus.accumulatedSeconds.isFinite, focus.accumulatedSeconds >= 0 else {
                throw BackupValidationError.invalidFocus("累计时长不合法")
            }
            if let taskID = focus.taskID {
                guard let task = taskByID[taskID], task.completedAt == nil else {
                    throw BackupValidationError.invalidFocus("引用了不存在或已完成的任务")
                }
                guard focus.originalStartedAt != nil,
                      (focus.currentStartedAt != nil) != (focus.pausedAt != nil) else {
                    throw BackupValidationError.invalidFocus("运行和暂停状态不一致")
                }
            } else if focus.originalStartedAt != nil || focus.currentStartedAt != nil || focus.pausedAt != nil {
                throw BackupValidationError.invalidFocus("空闲状态仍包含计时信息")
            }
        }
    }

    private static func unique<Value: Hashable>(_ values: [Value]) -> Bool {
        Set(values).count == values.count
    }

    private static func apply(_ snapshot: AppSettingsSnapshot, to settings: AppSettings) {
        settings.reminderLeadMinutes = min(max(snapshot.reminderLeadMinutes, 1), 1440)
        settings.dailyReminderEnabled = snapshot.dailyReminderEnabled
        settings.dailyReminderHour = min(max(snapshot.dailyReminderHour, 0), 23)
        settings.dailyReminderMinute = min(max(snapshot.dailyReminderMinute, 0), 59)
        settings.overdueReminderEnabled = snapshot.overdueReminderEnabled
        settings.didRequestNotificationAuthorization = snapshot.didRequestNotificationAuthorization
        settings.notificationStatusRaw = snapshot.notificationStatusRaw
        settings.lastBackupURL = snapshot.lastBackupURL
        settings.appearanceModeRaw = snapshot.appearanceModeRaw ?? AppAppearanceMode.light.rawValue
        settings.resolvedGlassTransparency = snapshot.glassTransparency ?? AppSettings.defaultGlassTransparency
    }

    private static func apply(_ snapshot: ActiveFocusSnapshot, to focusState: ActiveFocusState) {
        focusState.taskID = snapshot.taskID
        focusState.originalStartedAt = snapshot.originalStartedAt
        focusState.currentStartedAt = snapshot.currentStartedAt
        focusState.pausedAt = snapshot.pausedAt
        focusState.accumulatedSeconds = snapshot.accumulatedSeconds
        focusState.draftNote = snapshot.draftNote
    }

    private static func apply(_ snapshot: LearningTaskSnapshot, to task: LearningTask) {
        task.name = snapshot.name
        task.details = snapshot.details
        task.direction = snapshot.direction
        task.plannedAt = snapshot.plannedAt
        task.startedAt = snapshot.startedAt
        task.deadline = snapshot.deadline
        task.completedAt = snapshot.completedAt
        task.estimatedMinutes = snapshot.estimatedMinutes
        task.progress = snapshot.progress
        task.completionCriteria = snapshot.completionCriteria
        task.resourceLink = snapshot.resourceLink
        task.notes = snapshot.notes
        task.blockReason = snapshot.blockReason
        task.recoveryNote = snapshot.recoveryNote
        task.reviewNote = snapshot.reviewNote
        task.updatedAt = snapshot.updatedAt
    }

    private static func apply(_ snapshot: LearningSessionSnapshot, to session: LearningSession) {
        session.taskID = snapshot.taskID
        session.startedAt = snapshot.startedAt
        session.endedAt = snapshot.endedAt
        session.note = snapshot.note
        session.activeSeconds = snapshot.activeSeconds
    }

    private static func apply(_ snapshot: TaskEventSnapshot, to event: TaskEvent) {
        event.taskID = snapshot.taskID
        event.typeRaw = snapshot.typeRaw
        event.occurredAt = snapshot.occurredAt
        event.note = snapshot.note
    }

    private static func apply(_ snapshot: AchievementSnapshot, to achievement: AchievementRecord) {
        achievement.kindRaw = snapshot.kindRaw
        achievement.unlockedAt = snapshot.unlockedAt
        achievement.relatedTaskID = snapshot.relatedTaskID
        achievement.isSeen = snapshot.isSeen
    }
}

private extension AppSettingsSnapshot {
    init(_ settings: AppSettings) {
        reminderLeadMinutes = settings.reminderLeadMinutes
        dailyReminderEnabled = settings.dailyReminderEnabled
        dailyReminderHour = settings.dailyReminderHour
        dailyReminderMinute = settings.dailyReminderMinute
        overdueReminderEnabled = settings.overdueReminderEnabled
        didRequestNotificationAuthorization = settings.didRequestNotificationAuthorization
        notificationStatusRaw = settings.notificationStatusRaw
        lastBackupURL = settings.lastBackupURL
        appearanceModeRaw = settings.appearanceMode.rawValue
        glassTransparency = settings.resolvedGlassTransparency
    }
}

private extension ActiveFocusSnapshot {
    init(_ focusState: ActiveFocusState) {
        taskID = focusState.taskID
        originalStartedAt = focusState.originalStartedAt
        currentStartedAt = focusState.currentStartedAt
        pausedAt = focusState.pausedAt
        accumulatedSeconds = focusState.accumulatedSeconds
        draftNote = focusState.draftNote
    }
}

private extension LearningTaskSnapshot {
    init(_ task: LearningTask) {
        id = task.id
        name = task.name
        details = task.details
        direction = task.direction
        plannedAt = task.plannedAt
        startedAt = task.startedAt
        deadline = task.deadline
        completedAt = task.completedAt
        estimatedMinutes = task.estimatedMinutes
        progress = task.progress
        completionCriteria = task.completionCriteria
        resourceLink = task.resourceLink
        notes = task.notes
        blockReason = task.blockReason
        recoveryNote = task.recoveryNote
        reviewNote = task.reviewNote
        updatedAt = task.updatedAt
    }
}

private extension LearningSessionSnapshot {
    init(_ session: LearningSession) {
        id = session.id
        taskID = session.taskID
        startedAt = session.startedAt
        endedAt = session.endedAt
        note = session.note
        activeSeconds = session.activeSeconds
    }
}

private extension TaskEventSnapshot {
    init(_ event: TaskEvent) {
        id = event.id
        taskID = event.taskID
        typeRaw = event.typeRaw
        occurredAt = event.occurredAt
        note = event.note
    }
}

private extension AchievementSnapshot {
    init(_ achievement: AchievementRecord) {
        id = achievement.id
        kindRaw = achievement.kindRaw
        unlockedAt = achievement.unlockedAt
        relatedTaskID = achievement.relatedTaskID
        isSeen = achievement.isSeen
    }
}

private extension LearningTask {
    convenience init(_ snapshot: LearningTaskSnapshot) {
        self.init(
            id: snapshot.id,
            name: snapshot.name,
            details: snapshot.details,
            direction: snapshot.direction,
            plannedAt: snapshot.plannedAt,
            startedAt: snapshot.startedAt,
            deadline: snapshot.deadline,
            completedAt: snapshot.completedAt,
            estimatedMinutes: snapshot.estimatedMinutes,
            progress: snapshot.progress,
            completionCriteria: snapshot.completionCriteria,
            resourceLink: snapshot.resourceLink,
            notes: snapshot.notes,
            blockReason: snapshot.blockReason,
            recoveryNote: snapshot.recoveryNote,
            reviewNote: snapshot.reviewNote,
            updatedAt: snapshot.updatedAt
        )
    }
}

private extension LearningSession {
    convenience init(_ snapshot: LearningSessionSnapshot) {
        self.init(
            id: snapshot.id,
            taskID: snapshot.taskID,
            startedAt: snapshot.startedAt,
            endedAt: snapshot.endedAt,
            note: snapshot.note,
            activeSeconds: snapshot.activeSeconds
        )
    }
}

private extension TaskEvent {
    convenience init(_ snapshot: TaskEventSnapshot) {
        self.init(
            id: snapshot.id,
            taskID: snapshot.taskID,
            type: TaskEventType(rawValue: snapshot.typeRaw) ?? .progress,
            occurredAt: snapshot.occurredAt,
            note: snapshot.note
        )
        typeRaw = snapshot.typeRaw
    }
}

private extension AchievementRecord {
    convenience init(_ snapshot: AchievementSnapshot) {
        self.init(
            id: snapshot.id,
            kind: AchievementKind(rawValue: snapshot.kindRaw) ?? .firstTaskCompleted,
            unlockedAt: snapshot.unlockedAt,
            relatedTaskID: snapshot.relatedTaskID,
            isSeen: snapshot.isSeen
        )
        kindRaw = snapshot.kindRaw
    }
}
