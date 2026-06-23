import Foundation
import SwiftData
import UserNotifications

struct ReminderNotificationRoute: Equatable {
    var taskID: UUID?
    var eventType: TaskEventType?
    var deadline: Date?
}

enum ReminderNotificationPayloadPolicy {
    static let taskIDKey = "taskID"
    static let eventTypeKey = "eventType"
    static let deadlineKey = "deadline"

    static func userInfo(task: LearningTask, eventType: TaskEventType) -> [AnyHashable: Any] {
        [
            taskIDKey: task.id.uuidString,
            eventTypeKey: eventType.rawValue,
            deadlineKey: task.deadline.timeIntervalSince1970
        ]
    }

    static func route(from userInfo: [AnyHashable: Any]) -> ReminderNotificationRoute? {
        let eventType = (userInfo[eventTypeKey] as? String).flatMap(TaskEventType.init(rawValue:))
        let taskID = (userInfo[taskIDKey] as? String).flatMap(UUID.init(uuidString:))
        let deadline = (userInfo[deadlineKey] as? TimeInterval).map(Date.init(timeIntervalSince1970:))

        guard eventType == .leadReminder || eventType == .overdueReminder || taskID != nil else {
            return nil
        }

        return ReminderNotificationRoute(taskID: taskID, eventType: eventType, deadline: deadline)
    }
}

final class DayDayUpNotificationRouter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = DayDayUpNotificationRouter()

    func register() {
        UNUserNotificationCenter.current().delegate = self
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let route = ReminderNotificationPayloadPolicy.route(from: response.notification.request.content.userInfo) else {
            return
        }
        await MainActor.run {
            NotificationCenter.default.post(name: .dayDayUpOpenTaskFromNotification, object: route)
        }
    }
}

enum ReminderScheduler {
    static let dailyReminderID = "daydayup.daily-reminder"

    static func leadReminderID(for taskID: UUID) -> String {
        "daydayup.task.\(taskID.uuidString).lead"
    }

    static func overdueReminderID(for taskID: UUID) -> String {
        "daydayup.task.\(taskID.uuidString).overdue"
    }

    static func requestIdentifiers(for taskID: UUID) -> [String] {
        [leadReminderID(for: taskID), overdueReminderID(for: taskID)]
    }

    static func authorizationState() async -> ReminderAuthorizationState {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: authorizationState(from: settings.authorizationStatus))
            }
        }
    }

    static func requestAuthorization() async -> ReminderAuthorizationState {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return .unknown
        }
        return await authorizationState()
    }

    static func rescheduleAll(tasks: [LearningTask], settings: AppSettings) {
        for task in tasks {
            scheduleTaskReminders(for: task, settings: settings)
        }
        scheduleDailyReminder(settings: settings)
    }

    static func scheduleTaskReminders(for task: LearningTask, settings: AppSettings) {
        cancelTaskReminders(for: task)
        let reminderDates = taskReminderDates(for: task, settings: settings)

        if let leadDate = reminderDates.lead {
            addNotification(
                id: leadReminderID(for: task.id),
                date: leadDate,
                title: "DayDayUp 任务快到截止时间",
                body: "\(task.name) 截止时间：\(task.deadline.formattedDateTime())，还差一颗松果，先收好再开饭。",
                userInfo: ReminderNotificationPayloadPolicy.userInfo(task: task, eventType: .leadReminder)
            )
        }

        if let overdueDate = reminderDates.overdue {
            addNotification(
                id: overdueReminderID(for: task.id),
                date: overdueDate,
                title: "DayDayUp 任务已经逾期",
                body: "\(task.name) 截止时间：\(task.deadline.formattedDateTime())，还没有闭环，先记录卡住原因，再补上。",
                userInfo: ReminderNotificationPayloadPolicy.userInfo(task: task, eventType: .overdueReminder)
            )
        }
    }

    static func cancelTaskReminders(for task: LearningTask) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: requestIdentifiers(for: task.id))
    }

    static func taskReminderDates(
        for task: LearningTask,
        settings: AppSettings,
        now: Date = .now
    ) -> (lead: Date?, overdue: Date?) {
        guard task.completedAt == nil, task.deadline > now else {
            return (nil, nil)
        }

        let leadDate = task.deadline.addingTimeInterval(-Double(max(1, settings.reminderLeadMinutes)) * 60)
        let overdueDate = task.deadline.addingTimeInterval(5 * 60)

        return (
            lead: leadDate > now ? leadDate : nil,
            overdue: settings.overdueReminderEnabled ? overdueDate : nil
        )
    }

    static func scheduleDailyReminder(settings: AppSettings) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
        guard settings.dailyReminderEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "DayDayUp 今日学习提醒"
        content.body = "今天的篮子还空着，先开始一段专注。"
        content.sound = .default

        var components = DateComponents()
        components.hour = min(max(settings.dailyReminderHour, 0), 23)
        components.minute = min(max(settings.dailyReminderMinute, 0), 59)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: dailyReminderID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private static func addNotification(
        id: String,
        date: Date,
        title: String,
        body: String,
        userInfo: [AnyHashable: Any] = [:]
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = userInfo

        let components = notificationDateComponents(for: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func notificationDateComponents(for date: Date, calendar: Calendar = .current) -> DateComponents {
        calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
    }

    private static func authorizationState(from status: UNAuthorizationStatus) -> ReminderAuthorizationState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .provisional:
            return .provisional
        case .ephemeral:
            return .ephemeral
        @unknown default:
            return .unknown
        }
    }
}

