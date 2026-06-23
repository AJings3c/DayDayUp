import Foundation
import SwiftData
import Testing
@testable import DayDayUp

@Suite("DayDayUp MVP Rules")
struct DayDayUpTests {
    private let calendar = Calendar(identifier: .gregorian)

    @Test("task status, closure, and delay rules")
    func taskStatusRules() {
        let now = date(2026, 6, 9, 10, 0)
        let futureDeadline = date(2026, 6, 10, 10, 0)
        let pastDeadline = date(2026, 6, 8, 10, 0)

        let active = LearningTask(name: "Read RAG paper", details: "", direction: "RAG", deadline: futureDeadline)
        #expect(active.status(now: now) == .warning)
        #expect(active.isClosedLoop == false)

        let overdue = LearningTask(name: "Build agent demo", details: "", direction: "Agent", deadline: pastDeadline)
        #expect(overdue.status(now: now) == .overdue)

        let recovered = LearningTask(
            name: "Patch retrieval eval",
            details: "",
            direction: "RAG",
            deadline: pastDeadline,
            completedAt: now,
            progress: 1
        )
        #expect(recovered.status(now: now) == .recovered)
        #expect(recovered.isClosedLoop == true)
        #expect(recovered.delayedDays == 1)
        #expect(TaskStatus.active.title == "待执行")
    }

    @Test("today execution overdue count uses injected now")
    func overdueOpenCountRules() {
        let now = date(2026, 6, 19, 22, 41)
        let overdue = LearningTask(name: "5 分钟 deadline 测试", details: "", direction: "", deadline: date(2026, 6, 19, 22, 40))
        let future = LearningTask(name: "未来任务", details: "", direction: "", deadline: date(2026, 6, 19, 23, 0))
        let completedLate = LearningTask(
            name: "已补完成",
            details: "",
            direction: "",
            deadline: date(2026, 6, 19, 22, 30),
            completedAt: now,
            progress: 1
        )

        #expect(TaskCollectionStatusPolicy.overdueOpenCount(tasks: [overdue, future, completedLate], now: now) == 1)
        #expect(overdue.status(now: now) == .overdue)
    }

    @Test("task deadline policy prevents fresh tasks from starting overdue")
    func taskDeadlinePolicyRules() {
        let now = date(2026, 6, 13, 10, 0)
        let yesterday = date(2026, 6, 12, 23, 59)
        let thirtySecondsLater = date(2026, 6, 13, 10, 0, 30)
        let preciseFuture = date(2026, 6, 13, 22, 40, 17)
        let overdueTask = LearningTask(
            name: "任务名称",
            details: "",
            direction: "",
            plannedAt: date(2026, 6, 10, 9, 0),
            deadline: yesterday
        )
        let normalized = TaskDeadlinePolicy.normalizedDeadline(yesterday, for: nil, now: now)
        let preservedOverdue = TaskDeadlinePolicy.normalizedDeadline(yesterday, for: overdueTask, now: now)
        let defaultDeadline = TaskDeadlinePolicy.defaultDeadline(now: now)

        #expect(normalized > now)
        #expect(normalized == TaskDeadlinePolicy.minimumDeadline(for: nil, now: now))
        #expect(normalized.timeIntervalSince(now) == TaskDeadlinePolicy.minimumLeadSeconds)
        #expect(preservedOverdue == yesterday)
        #expect(defaultDeadline > now)
        #expect(calendar.component(.hour, from: defaultDeadline) == 23)
        #expect(calendar.component(.minute, from: defaultDeadline) == 59)
        #expect(TaskDeadlinePolicy.normalizedDeadline(thirtySecondsLater, for: nil, now: now) == thirtySecondsLater)
        #expect(TaskDeadlinePolicy.normalizedDeadline(preciseFuture, for: nil, now: now) == preciseFuture)
        #expect(calendar.component(.second, from: preciseFuture) == 17)

        let fiveMinutesLater = DeadlineShortcutPolicy.relative(minutes: 5, now: preciseFuture)
        #expect(fiveMinutesLater.timeIntervalSince(preciseFuture) == 300)
        #expect(calendar.component(.second, from: fiveMinutesLater) == 17)
        #expect(TaskDeadlinePolicy.normalizedDeadline(fiveMinutesLater, for: nil, now: preciseFuture) == fiveMinutesLater)
    }

    @Test("missed deadline events are inserted once for overdue open tasks")
    func missedDeadlineEventRules() {
        let now = date(2026, 6, 19, 0, 20)
        let deadline = date(2026, 6, 18, 22, 40)
        let overdue = LearningTask(
            name: "学习英语",
            details: "",
            direction: "英语学习",
            plannedAt: date(2026, 6, 18, 20, 0),
            deadline: deadline
        )
        let future = LearningTask(
            name: "未来任务",
            details: "",
            direction: "",
            deadline: date(2026, 6, 19, 22, 40)
        )

        let missed = DeadlineEventRecorder.missingEvents(tasks: [overdue, future], events: [], now: now)

        #expect(missed.count == 1)
        #expect(missed.first?.taskID == overdue.id)
        #expect(missed.first?.type == .missed)
        #expect(missed.first?.occurredAt == deadline)

        let repeated = DeadlineEventRecorder.missingEvents(tasks: [overdue], events: missed, now: now)
        #expect(repeated.isEmpty)
    }

