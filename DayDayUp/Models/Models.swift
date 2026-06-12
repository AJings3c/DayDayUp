import Foundation
import SwiftData
import SwiftUI

enum TaskStatus: String, CaseIterable, Identifiable {
    case active
    case warning
    case overdue
    case completed
    case recovered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: "进行中"
        case .warning: "接近截止"
        case .overdue: "逾期未完成"
        case .completed: "按时完成"
        case .recovered: "补完成"
        }
    }

    var symbolName: String {
        switch self {
        case .active: "circle.dotted"
        case .warning: "exclamationmark.triangle.fill"
        case .overdue: "xmark.octagon.fill"
        case .completed: "checkmark.circle.fill"
        case .recovered: "arrow.triangle.2.circlepath.circle.fill"
        }
    }

    var accessibilityText: String {
        switch self {
        case .active: "普通进行中"
        case .warning: "接近截止，还没有逾期"
        case .overdue: "红色，逾期未完成"
        case .completed: "绿色，按时或提前完成"
        case .recovered: "紫色，逾期后补完成"
        }
    }
}

enum TaskEventType: String, CaseIterable, Identifiable {
    case planned
    case started
    case progress
    case blocked
    case deadline
    case completed
    case recovered
    case reviewed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .planned: "制定计划"
        case .started: "开始执行"
        case .progress: "进度更新"
        case .blocked: "记录卡住原因"
        case .deadline: "截止时间"
        case .completed: "完成任务"
        case .recovered: "补完成"
        case .reviewed: "复盘记录"
        }
    }

    var symbolName: String {
        switch self {
        case .planned: "plus.circle.fill"
        case .started: "play.circle.fill"
        case .progress: "chart.line.uptrend.xyaxis.circle.fill"
        case .blocked: "exclamationmark.triangle.fill"
        case .deadline: "calendar.badge.exclamationmark"
        case .completed: "checkmark.circle.fill"
        case .recovered: "arrow.triangle.2.circlepath.circle.fill"
        case .reviewed: "text.bubble.fill"
        }
    }
}

enum AchievementKind: String, CaseIterable, Identifiable {
    case firstTaskCompleted
    case firstOnTimeClosure
    case firstEarlyClosure
    case firstRecoveredClosure
    case focusStreak3
    case focusStreak7
    case focusStreak14
    case reviewStreak3
    case cleanWeek
    case monthlyClosureRate
    case totalFocusOneHour
    case totalFocusTenHours

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstTaskCompleted: "首次完成任务"
        case .firstOnTimeClosure: "首次按时闭环"
        case .firstEarlyClosure: "首次提前完成"
        case .firstRecoveredClosure: "首次补完成"
        case .focusStreak3: "连续专注 3 天"
        case .focusStreak7: "连续专注 7 天"
        case .focusStreak14: "连续专注 14 天"
        case .reviewStreak3: "连续复盘 3 天"
        case .cleanWeek: "本周无逾期"
        case .monthlyClosureRate: "单月闭环率达标"
        case .totalFocusOneHour: "累计学习 1 小时"
        case .totalFocusTenHours: "累计学习 10 小时"
        }
    }

    var subtitle: String {
        switch self {
        case .firstTaskCompleted: "第一颗松果已经入仓。"
        case .firstOnTimeClosure: "任务在 deadline 前完成并闭环。"
        case .firstEarlyClosure: "提前收好一颗松果。"
        case .firstRecoveredClosure: "逾期任务已经补上闭环。"
        case .focusStreak3: "连续 3 天留下专注记录。"
        case .focusStreak7: "连续 7 天保持学习节奏。"
        case .focusStreak14: "连续 14 天稳定推进。"
        case .reviewStreak3: "连续 3 天完成复盘记录。"
        case .cleanWeek: "本周暂时没有逾期任务。"
        case .monthlyClosureRate: "本月任务闭环率达到 80%。"
        case .totalFocusOneHour: "累计专注时长达到 60 分钟。"
        case .totalFocusTenHours: "累计专注时长达到 600 分钟。"
        }
    }

    var symbolName: String {
        switch self {
        case .firstTaskCompleted: "checkmark.seal.fill"
        case .firstOnTimeClosure: "clock.badge.checkmark.fill"
        case .firstEarlyClosure: "hare.fill"
        case .firstRecoveredClosure: "arrow.triangle.2.circlepath.circle.fill"
        case .focusStreak3, .focusStreak7, .focusStreak14: "flame.fill"
        case .reviewStreak3: "text.bubble.fill"
        case .cleanWeek: "calendar.badge.checkmark"
        case .monthlyClosureRate: "chart.line.uptrend.xyaxis.circle.fill"
        case .totalFocusOneHour, .totalFocusTenHours: "timer.circle.fill"
        }
    }

    var accessibilityText: String {
        "\(title)，\(subtitle)"
    }
}

