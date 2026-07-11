import Foundation
import SwiftData

enum DayDayUpSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            LearningTask.self,
            LearningSession.self,
            TaskEvent.self,
            AchievementRecord.self,
            ActiveFocusState.self,
            AppSettings.self
        ]
    }
}

enum DayDayUpMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [DayDayUpSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

struct ModelIntegritySummary: Equatable {
    var linkedSessions = 0
    var linkedEvents = 0
    var removedOrphanSessions = 0
    var removedOrphanEvents = 0
    var removedDuplicateSettings = 0
    var removedDuplicateFocusStates = 0
    var clearedInvalidFocus = false
}

struct ModelIntegrityResult {
    let settings: AppSettings
    let focusState: ActiveFocusState
    let summary: ModelIntegritySummary
}

@MainActor
enum ModelIntegrityCoordinator {
    static func repair(modelContext: ModelContext) throws -> ModelIntegrityResult {
        let tasks = try modelContext.fetch(FetchDescriptor<LearningTask>())
        let sessions = try modelContext.fetch(FetchDescriptor<LearningSession>())
        let events = try modelContext.fetch(FetchDescriptor<TaskEvent>())
        let taskByID = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        var summary = ModelIntegritySummary()

        for session in sessions {
            if let task = taskByID[session.taskID] {
                if session.task?.id != task.id {
                    session.task = task
                    summary.linkedSessions += 1
                }
            } else {
                modelContext.delete(session)
                summary.removedOrphanSessions += 1
            }
        }

        for event in events {
            if let task = taskByID[event.taskID] {
                if event.task?.id != task.id {
                    event.task = task
                    summary.linkedEvents += 1
                }
            } else {
                modelContext.delete(event)
                summary.removedOrphanEvents += 1
            }
        }

        let allSettings = try modelContext.fetch(
            FetchDescriptor<AppSettings>(sortBy: [SortDescriptor(\.createdAt)])
        )
        let settings = allSettings.first ?? AppSettings()
        if allSettings.isEmpty {
            modelContext.insert(settings)
        } else {
            for duplicate in allSettings.dropFirst() {
                modelContext.delete(duplicate)
                summary.removedDuplicateSettings += 1
            }
        }

        let allFocusStates = try modelContext.fetch(FetchDescriptor<ActiveFocusState>())
        let focusState = allFocusStates.first(where: \.isActive) ?? allFocusStates.first ?? ActiveFocusState()
        if allFocusStates.isEmpty {
            modelContext.insert(focusState)
        } else {
            for duplicate in allFocusStates where duplicate.id != focusState.id {
                modelContext.delete(duplicate)
                summary.removedDuplicateFocusStates += 1
            }
        }

        if let taskID = focusState.taskID,
           taskByID[taskID]?.completedAt != nil || taskByID[taskID] == nil {
            focusState.clear()
            summary.clearedInvalidFocus = true
        }

        try modelContext.commitOrRollback()
        return ModelIntegrityResult(settings: settings, focusState: focusState, summary: summary)
    }
}
