import Foundation

enum AchievementRuleEngine {
    static func newlyUnlockedKinds(
        tasks: [LearningTask],
        sessions: [LearningSession],
        events: [TaskEvent],
        existingKindRawValues: Set<String>,
        now: Date = .now
    ) -> [AchievementKind] {
        var unlocked = existingKindRawValues
        var result: [AchievementKind] = []

        func unlock(_ kind: AchievementKind, when condition: Bool) {
            guard condition, !unlocked.contains(kind.rawValue) else { return }
            unlocked.insert(kind.rawValue)
            result.append(kind)
        }

        let completedTasks = tasks.filter { $0.completedAt != nil && $0.progress >= 1 }
        unlock(.firstTaskCompleted, when: !completedTasks.isEmpty)
        unlock(.firstOnTimeClosure, when: completedTasks.contains { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt <= task.deadline
        })
        unlock(.firstEarlyClosure, when: completedTasks.contains { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt < task.deadline
        })
        unlock(.firstRecoveredClosure, when: completedTasks.contains { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt > task.deadline
        })

        let focusStreak = longestConsecutiveDayStreak(from: sessions.map(\.startedAt))
        unlock(.focusStreak3, when: focusStreak >= 3)
        unlock(.focusStreak7, when: focusStreak >= 7)
        unlock(.focusStreak14, when: focusStreak >= 14)

        let reviewStreak = longestConsecutiveDayStreak(from: events.filter { $0.type == .reviewed }.map(\.occurredAt))
        unlock(.reviewStreak3, when: reviewStreak >= 3)

        unlock(.cleanWeek, when: hasCleanCompletedWeek(tasks: tasks, now: now))
        unlock(.monthlyClosureRate, when: currentMonthClosureRateReached(tasks: tasks, now: now))

        let focusMinutes = sessions.reduce(0) { $0 + $1.durationMinutes }
        unlock(.totalFocusOneHour, when: focusMinutes >= 60)
        unlock(.totalFocusTenHours, when: focusMinutes >= 600)

        return result
    }

    static func relatedTaskID(for kind: AchievementKind, preferredTask: LearningTask?, tasks: [LearningTask]) -> UUID? {
        switch kind {
        case .firstTaskCompleted:
            return preferredTask?.completedAt == nil ? firstCompletedTask(in: tasks)?.id : preferredTask?.id
        case .firstOnTimeClosure:
            return matchingTask(preferredTask, in: tasks) { task in
                guard let completedAt = task.completedAt else { return false }
                return task.progress >= 1 && completedAt <= task.deadline
            }?.id
        case .firstEarlyClosure:
            return matchingTask(preferredTask, in: tasks) { task in
                guard let completedAt = task.completedAt else { return false }
                return task.progress >= 1 && completedAt < task.deadline
            }?.id
        case .firstRecoveredClosure:
            return matchingTask(preferredTask, in: tasks) { task in
                guard let completedAt = task.completedAt else { return false }
                return task.progress >= 1 && completedAt > task.deadline
            }?.id
        case .focusStreak3, .focusStreak7, .focusStreak14, .reviewStreak3, .cleanWeek, .monthlyClosureRate, .totalFocusOneHour, .totalFocusTenHours:
            return nil
        }
    }

    private static func firstCompletedTask(in tasks: [LearningTask]) -> LearningTask? {
        tasks
            .filter { $0.completedAt != nil }
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
            .first
    }

    private static func matchingTask(
        _ preferredTask: LearningTask?,
        in tasks: [LearningTask],
        where predicate: (LearningTask) -> Bool
    ) -> LearningTask? {
        if let preferredTask, predicate(preferredTask) {
            return preferredTask
        }
        return tasks.first(where: predicate)
    }

    private static func longestConsecutiveDayStreak(from dates: [Date], calendar: Calendar = .current) -> Int {
        let days = Array(Set(dates.map { calendar.startOfDay(for: $0) })).sorted()
        guard !days.isEmpty else { return 0 }

        var best = 1
        var current = 1
        for index in 1..<days.count {
            let previous = days[index - 1]
            let day = days[index]
            let distance = calendar.dateComponents([.day], from: previous, to: day).day ?? 0
            if distance == 1 {
                current += 1
            } else if distance > 1 {
                current = 1
            }
            best = max(best, current)
        }
        return best
    }

