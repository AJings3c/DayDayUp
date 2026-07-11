import Foundation
import OSLog
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
        guard task.completedAt == nil else {
            return (nil, nil)
        }

        let leadDate = task.deadline.addingTimeInterval(-Double(max(1, settings.reminderLeadMinutes)) * 60)
        let overdueDate = task.deadline.addingTimeInterval(5 * 60)

        return (
            lead: task.deadline > now && leadDate > now ? leadDate : nil,
            overdue: settings.overdueReminderEnabled && overdueDate > now ? overdueDate : nil
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
        add(request)
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
        add(request)
    }

    private static func add(_ request: UNNotificationRequest) {
        UNUserNotificationCenter.current().add(request) { error in
            guard let error else { return }
            Logger(subsystem: "com.daydayup.app", category: "Notifications")
                .error("Notification scheduling failed: \(error.localizedDescription, privacy: .public)")
        }
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
