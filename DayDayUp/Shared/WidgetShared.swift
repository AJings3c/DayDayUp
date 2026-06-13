import Foundation

enum WidgetTaskStatus: String, Codable, CaseIterable {
    case active
    case warning
    case overdue
    case completed
    case recovered

    var title: String {
        switch self {
        case .active: "待执行"
        case .warning: "接近截止"
        case .overdue: "逾期"
        case .completed: "已完成"
        case .recovered: "已补完成"
        }
    }
}

struct WidgetTaskSnapshot: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var deadline: Date
    var completedAt: Date?
    var progress: Double
    var statusRaw: String
    var completionCriteria: String

    var status: WidgetTaskStatus {
        WidgetTaskStatus(rawValue: statusRaw) ?? .active
    }
}

struct WidgetFocusSnapshot: Codable, Equatable {
    var taskID: UUID?
    var originalStartedAt: Date?
    var currentStartedAt: Date?
    var pausedAt: Date?
    var accumulatedSeconds: Double
}

struct WidgetTodaySnapshot: Codable, Equatable {
    var focusMinutes: Int
    var incompleteCount: Int
    var completedCount: Int
    var overdueCount: Int
    var queue: [WidgetTaskSnapshot]
    var recommendedTaskID: UUID?
}

struct WidgetRhythmSnapshot: Codable, Equatable {
    var score: Int
    var scoreLabel: String
    var weeklyFocusMinutes: Int
    var completionRate: Double
    var onTimeRate: Double
    var reviewRate: Double
    var overdueCount: Int
    var riskTask: WidgetTaskSnapshot?
    var hasTasks: Bool
}

enum WidgetTimelineMode: String, Codable, Equatable {
    case nextTask
    case todayBasket
    case rhythmGauge
}

struct WidgetDashboardSnapshot: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case updatedAt
        case task
        case activeFocus
        case todayFocusMinutes
        case overdueCount
        case today
        case rhythm
        case glassTransparency
    }

    var updatedAt: Date
    var task: WidgetTaskSnapshot?
    var activeFocus: WidgetFocusSnapshot?
    var todayFocusMinutes: Int
    var overdueCount: Int
    var today: WidgetTodaySnapshot?
    var rhythm: WidgetRhythmSnapshot?
    var glassTransparency: Double

    init(
        updatedAt: Date,
        task: WidgetTaskSnapshot?,
        activeFocus: WidgetFocusSnapshot?,
        todayFocusMinutes: Int,
        overdueCount: Int,
        today: WidgetTodaySnapshot? = nil,
        rhythm: WidgetRhythmSnapshot? = nil,
        glassTransparency: Double = DayDayUpWidgetShared.defaultGlassTransparency
    ) {
        self.updatedAt = updatedAt
        self.task = task
        self.activeFocus = activeFocus
        self.todayFocusMinutes = todayFocusMinutes
        self.overdueCount = overdueCount
        self.today = today
        self.rhythm = rhythm
        self.glassTransparency = DayDayUpWidgetShared.clampedGlassTransparency(glassTransparency)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        task = try container.decodeIfPresent(WidgetTaskSnapshot.self, forKey: .task)
        activeFocus = try container.decodeIfPresent(WidgetFocusSnapshot.self, forKey: .activeFocus)
        todayFocusMinutes = try container.decode(Int.self, forKey: .todayFocusMinutes)
        overdueCount = try container.decode(Int.self, forKey: .overdueCount)
        today = try container.decodeIfPresent(WidgetTodaySnapshot.self, forKey: .today)
        rhythm = try container.decodeIfPresent(WidgetRhythmSnapshot.self, forKey: .rhythm)
        glassTransparency = DayDayUpWidgetShared.clampedGlassTransparency(
            try container.decodeIfPresent(Double.self, forKey: .glassTransparency)
                ?? DayDayUpWidgetShared.defaultGlassTransparency
        )
    }
}

struct WidgetPendingIntent: Codable, Equatable {
    enum Kind: String, Codable {
        case openApp
        case startFocus
        case openSection
    }

    enum Destination: String, Codable {
        case launch
        case today
        case score
    }

    var kind: Kind
    var taskID: UUID?
    var destinationRaw: String?
    var createdAt: Date

    init(kind: Kind, taskID: UUID?, destination: Destination? = nil, createdAt: Date) {
        self.kind = kind
        self.taskID = taskID
        destinationRaw = destination?.rawValue
        self.createdAt = createdAt
    }

