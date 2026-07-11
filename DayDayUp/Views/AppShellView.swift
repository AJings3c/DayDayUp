import SwiftUI

struct ShellView: View {
    let tasks: [LearningTask]
    let settings: AppSettings?
    let focusState: ActiveFocusState?
    @Bindable var router: AppRouter
    @Bindable var focusController: FocusSessionController
    let metrics: AppMetrics
    let currentNow: Date
    let lastReminderScanAt: Date?
    let taskActions: TaskActionSet
    let focusActions: FocusActionSet
    let settingsActions: SettingsActionSet

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedTask: LearningTask? {
        router.selectedTaskID.flatMap { id in tasks.first(where: { $0.id == id }) }
            ?? tasks.nearestIncomplete(now: currentNow)
            ?? tasks.latestCompleted
    }

    private var launchTask: LearningTask? {
        tasks.nearestIncomplete(now: currentNow) ?? tasks.latestCompleted
    }

    private var nextUpcomingTask: LearningTask? {
        tasks
            .filter { $0.completedAt == nil && $0.deadline > currentNow }
            .sorted { $0.deadline < $1.deadline }
            .first
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarNavigation(
                settings: settings,
                selectedSection: $router.selectedSection,
                onAppearanceChanged: settingsActions.appearanceChanged,
                onNewTask: taskActions.newTask
            )
            .frame(width: 272)
            .layoutPriority(2)
            .clipped()

            Divider()

            VStack(spacing: 0) {
                if router.selectedSection == .settings {
                    NotificationFallbackBanner(settings: settings)
                }
                Group {
                    switch router.selectedSection {
                    case .launch:
                        LaunchCountdownView(
                            task: launchTask,
                            nextUpcomingTask: nextUpcomingTask,
                            metrics: metrics,
                            now: currentNow,
                            onStartToday: { router.selectedSection = .today },
                            onTaskDetail: {
                                router.selectedTaskID = launchTask?.id
                                router.selectedSection = .tasks
                            },
                            onNewTask: taskActions.newTask,
                            onCreateSampleTask: taskActions.createSample,
                            onBeginFocus: taskActions.beginFocus
                        )
                    case .today:
                        TodayExecutionView(
                            tasks: tasks.sortedForExecution(now: currentNow),
                            now: currentNow,
                            focusController: focusController,
                            selectedTaskID: $router.selectedTaskID,
                            onBeginFocus: taskActions.beginFocus,
                            onPauseFocus: focusActions.pause,
                            onResumeFocus: focusActions.resume,
                            onFinishFocus: focusActions.finish,
                            onUpdateFocusNote: focusActions.updateNote,
                            onUpdateProgress: taskActions.updateProgress,
                            onMarkComplete: taskActions.complete,
                            onNewTask: taskActions.newTask,
                            onCreateSampleTask: taskActions.createSample
                        )
                    case .tasks:
                        TaskManagementView(
                            tasks: tasks,
                            now: currentNow,
                            selectedTaskID: $router.selectedTaskID,
                            onNewTask: taskActions.newTask,
                            onEditTask: taskActions.edit,
                            onBeginFocus: taskActions.beginFocus,
                            onMarkComplete: taskActions.complete
                        )
                    case .score:
                        ScoreDashboardView(
                            tasks: tasks,
                            metrics: metrics,
                            now: currentNow,
                            selectedTaskID: $router.selectedTaskID
                        )
                    case .journey:
                        LearningJourneyView(
                            tasks: tasks,
                            now: currentNow,
                            selectedTaskID: $router.selectedTaskID
                        )
                    case .settings:
                        SettingsBackupView(
                            settings: settings,
                            tasks: tasks,
                            focusState: focusState,
                            lastReminderScanAt: lastReminderScanAt,
                            onAppearanceChanged: settingsActions.appearanceChanged,
                            onSettingsChanged: settingsActions.settingsChanged,
                            onRequestNotifications: settingsActions.requestNotifications,
                            onExportBackup: settingsActions.exportBackup,
                            onPreviewImport: settingsActions.previewImport,
                            onImportBackup: settingsActions.importBackup
                        )
                    }
                }
                .id(router.selectedSection)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity
                        )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(reduceMotion ? nil : DayMotion.navigation, value: router.selectedSection)
            }
            .dayGlassMotionEnabled(router.selectedSection != .score)
            .dayPageBackground()
            .frame(minWidth: 780, maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
            .clipped()

            Divider()

            Group {
                if let selectedTask {
                    TaskDetailInspectorContainer(
                        task: selectedTask,
                        now: currentNow,
                        onEditTask: taskActions.edit,
                        onBeginFocus: taskActions.beginFocus,
                        onMarkComplete: taskActions.complete,
                        onRecordBlock: taskActions.recordBlock,
                        onRecordRecovery: taskActions.recordRecovery,
                        onSaveReview: taskActions.saveReview,
                        onDeleteTask: taskActions.delete
                    )
                } else {
                    EmptyInspectorView(onNewTask: taskActions.newTask, onCreateSampleTask: taskActions.createSample)
                }
            }
            .id(selectedTask?.id)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing)))
            .animation(reduceMotion ? nil : DayMotion.state, value: selectedTask?.id)
            .frame(width: 348)
            .frame(maxHeight: .infinity)
            .layoutPriority(2)
            .clipped()
        }
        .tint(DayColor.primaryAction)
    }
}

private struct NotificationFallbackBanner: View {
    let settings: AppSettings?