@Model
final class LearningTask {
    @Attribute(.unique) var id: UUID
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
    var updatedAt: Date = Date.now

    init(
        id: UUID = UUID(),
        name: String,
        details: String,
        direction: String,
        plannedAt: Date = .now,
        startedAt: Date? = nil,
        deadline: Date,
        completedAt: Date? = nil,
        estimatedMinutes: Int = 60,
        progress: Double = 0,
        completionCriteria: String = "",
        resourceLink: String = "",
        notes: String = "",
        blockReason: String = "",
        recoveryNote: String = "",
        reviewNote: String = "",
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.details = details
        self.direction = direction
        self.plannedAt = plannedAt
        self.startedAt = startedAt
        self.deadline = deadline
        self.completedAt = completedAt
        self.estimatedMinutes = estimatedMinutes
        self.progress = progress
        self.completionCriteria = completionCriteria
        self.resourceLink = resourceLink
        self.notes = notes
        self.blockReason = blockReason
        self.recoveryNote = recoveryNote
        self.reviewNote = reviewNote
        self.updatedAt = updatedAt
    }

    func status(now: Date = .now) -> TaskStatus {
        if let completedAt {
            return completedAt > deadline ? .recovered : .completed
        }
        if now > deadline {
            return .overdue
        }
        if deadline.timeIntervalSince(now) <= 24 * 60 * 60 {
            return .warning
        }
        return .active
    }

    var isClosedLoop: Bool {
        completedAt != nil && progress >= 1.0
    }

    var delayedDays: Int {
        let reference = completedAt ?? .now
        guard reference > deadline else { return 0 }
        return Calendar.current.dateComponents([.day], from: deadline, to: reference).day ?? 0
    }

    var startDelayDays: Int {
        guard let startedAt else { return 0 }
        return Calendar.current.dateComponents([.day], from: plannedAt, to: startedAt).day ?? 0
    }
}

@Model
final class LearningSession {
    @Attribute(.unique) var id: UUID
    var taskID: UUID
    var startedAt: Date
    var endedAt: Date
    var note: String
    var activeSeconds: Double? = nil

    init(
        id: UUID = UUID(),
        taskID: UUID,
        startedAt: Date,
        endedAt: Date,
        note: String,
        activeSeconds: Double? = nil
    ) {
        self.id = id
        self.taskID = taskID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.note = note
        self.activeSeconds = activeSeconds
    }

    var durationMinutes: Int {
        let seconds = activeSeconds ?? endedAt.timeIntervalSince(startedAt)
        return max(0, Int(seconds / 60))
    }
}

@Model
final class ActiveFocusState {
    @Attribute(.unique) var id: UUID
    var taskID: UUID?
    var originalStartedAt: Date?
    var currentStartedAt: Date?
    var pausedAt: Date?
    var accumulatedSeconds: Double
    var draftNote: String

    init(
        id: UUID = UUID(),
        taskID: UUID? = nil,
        originalStartedAt: Date? = nil,
        currentStartedAt: Date? = nil,
        pausedAt: Date? = nil,
        accumulatedSeconds: Double = 0,
        draftNote: String = ""
    ) {
        self.id = id
        self.taskID = taskID
        self.originalStartedAt = originalStartedAt
        self.currentStartedAt = currentStartedAt
        self.pausedAt = pausedAt
        self.accumulatedSeconds = accumulatedSeconds
        self.draftNote = draftNote
    }

    var isActive: Bool {
        taskID != nil && originalStartedAt != nil
    }

    var isPaused: Bool {
        isActive && pausedAt != nil
    }

    func start(taskID: UUID, at date: Date = .now) {
        self.taskID = taskID
        originalStartedAt = date
        currentStartedAt = date
        pausedAt = nil
        accumulatedSeconds = 0
        draftNote = ""
    }

    func pause(at date: Date = .now) {
        guard isActive, pausedAt == nil else { return }
        if let currentStartedAt {
            accumulatedSeconds += max(0, date.timeIntervalSince(currentStartedAt))
        }
        currentStartedAt = nil
        pausedAt = date
    }

    func resume(at date: Date = .now) {
        guard isActive, pausedAt != nil else { return }
        currentStartedAt = date
        pausedAt = nil
    }