    @Test("runtime reminders are inserted once and record notification fallback")
    func runtimeReminderRules() {
        let deadline = date(2026, 6, 22, 2, 0)
        let task = LearningTask(
            name: "背单词",
            details: "",
            direction: "英语学习",
            deadline: deadline
        )
        let settings = AppSettings(reminderLeadMinutes: 30, overdueReminderEnabled: true)
        let leadNow = date(2026, 6, 22, 1, 30, 1)

        let lead = ReminderRuntimePolicy.dueReminders(
            tasks: [task],
            events: [],
            settings: settings,
            notificationState: .denied,
            now: leadNow
        )

        #expect(lead.count == 1)
        #expect(lead.first?.type == .leadReminder)
        #expect(lead.first?.occurredAt == date(2026, 6, 22, 1, 30))
        #expect(lead.first?.note.contains("系统通知不可用/未授权") == true)

        let repeatedLead = ReminderRuntimePolicy.dueReminders(
            tasks: [task],
            events: lead,
            settings: settings,
            notificationState: .denied,
            now: leadNow
        )
        #expect(repeatedLead.isEmpty)

        let overdue = ReminderRuntimePolicy.dueReminders(
            tasks: [task],
            events: lead,
            settings: settings,
            notificationState: .denied,
            now: date(2026, 6, 22, 2, 6)
        )

        #expect(overdue.count == 1)
        #expect(overdue.first?.type == .overdueReminder)
        #expect(overdue.first?.occurredAt == date(2026, 6, 22, 2, 5))
        #expect(ReminderRuntimePolicy.dueReminders(tasks: [task], events: lead + overdue, settings: settings, notificationState: .denied, now: date(2026, 6, 22, 2, 6)).isEmpty)
    }

    @Test("execution helpers use injected now for overdue state")
    func injectedNowExecutionHelperRules() {
        let now = date(2026, 6, 22, 2, 1)
        let overdue = LearningTask(name: "背单词", details: "", direction: "", deadline: date(2026, 6, 22, 2, 0))
        let future = LearningTask(name: "未来任务", details: "", direction: "", deadline: date(2026, 6, 22, 3, 0))

        #expect(overdue.status(now: now) == .overdue)
        #expect([future, overdue].nearestIncomplete(now: now)?.id == overdue.id)
        #expect([future, overdue].sortedForExecution(now: now).map(\.id) == [overdue.id, future.id])
        #expect(overdue.isRelevantToday(now: now))
    }

    @Test("missed event remains separate from recovered completion")
    func missedDeadlineRecoveredRules() {
        let now = date(2026, 6, 19, 0, 20)
        let deadline = date(2026, 6, 18, 22, 40)
        let recovered = LearningTask(
            name: "补完成任务",
            details: "",
            direction: "",
            plannedAt: date(2026, 6, 18, 20, 0),
            deadline: deadline,
            completedAt: now,
            progress: 1
        )
        let missed = TaskEvent(taskID: recovered.id, type: .missed, occurredAt: deadline, note: "未按时完成")
        let recovery = TaskEvent(taskID: recovered.id, type: .recovered, occurredAt: now, note: "逾期后补完成")

        let generated = MissedDeadlinePolicy.missingEvents(tasks: [recovered], events: [missed, recovery], now: now)

        #expect(generated.isEmpty)
        #expect([missed, recovery].map(\.type) == [.missed, .recovered])
    }

    @Test("unknown notification authorization does not count as completed request")
    func notificationAuthorizationRequestStateRules() {
        #expect(ReminderAuthorizationPolicy.didCompleteAuthorizationRequest(state: .unknown) == false)
        #expect(ReminderAuthorizationPolicy.didCompleteAuthorizationRequest(state: .notDetermined))
        #expect(ReminderAuthorizationPolicy.didCompleteAuthorizationRequest(state: .denied))
        #expect(ReminderAuthorizationPolicy.didCompleteAuthorizationRequest(state: .authorized))
    }

    @Test("journey timeline ranks deadline and missed before later recovery events")
    func journeyTimelineSortRankRules() {
        let orderedTypes: [TaskEventType] = [
            .planned,
            .started,
            .deadline,
            .missed,
            .leadReminder,
            .overdueReminder,
            .blocked,
            .progress,
            .recovered,
            .completed,
            .reviewed
        ]

        #expect(orderedTypes.map(\.timelineSortRank) == Array(0..<orderedTypes.count))
        #expect(TaskEventType.deadline.timelineSortRank < TaskEventType.missed.timelineSortRank)
        #expect(TaskEventType.missed.timelineSortRank < TaskEventType.leadReminder.timelineSortRank)
        #expect(TaskEventType.leadReminder.timelineSortRank < TaskEventType.overdueReminder.timelineSortRank)
        #expect(TaskEventType.missed.timelineSortRank < TaskEventType.blocked.timelineSortRank)
        #expect(TaskEventType.missed.timelineSortRank < TaskEventType.recovered.timelineSortRank)
    }

