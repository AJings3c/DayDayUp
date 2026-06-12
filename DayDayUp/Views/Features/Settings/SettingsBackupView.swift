import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsBackupView: View {
    let settings: AppSettings?
    let tasks: [LearningTask]
    let sessions: [LearningSession]
    let events: [TaskEvent]
    let achievements: [AchievementRecord]
    let focusState: ActiveFocusState?
    let onAppearanceChanged: () -> Void
    let onSettingsChanged: () -> Void
    let onRequestNotifications: () -> Void
    let onExportBackup: (URL) -> String
    let onPreviewImport: (URL) -> String
    let onImportBackup: (URL) -> String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageTitle(title: "设置与备份", subtitle: "调整提醒节奏，导出或恢复本机学习记录。")
                if let settings {
                    SettingsBackupContent(
                        settings: settings,
                        tasks: tasks,
                        sessions: sessions,
                        events: events,
                        achievements: achievements,
                        focusState: focusState,
                        onAppearanceChanged: onAppearanceChanged,
                        onSettingsChanged: onSettingsChanged,
                        onRequestNotifications: onRequestNotifications,
                        onExportBackup: onExportBackup,
                        onPreviewImport: onPreviewImport,
                        onImportBackup: onImportBackup
                    )
                } else {
                    EmptyStateView(title: "设置正在初始化", subtitle: "稍等一下，DayDayUp 会创建默认提醒和备份设置。")
                }
            }
            .padding(28)
        }
        .dayPageBackground()
    }
}

struct SettingsBackupContent: View {
    @Bindable var settings: AppSettings
    let tasks: [LearningTask]
    let sessions: [LearningSession]
    let events: [TaskEvent]
    let achievements: [AchievementRecord]
    let focusState: ActiveFocusState?
    let onAppearanceChanged: () -> Void
    let onSettingsChanged: () -> Void
    let onRequestNotifications: () -> Void
    let onExportBackup: (URL) -> String
    let onPreviewImport: (URL) -> String
    let onImportBackup: (URL) -> String