    var destination: Destination? {
        destinationRaw.flatMap(Destination.init(rawValue:))
    }
}

enum DayDayUpWidgetShared {
    static let appGroupIdentifier = "group.com.daydayup.app"
    static let dashboardFileName = "widget-dashboard.json"
    static let pendingIntentFileName = "widget-pending-intent.json"
    static let defaultGlassTransparency = 0.55

    static var appGroupDirectoryURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    static var dashboardURL: URL? {
        appGroupDirectoryURL?.appendingPathComponent(dashboardFileName, isDirectory: false)
    }

    static var pendingIntentURL: URL? {
        appGroupDirectoryURL?.appendingPathComponent(pendingIntentFileName, isDirectory: false)
    }

    static func loadDashboard() -> WidgetDashboardSnapshot? {
        guard let dashboardURL else { return nil }
        return readDashboard(from: dashboardURL)
    }

    static func readDashboard(from url: URL) -> WidgetDashboardSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return decodeDashboard(data)
    }

    static func decodeDashboard(_ data: Data) -> WidgetDashboardSnapshot? {
        try? decoder.decode(WidgetDashboardSnapshot.self, from: data)
    }

    static func writeDashboard(_ snapshot: WidgetDashboardSnapshot) throws {
        guard let dashboardURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        try writeDashboard(snapshot, to: dashboardURL)
    }

    static func writeDashboard(_ snapshot: WidgetDashboardSnapshot, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: [.atomic])
    }

    static func writePendingIntent(_ intent: WidgetPendingIntent) throws {
        guard let pendingIntentURL else {
            throw CocoaError(.fileNoSuchFile)
        }
        try FileManager.default.createDirectory(
            at: pendingIntentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(intent)
        try data.write(to: pendingIntentURL, options: [.atomic])
    }

    static func consumePendingIntent() -> WidgetPendingIntent? {
        guard let pendingIntentURL,
              let data = try? Data(contentsOf: pendingIntentURL),
              let intent = try? decoder.decode(WidgetPendingIntent.self, from: data) else {
            return nil
        }
        try? FileManager.default.removeItem(at: pendingIntentURL)
        return intent
    }

    static func countdownText(
        deadline: Date,
        completedAt: Date?,
        now: Date = .now,
        compact: Bool
    ) -> String {
        if completedAt != nil {
            return "已完成"
        }

        let isOverdue = now > deadline
        let interval = abs(deadline.timeIntervalSince(now))
        let text = durationText(seconds: interval, compact: compact)
        return isOverdue ? "逾期 \(text)" : text
    }

    static func deadlineText(_ deadline: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: deadline)
    }

    static func percentText(_ value: Double) -> String {
        "\(Int((min(max(value, 0), 1) * 100).rounded()))%"
    }

    static func clampedGlassTransparency(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    static func nextRefreshDate(
        for snapshot: WidgetDashboardSnapshot?,
        mode: WidgetTimelineMode,
        now: Date = .now
    ) -> Date {
        switch mode {
        case .nextTask:
            return refreshDate(
                now: now,
                fallbackMinutes: 15,
                shouldRefreshEachMinute: snapshot?.activeFocus != nil || snapshot?.task.map { $0.completedAt == nil } == true
            )
        case .todayBasket:
            return refreshDate(
                now: now,
                fallbackMinutes: 15,
                shouldRefreshEachMinute: snapshot?.activeFocus != nil || snapshot?.today?.queue.isEmpty == false
            )
        case .rhythmGauge:
            return now.addingTimeInterval(30 * 60)
        }
    }

    private static func durationText(seconds: TimeInterval, compact: Bool) -> String {
        let totalSeconds = max(0, Int(seconds.rounded(.down)))
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if compact {
            return String(format: "%02d 天 %02d:%02d", days, hours, minutes)
        }
        return String(format: "%02d 天 %02d:%02d:%02d", days, hours, minutes, seconds)
    }

    private static func refreshDate(
        now: Date,
        fallbackMinutes: Int,
        shouldRefreshEachMinute: Bool
    ) -> Date {
        let fallback = now.addingTimeInterval(TimeInterval(fallbackMinutes * 60))
        guard shouldRefreshEachMinute else { return fallback }

        let nextMinute = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(second: 1),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(60)
        return min(nextMinute, fallback)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