    @Test("journey timeline sorts by occurred time before same-second rank")
    func journeyTimelineChronologicalRules() {
        let taskID = UUID()
        let progress = TaskEvent(taskID: taskID, type: .progress, occurredAt: date(2026, 6, 19, 1, 27), note: "先更新进度")
        let deadline = TaskEvent(taskID: taskID, type: .deadline, occurredAt: date(2026, 6, 19, 1, 30), note: "截止")
        let missed = TaskEvent(taskID: taskID, type: .missed, occurredAt: date(2026, 6, 19, 1, 30), note: "未完成")
        let recovered = TaskEvent(taskID: taskID, type: .recovered, occurredAt: date(2026, 6, 19, 1, 33), note: "补完成")

        let sorted = TaskEventTimelinePolicy.sorted([missed, recovered, deadline, progress])

        #expect(sorted.map(\.type) == [.progress, .deadline, .missed, .recovered])
    }

    @Test("one-shot notification scheduling preserves seconds")
    func notificationDateComponentsPreserveSeconds() {
        let deadline = date(2026, 6, 18, 22, 40, 17)
        let components = ReminderScheduler.notificationDateComponents(for: deadline, calendar: calendar)

        #expect(components.hour == 22)
        #expect(components.minute == 40)
        #expect(components.second == 17)
    }

    @Test("task repairs impossible deadline before planned date")
    func taskImpossibleTimelineRepairRules() {
        let now = date(2026, 6, 13, 10, 0)
        let task = LearningTask(
            name: "任务名称",
            details: "",
            direction: "",
            plannedAt: now,
            deadline: date(2026, 6, 11, 23, 59)
        )

        let repaired = task.repairImpossibleTimeline(now: now)

        #expect(repaired)
        #expect(task.deadline >= task.plannedAt)
        #expect(task.deadline > now)
    }

    @Test("metric calculator exposes score inputs")
    func metricCalculatorRules() {
        let now = date(2026, 6, 9, 12, 0)
        let onTime = LearningTask(
            name: "Finish prompt eval",
            details: "",
            direction: "Eval",
            deadline: date(2026, 6, 9, 18, 0),
            completedAt: date(2026, 6, 9, 11, 0),
            estimatedMinutes: 60,
            progress: 1,
            reviewNote: "Worked"
        )
        let recovered = LearningTask(
            name: "Repair RAG pipeline",
            details: "",
            direction: "RAG",
            deadline: date(2026, 6, 8, 18, 0),
            completedAt: date(2026, 6, 9, 10, 0),
            estimatedMinutes: 60,
            progress: 1
        )
        let open = LearningTask(
            name: "Read MCP docs",
            details: "",
            direction: "Agent",
            deadline: date(2026, 6, 12, 18, 0),
            estimatedMinutes: 60,
            progress: 0.2
        )
        let session = LearningSession(
            taskID: onTime.id,
            startedAt: date(2026, 6, 9, 9, 0),
            endedAt: date(2026, 6, 9, 10, 0),
            note: "Focus",
            activeSeconds: 3_600
        )

        let metrics = MetricCalculator.calculate(tasks: [onTime, recovered, open], sessions: [session], now: now)
        #expect(metrics.plannedTaskCount == 3)
        #expect(abs(metrics.completionRate - 2.0 / 3.0) < 0.001)
        #expect(abs(metrics.onTimeRate - 1.0 / 3.0) < 0.001)
        #expect(metrics.todayFocusMinutes == 60)
        #expect(metrics.weeklyFocusMinutes == 60)
        #expect(metrics.unfinishedCount == 1)
        #expect(metrics.directionFocusMinutes["Eval"] == 60)
    }

    @Test("active focus state pause, resume, and clear")
    func activeFocusStateRules() {
        let taskID = UUID()
        let startedAt = date(2026, 6, 9, 9, 0)
        let pausedAt = date(2026, 6, 9, 9, 15)
        let resumedAt = date(2026, 6, 9, 9, 20)
        let checkedAt = date(2026, 6, 9, 9, 30)
        let focusState = ActiveFocusState()

        focusState.start(taskID: taskID, at: startedAt)
        #expect(focusState.isActive)
        #expect(focusState.isPaused == false)

        focusState.pause(at: pausedAt)
        #expect(focusState.isPaused)
        #expect(focusState.currentStartedAt == nil)
        #expect(Int(focusState.accumulatedSeconds) == 900)

        focusState.resume(at: resumedAt)
        #expect(focusState.isPaused == false)
        #expect(focusState.currentStartedAt == resumedAt)
        #expect(Int(focusState.activeSeconds(at: checkedAt)) == 1_500)

        focusState.clear()
        #expect(focusState.isActive == false)
        #expect(focusState.taskID == nil)
        #expect(focusState.draftNote.isEmpty)
    }

