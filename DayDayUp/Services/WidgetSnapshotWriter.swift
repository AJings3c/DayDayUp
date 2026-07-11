import Foundation
import OSLog

#if canImport(WidgetKit)
import WidgetKit
#endif

enum WidgetSnapshotWriter {
    static func write(
        tasks: [LearningTask],
        sessions: [LearningSession],
        focusState: ActiveFocusState?,
        glassTransparency: Double = DayDayUpWidgetShared.defaultGlassTransparency,
        now: Date = .now
    ) {
        let snapshot = makeSnapshot(
            tasks: tasks,
            sessions: sessions,
            focusState: focusState,
            glassTransparency: glassTransparency,
            now: now
        )
        do {
            try DayDayUpWidgetShared.writeDashboard(snapshot)
            reloadWidgetTimelines()
        } catch {
            Logger(subsystem: "com.daydayup.app", category: "Widgets")
                .error("Widget snapshot write failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func makeSnapshot(
        tasks: [LearningTask],
        sessions: [LearningSession],
        focusState: ActiveFocusState?,
        glassTransparency: Double = DayDayUpWidgetShared.defaultGlassTransparency,
        now: Date = .now
    ) -> WidgetDashboardSnapshot {
        let todayFocusMinutes = todayFocusMinutes(from: sessions, now: now)
        return WidgetDashboardSnapshot(
            updatedAt: now,
            task: selectedTask(from: tasks, now: now).map { taskSnapshot(for: $0, now: now) },
            activeFocus: focusSnapshot(for: focusState),
            todayFocusMinutes: todayFocusMinutes,
            overdueCount: tasks.filter { $0.status(now: now) == .overdue }.count,
            today: todaySnapshot(from: tasks, focusMinutes: todayFocusMinutes, now: now),
            rhythm: rhythmSnapshot(from: tasks, sessions: sessions, now: now),
            glassTransparency: glassTransparency
        )
    }

    private static func selectedTask(from tasks: [LearningTask], now: Date) -> LearningTask? {
        let incompleteTasks = tasks
            .filter { $0.completedAt == nil }
            .sorted { lhs, rhs in
                let lhsRank = lhs.status(now: now).sortRank
                let rhsRank = rhs.status(now: now).sortRank
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }
                return lhs.deadline < rhs.deadline
            }

        if let nearestIncomplete = incompleteTasks.first {
            return nearestIncomplete
        }

        return tasks
            .filter { $0.completedAt != nil }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .first
    }

    private static func taskSnapshot(for task: LearningTask, now: Date) -> WidgetTaskSnapshot {
        WidgetTaskSnapshot(
            id: task.id,
            name: task.name,
            deadline: task.deadline,
            completedAt: task.completedAt,
            progress: min(max(task.progress, 0), 1),
            statusRaw: task.status(now: now).rawValue,
            completionCriteria: task.completionCriteria
        )
    }

    private static func todaySnapshot(
        from tasks: [LearningTask],
        focusMinutes: Int,
        now: Date
    ) -> WidgetTodaySnapshot {
        let calendar = Calendar.current
        let todayTasks = tasks.filter { isRelevantToday($0, now: now, calendar: calendar) }
        let incompleteTasks = sortedForWidgetExecution(
            todayTasks.filter { $0.completedAt == nil },
            now: now
        )
        let completedToday = todayTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return calendar.isDate(completedAt, inSameDayAs: now)
        }
        let queue = incompleteTasks
            .prefix(3)
            .map { taskSnapshot(for: $0, now: now) }

        return WidgetTodaySnapshot(
            focusMinutes: focusMinutes,
            incompleteCount: incompleteTasks.count,
            completedCount: completedToday.count,
            overdueCount: todayTasks.filter { $0.status(now: now) == .overdue }.count,
            queue: queue,
            recommendedTaskID: queue.first?.id
        )
    }

    private static func rhythmSnapshot(
        from tasks: [LearningTask],
        sessions: [LearningSession],
        now: Date
    ) -> WidgetRhythmSnapshot {
        let metrics = MetricCalculator.calculate(tasks: tasks, sessions: sessions, now: now)
        let riskTask = sortedForWidgetExecution(
            tasks.filter { $0.completedAt == nil },
            now: now
        ).first

        return WidgetRhythmSnapshot(
            score: metrics.score,
            scoreLabel: metrics.scoreLabel,
            weeklyFocusMinutes: metrics.weeklyFocusMinutes,
            completionRate: metrics.completionRate,
            onTimeRate: metrics.onTimeRate,
            reviewRate: metrics.reviewRate,
            overdueCount: tasks.filter { $0.status(now: now) == .overdue }.count,
            riskTask: riskTask.map { taskSnapshot(for: $0, now: now) },
            hasTasks: metrics.hasTasks
        )
    }

    private static func sortedForWidgetExecution(_ tasks: [LearningTask], now: Date) -> [LearningTask] {
        tasks.sorted { lhs, rhs in
            let lhsRank = lhs.status(now: now).sortRank
            let rhsRank = rhs.status(now: now).sortRank
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return lhs.deadline < rhs.deadline
        }
    }

    private static func isRelevantToday(
        _ task: LearningTask,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        calendar.isDate(task.deadline, inSameDayAs: now)
            || task.startedAt.map { calendar.isDate($0, inSameDayAs: now) } == true
            || task.completedAt.map { calendar.isDate($0, inSameDayAs: now) } == true
            || task.status(now: now) == .overdue
    }

    private static func focusSnapshot(for focusState: ActiveFocusState?) -> WidgetFocusSnapshot? {
        guard let focusState, focusState.isActive else { return nil }
        return WidgetFocusSnapshot(
            taskID: focusState.taskID,
            originalStartedAt: focusState.originalStartedAt,
            currentStartedAt: focusState.currentStartedAt,
            pausedAt: focusState.pausedAt,
            accumulatedSeconds: focusState.accumulatedSeconds
        )
    }

    private static func todayFocusMinutes(from sessions: [LearningSession], now: Date) -> Int {
        let calendar = Calendar.current
        return sessions
            .filter { calendar.isDate($0.startedAt, inSameDayAs: now) }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    private static func reloadWidgetTimelines() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "NextTaskWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "TodayBasketWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "RhythmGaugeWidget")
        #endif
    }
}