enum ReminderAuthorizationPolicy {
    static func didCompleteAuthorizationRequest(state: ReminderAuthorizationState) -> Bool {
        switch state {
        case .unknown:
            return false
        case .notDetermined, .denied, .authorized, .provisional, .ephemeral:
            return true
        }
    }
}

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

    var text: String {
        "任务 \(taskCount) 个，学习时段 \(sessionCount) 条，历程事件 \(eventCount) 条，里程碑 \(achievementCount) 个"
    }
}

enum DayDayUpBackupService {
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
            version: 1,
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

    static func importBackup(
        from url: URL,
        modelContext: ModelContext,
        tasks: [LearningTask],
        sessions: [LearningSession],
        events: [TaskEvent],
        achievements: [AchievementRecord],
        settings: AppSettings,
        focusState: ActiveFocusState?
    ) throws -> BackupImportSummary {
        let document = try decodeBackup(at: url)
        var taskByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        var sessionByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        var eventByID = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
        var achievementByID = Dictionary(uniqueKeysWithValues: achievements.map { ($0.id, $0) })

        apply(document.settings, to: settings)

        if let snapshot = document.activeFocus, let focusState {
            apply(snapshot, to: focusState)
        }

        for snapshot in document.tasks {
            if let task = taskByID[snapshot.id] {
                apply(snapshot, to: task)
            } else {
                let task = LearningTask(snapshot)
                modelContext.insert(task)
                taskByID[task.id] = task
            }
        }

        for snapshot in document.sessions {
            if let session = sessionByID[snapshot.id] {
                apply(snapshot, to: session)
            } else {
                let session = LearningSession(snapshot)
                modelContext.insert(session)
                sessionByID[session.id] = session
            }
        }

        for snapshot in document.events {
            if let event = eventByID[snapshot.id] {
                apply(snapshot, to: event)
            } else {
                let event = TaskEvent(snapshot)
                modelContext.insert(event)
                eventByID[event.id] = event
            }
        }

        for snapshot in document.achievements {
            if let achievement = achievementByID[snapshot.id] {
                apply(snapshot, to: achievement)
            } else {
                let achievement = AchievementRecord(snapshot)
                modelContext.insert(achievement)
                achievementByID[achievement.id] = achievement
            }
        }

        return BackupImportSummary(
            taskCount: document.tasks.count,
            sessionCount: document.sessions.count,
            eventCount: document.events.count,
            achievementCount: document.achievements.count
        )
    }

    private static func decodeBackup(at url: URL) throws -> DayDayUpBackupDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DayDayUpBackupDocument.self, from: Data(contentsOf: url))
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
        settings.appearanceModeRaw = snapshot.appearanceModeRaw ?? AppAppearanceMode.system.rawValue
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
