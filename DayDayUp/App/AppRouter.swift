import Foundation
import Observation

@MainActor
@Observable
final class AppRouter {
    var selectedSection: AppSection = .launch
    var selectedTaskID: UUID?
    var showingTaskEditor = false
    var editingTask: LearningTask?
    var errorMessage: String?

    func openNewTask() {
        editingTask = nil
        selectedSection = .tasks
        showingTaskEditor = true
    }

    func openEditor(_ task: LearningTask) {
        editingTask = task
        selectedTaskID = task.id
        selectedSection = .tasks
        showingTaskEditor = true
    }

    func openTask(_ taskID: UUID, section: AppSection = .tasks) {
        selectedTaskID = taskID
        selectedSection = section
    }

    func route(_ intent: WidgetPendingIntent) {
        switch intent.kind {
        case .openApp, .openSection:
            selectedSection = section(for: intent.destination) ?? .launch
        case .startFocus:
            if let taskID = intent.taskID {
                selectedTaskID = taskID
            }
            selectedSection = .today
        }
    }

    func present(error: Error) {
        errorMessage = error.localizedDescription
    }

    func dismissError() {
        errorMessage = nil
    }

    private func section(for destination: WidgetPendingIntent.Destination?) -> AppSection? {
        switch destination {
        case .launch: .launch
        case .today: .today
        case .score: .score
        case nil: nil
        }
    }
}