    func activeSeconds(at date: Date = .now) -> Double {
        accumulatedSeconds + (currentStartedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }

    func clear() {
        taskID = nil
        originalStartedAt = nil
        currentStartedAt = nil
        pausedAt = nil
        accumulatedSeconds = 0
        draftNote = ""
    }
}

enum ReminderAuthorizationState: String, CaseIterable, Identifiable, Codable {
    case unknown
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unknown: "未知"
        case .notDetermined: "尚未请求"
        case .denied: "已拒绝"
        case .authorized: "已允许"
        case .provisional: "临时允许"
        case .ephemeral: "临时会话允许"
        }
    }
}

enum AppAppearanceMode: String, CaseIterable, Identifiable, Codable, Equatable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@Model
final class AppSettings {
    static let defaultGlassTransparency = 0.55

    @Attribute(.unique) var id: UUID
    var createdAt: Date
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

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        reminderLeadMinutes: Int = 30,
        dailyReminderEnabled: Bool = true,
        dailyReminderHour: Int = 9,
        dailyReminderMinute: Int = 0,
        overdueReminderEnabled: Bool = true,
        didRequestNotificationAuthorization: Bool = false,
        notificationStatusRaw: String = ReminderAuthorizationState.unknown.rawValue,
        lastBackupURL: String = "",
        appearanceModeRaw: String? = AppAppearanceMode.system.rawValue,
        glassTransparency: Double = AppSettings.defaultGlassTransparency
    ) {
        self.id = id
        self.createdAt = createdAt
        self.reminderLeadMinutes = reminderLeadMinutes
        self.dailyReminderEnabled = dailyReminderEnabled
        self.dailyReminderHour = dailyReminderHour
        self.dailyReminderMinute = dailyReminderMinute
        self.overdueReminderEnabled = overdueReminderEnabled
        self.didRequestNotificationAuthorization = didRequestNotificationAuthorization
        self.notificationStatusRaw = notificationStatusRaw
        self.lastBackupURL = lastBackupURL
        self.appearanceModeRaw = appearanceModeRaw
        self.glassTransparency = Self.clampedGlassTransparency(glassTransparency)
    }

    var notificationStatus: ReminderAuthorizationState {
        get { ReminderAuthorizationState(rawValue: notificationStatusRaw) ?? .unknown }
        set { notificationStatusRaw = newValue.rawValue }
    }

    var appearanceMode: AppAppearanceMode {
        get { AppAppearanceMode(rawValue: appearanceModeRaw ?? "") ?? .system }
        set { appearanceModeRaw = newValue.rawValue }
    }

    var resolvedGlassTransparency: Double {
        get { Self.clampedGlassTransparency(glassTransparency ?? Self.defaultGlassTransparency) }
        set { glassTransparency = Self.clampedGlassTransparency(newValue) }
    }

    static func clampedGlassTransparency(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

@Model
final class TaskEvent {
    @Attribute(.unique) var id: UUID
    var taskID: UUID
    var typeRaw: String
    var occurredAt: Date
    var note: String

    init(
        id: UUID = UUID(),
        taskID: UUID,
        type: TaskEventType,
        occurredAt: Date = .now,
        note: String
    ) {
        self.id = id
        self.taskID = taskID
        self.typeRaw = type.rawValue
        self.occurredAt = occurredAt
        self.note = note
    }

    var type: TaskEventType {
        TaskEventType(rawValue: typeRaw) ?? .progress
    }
}

@Model
final class AchievementRecord {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var unlockedAt: Date
    var relatedTaskID: UUID?
    var isSeen: Bool

    init(
        id: UUID = UUID(),
        kind: AchievementKind,
        unlockedAt: Date = .now,
        relatedTaskID: UUID? = nil,
        isSeen: Bool = false
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.unlockedAt = unlockedAt
        self.relatedTaskID = relatedTaskID
        self.isSeen = isSeen
    }

    var kind: AchievementKind {
        AchievementKind(rawValue: kindRaw) ?? .firstTaskCompleted
    }
}

struct AppMetrics {
    var plannedTaskCount: Int
    var completionRate: Double
    var onTimeRate: Double
    var earlyRate: Double
    var delayedRate: Double
    var recoveredRate: Double
    var closedLoopRate: Double
    var stableFocusRate: Double
    var reviewRate: Double
    var totalFocusMinutes: Int
    var todayFocusMinutes: Int
    var weeklyFocusMinutes: Int
    var directionFocusMinutes: [String: Int]
    var unfinishedCount: Int
    var averageDelayDays: Double
    var score: Int

    var hasTasks: Bool {
        plannedTaskCount > 0
    }

    var scoreText: String {
        hasTasks ? "\(score)" : "暂无"
    }

    var scoreLabel: String {
        guard hasTasks else { return "暂无评分" }
        switch score {
        case 90...100: return "节奏优秀"
        case 75..<90: return "节奏稳定"
        case 60..<75: return "需要调整"
        default: return "执行风险较高"
        }
    }
}