    private static func hasCleanCompletedWeek(tasks: [LearningTask], now: Date, calendar: Calendar = .current) -> Bool {
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now),
              let completedWeek = calendar.dateInterval(of: .weekOfYear, for: currentWeek.start.addingTimeInterval(-1)) else {
            return false
        }
        let weekTasks = tasks.filter { completedWeek.contains($0.deadline) }
        guard !weekTasks.isEmpty else { return false }
        return weekTasks.allSatisfy { task in
            guard let completedAt = task.completedAt, task.progress >= 1 else { return false }
            return completedAt <= task.deadline
        }
    }

    private static func currentMonthClosureRateReached(tasks: [LearningTask], now: Date, calendar: Calendar = .current) -> Bool {
        guard let month = calendar.dateInterval(of: .month, for: now) else { return false }
        let monthTasks = tasks.filter { month.contains($0.deadline) }
        guard monthTasks.count >= 3 else { return false }
        let closed = monthTasks.filter(\.isClosedLoop)
        return Double(closed.count) / Double(monthTasks.count) >= 0.8
    }
}

enum TaskCollectionStatusPolicy {
    static func overdueOpenCount(tasks: [LearningTask], now: Date = .now) -> Int {
        tasks.filter { $0.status(now: now) == .overdue }.count
    }
}

enum MetricCalculator {
    static func calculate(tasks: [LearningTask], sessions: [LearningSession], now: Date = .now) -> AppMetrics {
        let taskIDs = Set(tasks.map(\.id))
        let validSessions = sessions.filter { taskIDs.contains($0.taskID) }

        guard !tasks.isEmpty else {
            return AppMetrics(
                plannedTaskCount: 0,
                completionRate: 0,
                onTimeRate: 0,
                earlyRate: 0,
                delayedRate: 0,
                recoveredRate: 0,
                closedLoopRate: 0,
                stableFocusRate: 0,
                reviewRate: 0,
                totalFocusMinutes: 0,
                todayFocusMinutes: 0,
                weeklyFocusMinutes: 0,
                directionFocusMinutes: [:],
                unfinishedCount: 0,
                averageDelayDays: 0,
                score: 0
            )
        }

        let calendar = Calendar.current
        let total = tasks.count
        let completed = tasks.filter { $0.completedAt != nil }
        let onTime = completed.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt <= task.deadline
        }
        let early = completed.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt < task.deadline
        }
        let recovered = completed.filter { $0.status(now: now) == .recovered }
        let overdue = tasks.filter { $0.status(now: now) == .overdue }
        let closed = tasks.filter(\.isClosedLoop)
        let reviewed = completed.filter { !$0.reviewNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let focusMinutes = validSessions.reduce(0) { $0 + $1.durationMinutes }
        let today = calendar.startOfDay(for: now)
        let week = calendar.dateInterval(of: .weekOfYear, for: now)
        let todayFocusMinutes = validSessions
            .filter { calendar.startOfDay(for: $0.startedAt) == today }
            .reduce(0) { $0 + $1.durationMinutes }
        let weeklyFocusMinutes = validSessions
            .filter { week?.contains($0.startedAt) == true }
            .reduce(0) { $0 + $1.durationMinutes }
        let taskDirections = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.direction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "未填写方向" : $0.direction) })
        let directionFocusMinutes = validSessions.reduce(into: [String: Int]()) { result, session in
            let direction = taskDirections[session.taskID] ?? "未关联任务"
            result[direction, default: 0] += session.durationMinutes
        }
        let delayedTasks = tasks.filter { task in
            if let completedAt = task.completedAt {
                return completedAt > task.deadline
            }
            return task.deadline < now
        }
        let averageDelayDays = delayedTasks.isEmpty
            ? 0
            : Double(delayedTasks.reduce(0) { $0 + $1.delayedDays(now: now) }) / Double(delayedTasks.count)

        let completionRate = Double(completed.count) / Double(total)
        let onTimeRate = Double(onTime.count) / Double(total)
        let earlyRate = Double(early.count) / Double(total)
        let delayedRate = Double(overdue.count + recovered.count) / Double(total)
        let recoveredRate = Double(recovered.count) / Double(max(overdue.count + recovered.count, 1))
        let closedLoopRate = Double(closed.count) / Double(total)
        let reviewRate = Double(reviewed.count) / Double(max(completed.count, 1))
        let stableFocusRate = min(Double(focusMinutes) / Double(max(tasks.reduce(0) { $0 + $1.estimatedMinutes }, 1)), 1)
        let delayControl = max(0, 1 - delayedRate)

        let score = Int(
            completionRate * 30
            + onTimeRate * 25
            + earlyRate * 10
            + delayControl * 15
            + stableFocusRate * 15
            + reviewRate * 5
        )

        return AppMetrics(
            plannedTaskCount: total,
            completionRate: completionRate,
            onTimeRate: onTimeRate,
            earlyRate: earlyRate,
            delayedRate: delayedRate,
            recoveredRate: recoveredRate,
            closedLoopRate: closedLoopRate,
            stableFocusRate: stableFocusRate,
            reviewRate: reviewRate,
            totalFocusMinutes: focusMinutes,
            todayFocusMinutes: todayFocusMinutes,
            weeklyFocusMinutes: weeklyFocusMinutes,
            directionFocusMinutes: directionFocusMinutes,
            unfinishedCount: tasks.filter { !$0.isClosedLoop }.count,
            averageDelayDays: averageDelayDays,
            score: max(0, min(100, score))
        )
    }
}