    @Test("calendar status priority")
    func calendarPriorityRules() {
        let now = date(2026, 6, 9, 12, 0)
        let deadline = date(2026, 6, 8, 18, 0)
        let recovered = LearningTask(
            name: "Recovered task",
            details: "",
            direction: "RAG",
            deadline: deadline,
            completedAt: now,
            progress: 1
        )
        let overdue = LearningTask(name: "Overdue task", details: "", direction: "Agent", deadline: deadline)

        #expect(TaskCalendarPolicy.status(for: deadline, tasks: [recovered], now: now, calendar: calendar) == .recovered)
        #expect(TaskCalendarPolicy.status(for: deadline, tasks: [recovered, overdue], now: now, calendar: calendar) == .overdue)
        #expect(TaskCalendarPolicy.status(for: now, tasks: [recovered], now: now, calendar: calendar) == .completed)
    }

    @Test("achievement unlocks are deduplicated")
    func achievementUnlockDedupes() {
        let completed = LearningTask(
            name: "First task",
            details: "",
            direction: "Agent",
            deadline: date(2026, 6, 9, 18, 0),
            completedAt: date(2026, 6, 9, 12, 0),
            progress: 1
        )

        let unlocked = AchievementRuleEngine.newlyUnlockedKinds(
            tasks: [completed],
            sessions: [],
            events: [],
            existingKindRawValues: []
        )
        #expect(unlocked.contains(.firstTaskCompleted))
        #expect(unlocked.contains(.firstOnTimeClosure))

        let repeated = AchievementRuleEngine.newlyUnlockedKinds(
            tasks: [completed],
            sessions: [],
            events: [],
            existingKindRawValues: Set(unlocked.map(\.rawValue))
        )
        #expect(repeated.isEmpty)
    }

    @Test("clean week only unlocks for a completed natural week")
    func cleanWeekAchievementRules() {
        let currentWeekNow = date(2026, 6, 19, 10, 0)
        let currentWeekTask = LearningTask(
            name: "本周按时任务",
            details: "",
            direction: "",
            deadline: date(2026, 6, 18, 18, 0),
            completedAt: date(2026, 6, 18, 17, 0),
            progress: 1
        )
        let currentWeekUnlocked = AchievementRuleEngine.newlyUnlockedKinds(
            tasks: [currentWeekTask],
            sessions: [],
            events: [],
            existingKindRawValues: [],
            now: currentWeekNow
        )
        #expect(!currentWeekUnlocked.contains(.cleanWeek))

        let afterWeekNow = date(2026, 6, 22, 10, 0)
        let previousWeekOnTime = LearningTask(
            name: "上周按时任务",
            details: "",
            direction: "",
            deadline: date(2026, 6, 18, 18, 0),
            completedAt: date(2026, 6, 18, 17, 0),
            progress: 1
        )
        let previousWeekUnlocked = AchievementRuleEngine.newlyUnlockedKinds(
            tasks: [previousWeekOnTime],
            sessions: [],
            events: [],
            existingKindRawValues: [],
            now: afterWeekNow
        )
        #expect(previousWeekUnlocked.contains(.cleanWeek))

        let recovered = LearningTask(
            name: "上周补完成任务",
            details: "",
            direction: "",
            deadline: date(2026, 6, 18, 18, 0),
            completedAt: date(2026, 6, 19, 9, 0),
            progress: 1
        )
        let open = LearningTask(
            name: "上周未完成任务",
            details: "",
            direction: "",
            deadline: date(2026, 6, 18, 19, 0)
        )
        #expect(!AchievementRuleEngine.newlyUnlockedKinds(tasks: [recovered], sessions: [], events: [], existingKindRawValues: [], now: afterWeekNow).contains(.cleanWeek))
        #expect(!AchievementRuleEngine.newlyUnlockedKinds(tasks: [open], sessions: [], events: [], existingKindRawValues: [], now: afterWeekNow).contains(.cleanWeek))
    }

    @Test("reminder request identifiers are stable")
    func reminderIdentifiers() {
        let id = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        #expect(ReminderScheduler.leadReminderID(for: id) == "daydayup.task.11111111-2222-3333-4444-555555555555.lead")
        #expect(ReminderScheduler.overdueReminderID(for: id) == "daydayup.task.11111111-2222-3333-4444-555555555555.overdue")
        #expect(ReminderScheduler.requestIdentifiers(for: id).count == 2)
    }

    @Test("task reminders are only scheduled while deadline is still future")
    func taskReminderDateRules() {
        let now = date(2026, 6, 18, 22, 40, 30)
        let settings = AppSettings(reminderLeadMinutes: 10, overdueReminderEnabled: true)
        let future = LearningTask(
            name: "未来任务",
            details: "",
            direction: "",
            deadline: date(2026, 6, 18, 23, 0, 17)
        )
        let justOverdue = LearningTask(
            name: "刚逾期任务",
            details: "",
            direction: "",
            deadline: date(2026, 6, 18, 22, 40, 0)
        )

        let futureDates = ReminderScheduler.taskReminderDates(for: future, settings: settings, now: now)
        let overdueDates = ReminderScheduler.taskReminderDates(for: justOverdue, settings: settings, now: now)

        #expect(futureDates.lead == date(2026, 6, 18, 22, 50, 17))
        #expect(futureDates.overdue == date(2026, 6, 18, 23, 5, 17))
        #expect(overdueDates.lead == nil)
        #expect(overdueDates.overdue == nil)
    }