    var body: some View {
        if shouldShow {
            HStack(spacing: 8) {
                Image(systemName: "bell.slash.fill")
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                Text(message)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DayColor.text)
                    .lineLimit(2)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(tint.opacity(0.10))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(DayColor.border.opacity(0.68))
                    .frame(height: 1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(message)
        }
    }

    private var shouldShow: Bool {
        switch settings?.notificationStatus {
        case .some(.authorized), .some(.provisional), .some(.ephemeral):
            return false
        case .some(.unknown), .some(.notDetermined), .some(.denied), nil:
            return true
        }
    }

    private var tint: Color {
        if case .some(.denied) = settings?.notificationStatus {
            return DayColor.danger
        }
        return DayColor.warning
    }

    private var message: String {
        switch settings?.notificationStatus {
        case .some(.denied):
            return "系统通知已被拒绝，DayDayUp 会使用 App 内提醒并记录提醒事件。"
        case .some(.notDetermined):
            return "尚未开启系统通知，DayDayUp 会先使用 App 内提醒并记录提醒事件。"
        default:
            return "通知状态未知，DayDayUp 会先使用 App 内提醒并记录提醒事件。"
        }
    }
}

struct SidebarNavigation: View {
    let settings: AppSettings?
    @Binding var selectedSection: AppSection
    let onAppearanceChanged: () -> Void
    let onNewTask: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                SquirrelImage(mood: .active, size: 46)
                    .padding(3)
                    .background(DayColor.squirrelSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("DayDayUp")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(DayColor.primaryDeep)
                        .lineLimit(1)
                    Text("把今天的松果收好")
                        .font(.caption)
                        .foregroundStyle(DayColor.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)

            VStack(alignment: .leading, spacing: 6) {
                Text("行动")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DayColor.muted)
                    .padding(.horizontal, 12)

                ForEach(Array(AppSection.allCases.prefix(3))) { section in
                    SidebarNavigationRow(
                        section: section,
                        isSelected: selectedSection == section,
                        selectionNamespace: selectionNamespace
                    ) {
                        select(section)
                    }
                }

                Text("复盘与系统")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DayColor.muted)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                ForEach(Array(AppSection.allCases.dropFirst(3))) { section in
                    SidebarNavigationRow(
                        section: section,
                        isSelected: selectedSection == section,
                        selectionNamespace: selectionNamespace
                    ) {
                        select(section)
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 0)

            if let settings {
                SidebarAppearanceControls(settings: settings, onAppearanceChanged: onAppearanceChanged)
                    .padding(.horizontal, 14)
            }

            Button {
                onNewTask()
            } label: {
                Label("新建任务", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("n", modifiers: [.command])
            .accessibilityHint("打开任务录入表单")
            .padding([.horizontal, .bottom], 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dayGlassMotionEnabled(false)
        .background {
            ZStack {
                Rectangle().fill(.thinMaterial)
                Rectangle().fill(DayColor.surface.opacity(0.88))
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(DayColor.border.opacity(0.7))
                .frame(width: 1)
        }
    }

    private func select(_ section: AppSection) {
        guard selectedSection != section else { return }
        withAnimation(reduceMotion ? nil : DayMotion.navigation) {
            selectedSection = section
        }
    }
}

private struct SidebarNavigationRow: View {
    let section: AppSection
    let isSelected: Bool
    let selectionNamespace: Namespace.ID
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: section.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.white : DayColor.muted)
                    .frame(width: 28, height: 28)
                    .background(
                        isSelected ? DayColor.primaryAction : DayColor.surface,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                Text(section.title)
                    .font(.callout.weight(isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Spacer(minLength: 0)

                if isSelected {
                    Circle()
                        .fill(DayColor.squirrel)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(isSelected ? DayColor.primaryDeep : DayColor.text)
            .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            .padding(.horizontal, 8)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DayColor.selected)
                        .matchedGeometryEffect(id: "sidebar-selection", in: selectionNamespace)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(DayColor.hover)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : DayMotion.feedback, value: isHovered)
        .animation(reduceMotion ? nil : DayMotion.state, value: isSelected)
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct SidebarAppearanceControls: View {
    @Bindable var settings: AppSettings
    let onAppearanceChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("外观", systemImage: "circle.lefthalf.filled")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DayColor.muted)

            Picker("外观模式", selection: appearanceModeBinding) {
                Text("系统").tag(AppAppearanceMode.system)
                Text("浅色").tag(AppAppearanceMode.light)
                Text("深色").tag(AppAppearanceMode.dark)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 5) {
                Text("\(Int(settings.resolvedGlassTransparency * 100))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(DayColor.muted)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                HStack(spacing: 8) {
                    Text("实体")

                    Slider(
                        value: glassTransparencyBinding,
                        in: 0...1,
                        step: 0.01,
                        onEditingChanged: { editing in
                            if !editing {
                                onAppearanceChanged()
                            }
                        }
                    )
                    .accessibilityLabel("界面透明度")

                    Text("通透")
                }
                .font(.caption)
                .foregroundStyle(DayColor.muted)
            }
        }
        .padding(12)
        .dayPanel(cornerRadius: 12)
    }

    private var appearanceModeBinding: Binding<AppAppearanceMode> {
        Binding(
            get: { settings.appearanceMode },
            set: { mode in
                settings.appearanceMode = mode
                onAppearanceChanged()
            }
        )
    }

    private var glassTransparencyBinding: Binding<Double> {
        Binding(
            get: { settings.resolvedGlassTransparency },
            set: { settings.resolvedGlassTransparency = $0 }
        )
    }
}