enum TaskCalendarPolicy {
    static func status(
        for date: Date,
        tasks: [LearningTask],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TaskStatus? {
        let day = calendar.startOfDay(for: date)
        if tasks.contains(where: { $0.status(now: now) == .overdue && calendar.startOfDay(for: $0.deadline) == day }) {
            return .overdue
        }
        if tasks.contains(where: { task in
            guard task.status(now: now) == .recovered else { return false }
            return calendar.startOfDay(for: task.deadline) == day
        }) {
            return .recovered
        }
        if tasks.contains(where: { task in
            guard let completedAt = task.completedAt else { return false }
            return calendar.startOfDay(for: completedAt) == day
        }) {
            return .completed
        }
        return nil
    }
}

enum DeadlineEventRecorder {
    static func missingEvents(
        tasks: [LearningTask],
        events: [TaskEvent],
        now: Date = .now
    ) -> [TaskEvent] {
        let missedTaskIDs = Set(events.filter { $0.type == .missed }.map(\.taskID))
        return tasks.compactMap { task in
            guard task.completedAt == nil,
                  task.deadline < now,
                  !missedTaskIDs.contains(task.id) else {
                return nil
            }
            return TaskEvent(
                taskID: task.id,
                type: .missed,
                occurredAt: task.deadline,
                note: "未按时完成：\(task.deadline.formattedDateTime()) 前未闭环。"
            )
        }
    }
}

enum MissedDeadlinePolicy {
    static func missingEvents(
        tasks: [LearningTask],
        events: [TaskEvent],
        now: Date = .now
    ) -> [TaskEvent] {
        DeadlineEventRecorder.missingEvents(tasks: tasks, events: events, now: now)
    }
}

enum ReminderRuntimePolicy {
    static func dueReminders(
        tasks: [LearningTask],
        events: [TaskEvent],
        settings: AppSettings,
        notificationState: ReminderAuthorizationState,
        now: Date = .now
    ) -> [TaskEvent] {
        let existingReminderKeys = Set(
            events
                .filter { $0.type == .leadReminder || $0.type == .overdueReminder }
                .map { reminderKey(taskID: $0.taskID, type: $0.type) }
        )

        return tasks.flatMap { task -> [TaskEvent] in
            guard task.completedAt == nil else { return [] }

            var reminders: [TaskEvent] = []
            let leadDate = task.deadline.addingTimeInterval(-Double(max(1, settings.reminderLeadMinutes)) * 60)
            if leadDate <= now,
               task.deadline > now,
               !existingReminderKeys.contains(reminderKey(taskID: task.id, type: .leadReminder)) {
                reminders.append(
                    TaskEvent(
                        taskID: task.id,
                        type: .leadReminder,
                        occurredAt: leadDate,
                        note: reminderNote(
                            task: task,
                            notificationState: notificationState,
                            message: "\(task.name) 截止时间：\(task.deadline.formattedDateTime())，还差一颗松果，先收好再开饭。"
                        )
                    )
                )
            }

            let overdueDate = task.deadline.addingTimeInterval(5 * 60)
            if settings.overdueReminderEnabled,
               overdueDate <= now,
               !existingReminderKeys.contains(reminderKey(taskID: task.id, type: .overdueReminder)) {
                reminders.append(
                    TaskEvent(
                        taskID: task.id,
                        type: .overdueReminder,
                        occurredAt: overdueDate,
                        note: reminderNote(
                            task: task,
                            notificationState: notificationState,
                            message: "\(task.name) 已经逾期，请记录卡住原因，再补上闭环。"
                        )
                    )
                )
            }

            return reminders
        }
    }

    private static func reminderKey(taskID: UUID, type: TaskEventType) -> String {
        "\(taskID.uuidString)-\(type.rawValue)"
    }

    private static func reminderNote(
        task: LearningTask,
        notificationState: ReminderAuthorizationState,
        message: String
    ) -> String {
        switch notificationState {
        case .authorized, .provisional, .ephemeral:
            return message
        case .unknown, .notDetermined, .denied:
            return "系统通知不可用/未授权（\(notificationState.title)），App 内提醒：\(message)"
        }
    }
}
