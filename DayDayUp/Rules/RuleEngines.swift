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

        unlock(.cleanWeek, when: hasCleanCurrentWeek(tasks: tasks, now: now))
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

    private static func hasCleanCurrentWeek(tasks: [LearningTask], now: Date, calendar: Calendar = .current) -> Bool {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return false }
        let weekTasks = tasks.filter { task in
            week.contains(task.deadline) || task.completedAt.map(week.contains) == true
        }
        guard !weekTasks.isEmpty else { return false }
        return !weekTasks.contains { task in
            if let completedAt = task.completedAt {
                return completedAt > task.deadline
            }
            return task.deadline < now
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
            : Double(delayedTasks.reduce(0) { $0 + $1.delayedDays }) / Double(delayedTasks.count)

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