    @Test("backup export, preview, and import restore records")
    func backupRoundTripRestoresRecords() throws {
        let taskID = UUID(uuidString: "22222222-3333-4444-5555-666666666666")!
        let sessionID = UUID(uuidString: "33333333-4444-5555-6666-777777777777")!
        let eventID = UUID(uuidString: "44444444-5555-6666-7777-888888888888")!
        let achievementID = UUID(uuidString: "55555555-6666-7777-8888-999999999999")!
        let task = LearningTask(
            id: taskID,
            name: "Ship MVP",
            details: "Finish DayDayUp",
            direction: "Product",
            plannedAt: date(2026, 6, 8, 9, 0),
            startedAt: date(2026, 6, 8, 10, 0),
            deadline: date(2026, 6, 9, 18, 0),
            completedAt: date(2026, 6, 9, 12, 0),
            estimatedMinutes: 90,
            progress: 1,
            completionCriteria: "Build and tests pass",
            resourceLink: "https://example.com",
            notes: "MVP scope",
            blockReason: "No blocker",
            recoveryNote: "Not needed",
            reviewNote: "Done",
            updatedAt: date(2026, 6, 9, 12, 30)
        )
        let session = LearningSession(
            id: sessionID,
            taskID: taskID,
            startedAt: date(2026, 6, 9, 9, 0),
            endedAt: date(2026, 6, 9, 9, 45),
            note: "Focused",
            activeSeconds: 2_700
        )
        let event = TaskEvent(
            id: eventID,
            taskID: taskID,
            type: .reviewed,
            occurredAt: date(2026, 6, 9, 12, 30),
            note: "Review saved"
        )
        let achievement = AchievementRecord(
            id: achievementID,
            kind: .firstOnTimeClosure,
            unlockedAt: date(2026, 6, 9, 12, 35),
            relatedTaskID: taskID,
            isSeen: true
        )
        let settings = AppSettings(
            reminderLeadMinutes: 45,
            dailyReminderEnabled: false,
            dailyReminderHour: 21,
            dailyReminderMinute: 30,
            overdueReminderEnabled: false,
            didRequestNotificationAuthorization: true,
            notificationStatusRaw: ReminderAuthorizationState.denied.rawValue,
            lastBackupURL: "/tmp/daydayup-last.json",
            appearanceModeRaw: AppAppearanceMode.dark.rawValue,
            glassTransparency: 0.84
        )
        let focusState = ActiveFocusState(
            taskID: taskID,
            originalStartedAt: date(2026, 6, 9, 13, 0),
            currentStartedAt: nil,
            pausedAt: date(2026, 6, 9, 13, 15),
            accumulatedSeconds: 900,
            draftNote: "Resume later"
        )
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let backupURL = directory.appendingPathComponent("DayDayUp-Backup.json")

        try DayDayUpBackupService.exportBackup(
            to: backupURL,
            tasks: [task],
            sessions: [session],
            events: [event],
            achievements: [achievement],
            settings: settings,
            focusState: focusState
        )

        let preview = try DayDayUpBackupService.previewBackup(at: backupURL)
        #expect(preview.taskCount == 1)
        #expect(preview.sessionCount == 1)
        #expect(preview.eventCount == 1)
        #expect(preview.achievementCount == 1)

        let container = try inMemoryContainer()
        let context = ModelContext(container)
        let importedSettings = AppSettings()
        let importedFocusState = ActiveFocusState()
        context.insert(importedSettings)
        context.insert(importedFocusState)

        let summary = try DayDayUpBackupService.importBackup(
            from: backupURL,
            modelContext: context,
            tasks: [],
            sessions: [],
            events: [],
            achievements: [],
            settings: importedSettings,
            focusState: importedFocusState
        )
        try context.save()

        let importedTasks = try context.fetch(FetchDescriptor<LearningTask>())
        let importedSessions = try context.fetch(FetchDescriptor<LearningSession>())
        let importedEvents = try context.fetch(FetchDescriptor<TaskEvent>())
        let importedAchievements = try context.fetch(FetchDescriptor<AchievementRecord>())

        #expect(summary.text == "任务 1 个，学习时段 1 条，历程事件 1 条，里程碑 1 个")
        #expect(importedTasks.count == 1)
        #expect(importedTasks.first?.id == taskID)
        #expect(importedTasks.first?.resourceLink == "https://example.com")
        #expect(importedTasks.first?.reviewNote == "Done")
        #expect(importedSessions.first?.activeSeconds == 2_700)
        #expect(importedEvents.first?.typeRaw == TaskEventType.reviewed.rawValue)
        #expect(importedAchievements.first?.kindRaw == AchievementKind.firstOnTimeClosure.rawValue)
        #expect(importedSettings.reminderLeadMinutes == 45)
        #expect(importedSettings.dailyReminderEnabled == false)
        #expect(importedSettings.dailyReminderHour == 21)
        #expect(importedSettings.dailyReminderMinute == 30)
        #expect(importedSettings.overdueReminderEnabled == false)
        #expect(importedSettings.didRequestNotificationAuthorization)
        #expect(importedSettings.notificationStatus == .denied)
        #expect(importedSettings.lastBackupURL == "/tmp/daydayup-last.json")
        #expect(importedSettings.appearanceMode == .dark)
        #expect(abs(importedSettings.resolvedGlassTransparency - 0.84) < 0.001)
        #expect(importedFocusState.taskID == taskID)
        #expect(importedFocusState.isPaused)
        #expect(importedFocusState.draftNote == "Resume later")
    }