    @State private var statusMessage = ""
    @State private var pendingImportURL: URL?
    @State private var pendingImportPreview = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            appearancePanel
            reminderPanel
            backupPanel
            dataSummaryPanel
        }
    }

    private var appearancePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "外观", systemImage: "circle.lefthalf.filled")

            HStack(spacing: 18) {
                Picker("外观模式", selection: appearanceModeBinding) {
                    ForEach(AppAppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 320)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("界面透明度", systemImage: "slider.horizontal.3")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(DayColor.text)
                    Spacer()
                    Text("\(Int(settings.resolvedGlassTransparency * 100))%")
                        .font(.system(.callout, design: .monospaced).weight(.semibold))
                        .foregroundStyle(DayColor.primary)
                        .frame(width: 54, alignment: .trailing)
                }

                HStack(spacing: 12) {
                    Text("实体")
                        .font(.caption)
                        .foregroundStyle(DayColor.muted)
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
                        .font(.caption)
                        .foregroundStyle(DayColor.muted)
                }
            }
        }
        .padding(20)
        .dayPanel(cornerRadius: 14)
    }

    private var reminderPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SectionHeader(title: "提醒", systemImage: "bell.badge")
                Spacer()
                Label(settings.notificationStatus.title, systemImage: notificationStatusSymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(notificationStatusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(notificationStatusColor.opacity(0.12), in: Capsule())
            }

            HStack(spacing: 16) {
                Stepper(value: $settings.reminderLeadMinutes, in: 1...1440, step: 5) {
                    Text("任务截止前 \(settings.reminderLeadMinutes) 分钟提醒")
                }
                .onChange(of: settings.reminderLeadMinutes) { _, _ in onSettingsChanged() }

                Toggle("逾期后提醒", isOn: $settings.overdueReminderEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: settings.overdueReminderEnabled) { _, _ in onSettingsChanged() }
            }

            HStack(spacing: 16) {
                Toggle("每日学习提醒", isOn: $settings.dailyReminderEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: settings.dailyReminderEnabled) { _, _ in onSettingsChanged() }

                Stepper(value: $settings.dailyReminderHour, in: 0...23) {
                    Text("小时 \(settings.dailyReminderHour)")
                }
                .disabled(!settings.dailyReminderEnabled)
                .onChange(of: settings.dailyReminderHour) { _, _ in onSettingsChanged() }

                Stepper(value: $settings.dailyReminderMinute, in: 0...59, step: 5) {
                    Text("分钟 \(settings.dailyReminderMinute)")
                }
                .disabled(!settings.dailyReminderEnabled)
                .onChange(of: settings.dailyReminderMinute) { _, _ in onSettingsChanged() }

                Spacer()

                Button {
                    onRequestNotifications()
                    statusMessage = "已请求通知权限，系统状态会自动刷新。"
                } label: {
                    Label("请求通知权限", systemImage: "bell.and.waves.left.and.right")
                }
            }
        }
        .padding(20)
        .dayPanel(cornerRadius: 14)
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
            set: { value in
                settings.resolvedGlassTransparency = value
            }
        )
    }

    private var backupPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "本机备份", systemImage: "externaldrive.badge.timemachine")
            HStack(spacing: 10) {
                Button {
                    chooseExportURL()
                } label: {
                    Label("导出 JSON 备份", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    chooseImportURL()
                } label: {
                    Label("选择备份文件", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.bordered)

                if pendingImportURL != nil {
                    Button {
                        importPendingBackup()
                    } label: {
                        Label("导入并合并", systemImage: "tray.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if !settings.lastBackupURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("最近导出：\(settings.lastBackupURL)")
                    .font(.caption)
                    .foregroundStyle(DayColor.muted)
                    .lineLimit(2)
            }

            if !pendingImportPreview.isEmpty {
                Text(pendingImportPreview)
                    .font(.callout)
                    .foregroundStyle(DayColor.text)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .dayPanel(cornerRadius: 10)
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(statusMessage.contains("失败") ? DayColor.danger : DayColor.success)
            }
        }
        .padding(20)
        .dayPanel(cornerRadius: 14)
    }

    private var dataSummaryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                MetricCard(title: "任务", value: "\(tasks.count)", subtitle: "本机记录", tint: DayColor.primary)
                MetricCard(title: "学习时段", value: "\(sessions.count)", subtitle: "专注记录", tint: DayColor.success)
                MetricCard(title: "历程事件", value: "\(events.count)", subtitle: "时间线", tint: DayColor.warning)
                MetricCard(title: "里程碑", value: "\(achievements.count)", subtitle: "学习档案", tint: DayColor.recovered)
            }
            if focusState?.isActive == true {
                Label("当前有未结束专注，备份会保存这段专注状态。", systemImage: "timer")
                    .font(.callout)
                    .foregroundStyle(DayColor.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DayColor.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var notificationStatusSymbol: String {
        switch settings.notificationStatus {
        case .authorized, .provisional, .ephemeral: "checkmark.circle.fill"
        case .denied: "xmark.octagon.fill"
        case .notDetermined, .unknown: "questionmark.circle"
        }
    }

    private var notificationStatusColor: Color {
        switch settings.notificationStatus {
        case .authorized, .provisional, .ephemeral: DayColor.success
        case .denied: DayColor.danger
        case .notDetermined, .unknown: DayColor.warning
        }
    }

    private func chooseExportURL() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        panel.nameFieldStringValue = "DayDayUp-Backup-\(formatter.string(from: .now)).json"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            statusMessage = onExportBackup(url)
        }
    }

    private func chooseImportURL() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            pendingImportURL = url
            pendingImportPreview = onPreviewImport(url)
            statusMessage = ""
        }
    }

    private func importPendingBackup() {
        guard let pendingImportURL else { return }
        statusMessage = onImportBackup(pendingImportURL)
        pendingImportPreview = ""
        self.pendingImportURL = nil
    }
}