    @Test("widget snapshot selects nearest incomplete task before completed tasks")
    func widgetSnapshotTaskSelectionRules() {
        let now = date(2026, 6, 9, 12, 0)
        let later = LearningTask(
            name: "任务名称 B",
            details: "",
            direction: "",
            deadline: date(2026, 6, 12, 23, 59),
            progress: 0.2
        )
        let overdue = LearningTask(
            name: "任务名称 A",
            details: "",
            direction: "",
            deadline: date(2026, 6, 8, 23, 59),
            progress: 0.6
        )
        let completed = LearningTask(
            name: "任务名称 C",
            details: "",
            direction: "",
            deadline: date(2026, 6, 7, 23, 59),
            completedAt: date(2026, 6, 8, 10, 0),
            progress: 1
        )

        let snapshot = WidgetSnapshotWriter.makeSnapshot(
            tasks: [later, completed, overdue],
            sessions: [],
            focusState: nil,
            now: now
        )

        #expect(snapshot.task?.id == overdue.id)
        #expect(snapshot.task?.statusRaw == TaskStatus.overdue.rawValue)
        #expect(snapshot.overdueCount == 1)
    }

    @Test("widget snapshot falls back to latest completed task")
    func widgetSnapshotCompletedFallbackRules() {
        let now = date(2026, 6, 9, 12, 0)
        let older = LearningTask(
            name: "任务名称 A",
            details: "",
            direction: "",
            deadline: date(2026, 6, 6, 23, 59),
            completedAt: date(2026, 6, 7, 10, 0),
            progress: 1
        )
        let newer = LearningTask(
            name: "任务名称 B",
            details: "",
            direction: "",
            deadline: date(2026, 6, 7, 23, 59),
            completedAt: date(2026, 6, 9, 10, 0),
            progress: 1
        )

        let snapshot = WidgetSnapshotWriter.makeSnapshot(
            tasks: [older, newer],
            sessions: [],
            focusState: nil,
            now: now
        )

        #expect(snapshot.task?.id == newer.id)
        #expect(snapshot.task?.statusRaw == TaskStatus.recovered.rawValue)
    }

    @Test("widget countdown formats incomplete overdue and completed states")
    func widgetCountdownFormattingRules() {
        let now = date(2026, 6, 9, 12, 0)
        let future = date(2026, 6, 10, 16, 22)
        let past = date(2026, 6, 9, 10, 55)

        #expect(DayDayUpWidgetShared.countdownText(deadline: future, completedAt: nil, now: now, compact: true) == "01 天 04:22")
        #expect(DayDayUpWidgetShared.countdownText(deadline: past, completedAt: nil, now: now, compact: true) == "逾期 00 天 01:05")
        #expect(DayDayUpWidgetShared.countdownText(deadline: future, completedAt: now, now: now, compact: false) == "已完成")
    }

    @Test("widget dashboard json writes reads and fails silently")
    func widgetDashboardJSONRules() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("widget-dashboard.json")
        let now = date(2026, 6, 9, 12, 0)
        let snapshot = WidgetDashboardSnapshot(
            updatedAt: now,
            task: WidgetTaskSnapshot(
                id: UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!,
                name: "任务名称",
                deadline: date(2026, 6, 10, 23, 59),
                completedAt: nil,
                progress: 0.62,
                statusRaw: WidgetTaskStatus.warning.rawValue,
                completionCriteria: "完成标准"
            ),
            activeFocus: nil,
            todayFocusMinutes: 45,
            overdueCount: 0,
            glassTransparency: 0.73
        )

        try DayDayUpWidgetShared.writeDashboard(snapshot, to: url)

        #expect(DayDayUpWidgetShared.readDashboard(from: url) == snapshot)
        #expect(DayDayUpWidgetShared.readDashboard(from: directory.appendingPathComponent("missing.json")) == nil)
        #expect(DayDayUpWidgetShared.decodeDashboard(Data("not-json".utf8)) == nil)
    }

    @Test("widget snapshot carries clamped glass transparency")
    func widgetSnapshotGlassTransparencyRules() {
        let now = date(2026, 6, 9, 12, 0)
        let task = LearningTask(
            name: "任务名称",
            details: "",
            direction: "",
            deadline: date(2026, 6, 9, 23, 59),
            progress: 0.2
        )

        let transparent = WidgetSnapshotWriter.makeSnapshot(
            tasks: [task],
            sessions: [],
            focusState: nil,
            glassTransparency: 0.84,
            now: now
        )
        let tooTransparent = WidgetSnapshotWriter.makeSnapshot(
            tasks: [task],
            sessions: [],
            focusState: nil,
            glassTransparency: 1.8,
            now: now
        )
        let tooSolid = WidgetSnapshotWriter.makeSnapshot(
            tasks: [task],
            sessions: [],
            focusState: nil,
            glassTransparency: -0.4,
            now: now
        )

        #expect(transparent.glassTransparency == 0.84)
        #expect(tooTransparent.glassTransparency == 1)
        #expect(tooSolid.glassTransparency == 0)
    }

    @Test("today basket snapshot sorts queue and counts daily work")
    func widgetTodayBasketSnapshotRules() {
        let now = date(2026, 6, 9, 12, 0)
        let overdue = LearningTask(
            name: "任务名称 A",
            details: "",
            direction: "",
            deadline: date(2026, 6, 8, 23, 59),
            progress: 0.3
        )
        let upcoming = LearningTask(
            name: "任务名称 B",
            details: "",
            direction: "",
            deadline: date(2026, 6, 9, 23, 59),
            progress: 0.2
        )
        let future = LearningTask(
            name: "任务名称 D",
            details: "",
            direction: "",
            deadline: date(2026, 6, 20, 23, 59),
            progress: 0.1
        )
        let completedToday = LearningTask(
            name: "任务名称 C",
            details: "",
            direction: "",
            deadline: date(2026, 6, 9, 18, 0),
            completedAt: date(2026, 6, 9, 11, 0),
            progress: 1
        )
        let session = LearningSession(
            taskID: completedToday.id,
            startedAt: date(2026, 6, 9, 9, 0),
            endedAt: date(2026, 6, 9, 9, 45),
            note: "",
            activeSeconds: 2_700
        )

        let snapshot = WidgetSnapshotWriter.makeSnapshot(
            tasks: [future, upcoming, completedToday, overdue],
            sessions: [session],
            focusState: nil,
            now: now
        )

        #expect(snapshot.today?.focusMinutes == 45)
        #expect(snapshot.today?.incompleteCount == 2)
        #expect(snapshot.today?.completedCount == 1)
        #expect(snapshot.today?.overdueCount == 1)
        #expect(snapshot.today?.queue.map(\.id) == [overdue.id, upcoming.id])
        #expect(snapshot.today?.recommendedTaskID == overdue.id)
    }

    @Test("today basket empty snapshot has no recommended task")
    func widgetTodayBasketEmptyRules() {
        let future = LearningTask(
            name: "任务名称",
            details: "",
            direction: "",
            deadline: date(2026, 6, 20, 23, 59)
        )
        let snapshot = WidgetSnapshotWriter.makeSnapshot(
            tasks: [future],
            sessions: [],
            focusState: nil,
            now: date(2026, 6, 9, 12, 0)
        )

        #expect(snapshot.today?.incompleteCount == 0)
        #expect(snapshot.today?.completedCount == 0)
        #expect(snapshot.today?.queue.isEmpty == true)
        #expect(snapshot.today?.recommendedTaskID == nil)
    }

    @Test("widget timeline policy separates A B and C refresh cadence")
    func widgetTimelinePolicyRules() {
        let now = date(2026, 6, 9, 12, 0)
        let taskID = UUID(uuidString: "77777777-8888-9999-AAAA-BBBBBBBBBBBB")!
        let task = WidgetTaskSnapshot(
            id: taskID,
            name: "任务名称",
            deadline: date(2026, 6, 9, 23, 59),
            completedAt: nil,
            progress: 0.4,
            statusRaw: WidgetTaskStatus.warning.rawValue,
            completionCriteria: ""
        )
        let activeSnapshot = WidgetDashboardSnapshot(
            updatedAt: now,
            task: task,
            activeFocus: nil,
            todayFocusMinutes: 0,
            overdueCount: 0,
            today: WidgetTodaySnapshot(
                focusMinutes: 0,
                incompleteCount: 1,
                completedCount: 0,
                overdueCount: 0,
                queue: [task],
                recommendedTaskID: taskID
            )
        )
        let emptySnapshot = WidgetDashboardSnapshot(
            updatedAt: now,
            task: nil,
            activeFocus: nil,
            todayFocusMinutes: 0,
            overdueCount: 0,
            today: WidgetTodaySnapshot(
                focusMinutes: 0,
                incompleteCount: 0,
                completedCount: 0,
                overdueCount: 0,
                queue: [],
                recommendedTaskID: nil
            )
        )

        let nextTaskRefresh = DayDayUpWidgetShared.nextRefreshDate(for: activeSnapshot, mode: .nextTask, now: now)
        let todayRefresh = DayDayUpWidgetShared.nextRefreshDate(for: activeSnapshot, mode: .todayBasket, now: now)
        let emptyTodayRefresh = DayDayUpWidgetShared.nextRefreshDate(for: emptySnapshot, mode: .todayBasket, now: now)
        let rhythmRefresh = DayDayUpWidgetShared.nextRefreshDate(for: activeSnapshot, mode: .rhythmGauge, now: now)
        let missingNextRefresh = DayDayUpWidgetShared.nextRefreshDate(for: nil, mode: .nextTask, now: now)

        #expect(nextTaskRefresh.timeIntervalSince(now) <= 61)
        #expect(todayRefresh.timeIntervalSince(now) <= 61)
        #expect(Int(emptyTodayRefresh.timeIntervalSince(now)) == 900)
        #expect(Int(rhythmRefresh.timeIntervalSince(now)) == 1_800)
        #expect(Int(missingNextRefresh.timeIntervalSince(now)) == 900)
    }

    @Test("rhythm widget snapshot reuses metric calculator")
    func widgetRhythmSnapshotRules() {
        let now = date(2026, 6, 9, 12, 0)
        let completed = LearningTask(
            name: "任务名称 A",
            details: "",
            direction: "方向",
            deadline: date(2026, 6, 9, 18, 0),
            completedAt: date(2026, 6, 9, 11, 0),
            estimatedMinutes: 60,
            progress: 1,
            reviewNote: "复盘"
        )
        let open = LearningTask(
            name: "任务名称 B",
            details: "",
            direction: "方向",
            deadline: date(2026, 6, 10, 18, 0),
            estimatedMinutes: 60,
            progress: 0.3
        )
        let session = LearningSession(
            taskID: completed.id,
            startedAt: date(2026, 6, 9, 9, 0),
            endedAt: date(2026, 6, 9, 10, 0),
            note: "",
            activeSeconds: 3_600
        )

        let metrics = MetricCalculator.calculate(tasks: [completed, open], sessions: [session], now: now)
        let snapshot = WidgetSnapshotWriter.makeSnapshot(
            tasks: [completed, open],
            sessions: [session],
            focusState: nil,
            now: now
        )

        #expect(snapshot.rhythm?.hasTasks == true)
        #expect(snapshot.rhythm?.score == metrics.score)
        #expect(snapshot.rhythm?.scoreLabel == metrics.scoreLabel)
        #expect(snapshot.rhythm?.weeklyFocusMinutes == metrics.weeklyFocusMinutes)
        #expect(abs((snapshot.rhythm?.completionRate ?? 0) - metrics.completionRate) < 0.001)
        #expect(abs((snapshot.rhythm?.onTimeRate ?? 0) - metrics.onTimeRate) < 0.001)
        #expect(abs((snapshot.rhythm?.reviewRate ?? 0) - metrics.reviewRate) < 0.001)
    }

    @Test("rhythm widget risk task prioritizes overdue then nearest incomplete")
    func widgetRhythmRiskTaskRules() {
        let now = date(2026, 6, 9, 12, 0)
        let upcoming = LearningTask(
            name: "任务名称 A",
            details: "",
            direction: "",
            deadline: date(2026, 6, 10, 18, 0)
        )
        let overdue = LearningTask(
            name: "任务名称 B",
            details: "",
            direction: "",
            deadline: date(2026, 6, 8, 18, 0)
        )

        let withOverdue = WidgetSnapshotWriter.makeSnapshot(
            tasks: [upcoming, overdue],
            sessions: [],
            focusState: nil,
            now: now
        )
        let withoutOverdue = WidgetSnapshotWriter.makeSnapshot(
            tasks: [upcoming],
            sessions: [],
            focusState: nil,
            now: now
        )

        #expect(withOverdue.rhythm?.riskTask?.id == overdue.id)
        #expect(withoutOverdue.rhythm?.riskTask?.id == upcoming.id)
    }

    @Test("widget dashboard decodes old json without B and C snapshots")
    func widgetDashboardLegacyJSONRules() {
        let oldJSON = """
        {
          "updatedAt" : "2026-06-09T12:00:00Z",
          "task" : null,
          "activeFocus" : null,
          "todayFocusMinutes" : 0,
          "overdueCount" : 0
        }
        """

        let snapshot = DayDayUpWidgetShared.decodeDashboard(Data(oldJSON.utf8))

        #expect(snapshot != nil)
        #expect(snapshot?.today == nil)
        #expect(snapshot?.rhythm == nil)
        #expect(snapshot?.glassTransparency == DayDayUpWidgetShared.defaultGlassTransparency)
    }

    @Test("widget pending intent carries section destinations")
    func widgetPendingIntentDestinationRules() {
        let todayIntent = WidgetPendingIntent(
            kind: .openSection,
            taskID: nil,
            destination: .today,
            createdAt: date(2026, 6, 9, 12, 0)
        )
        let scoreIntent = WidgetPendingIntent(
            kind: .openSection,
            taskID: nil,
            destination: .score,
            createdAt: date(2026, 6, 9, 12, 0)
        )

        #expect(todayIntent.destination == .today)
        #expect(todayIntent.destinationRaw == "today")
        #expect(scoreIntent.destination == .score)
        #expect(scoreIntent.destinationRaw == "score")
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    private func inMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: LearningTask.self,
            LearningSession.self,
            TaskEvent.self,
            AchievementRecord.self,
            ActiveFocusState.self,
            AppSettings.self,
            configurations: configuration
        )
    }
}
