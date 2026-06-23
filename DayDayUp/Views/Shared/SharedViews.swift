import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarCountdownView: View {
    @Query(sort: \LearningTask.deadline) private var tasks: [LearningTask]
    @Environment(\.openWindow) private var openWindow
    @State private var currentNow = Date.now

    private var displayTask: LearningTask? {
        tasks.nearestIncomplete(now: currentNow) ?? tasks.latestCompleted
    }

    var body: some View {
        GlassHost(spacing: 12) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    SquirrelImage(mood: SquirrelMood(status: displayTask?.status(now: currentNow)), size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DayDayUp")
                            .font(.headline)
                        Text("菜单栏倒计时")
                            .font(.caption)
                            .foregroundStyle(DayColor.muted)
                    }
                    Spacer()
                }

                if let task = displayTask {
                    VStack(alignment: .leading, spacing: 10) {
                        StatusBadge(status: task.status(now: currentNow))
                        Text(task.name)
                            .font(.headline)
                            .lineLimit(2)
                        CountdownText(deadline: task.deadline, completedAt: task.completedAt, compact: true)
                        Text("截止时间：\(task.deadline.formattedDateTime())")
                            .font(.caption)
                            .foregroundStyle(DayColor.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .dayLiquidPanel(cornerRadius: 12, interactive: true)

                    Button {
                        openWindow(id: "main")
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            NotificationCenter.default.post(name: .dayDayUpStartTask, object: task.id)
                        }
                    } label: {
                        Label("开始专注", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(task.completedAt != nil)
                } else {
                    EmptyStateView(title: "暂无任务", subtitle: "先在主窗口新建一个任务。")
                }

                Button {
                    openWindow(id: "main")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                } label: {
                    Label("打开 DayDayUp", systemImage: "macwindow")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            .frame(width: 330)
            .dayGlass(cornerRadius: 18, interactive: true)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in
            currentNow = now
        }
    }
}

struct PageTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .default))
                .foregroundStyle(DayColor.primaryDeep)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(DayColor.muted)
        }
        .accessibilityElement(children: .combine)
    }
}

struct SectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(DayColor.text)
            .accessibilityAddTraits(.isHeader)
    }
}

struct DayTextEditor: View {
    @Binding var text: String
    let minHeight: CGFloat
    var width: CGFloat?
    let label: String
    var accessibilityIdentifier: String?

    var body: some View {
        TextEditor(text: $text)
            .scrollContentBackground(.hidden)
            .padding(6)
            .frame(width: width)
            .frame(minHeight: minHeight)
            .dayPanel(cornerRadius: 8)
            .accessibilityLabel(label)
            .accessibilityIdentifier(accessibilityIdentifier ?? label)
    }
}

struct AchievementToastView: View {
    let record: AchievementRecord
    let relatedTask: LearningTask?
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: record.kind.symbolName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(record.kind.tint)
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("学习里程碑")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DayColor.muted)
                Text(record.kind.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DayColor.text)
                Text(toastSubtitle)
                    .font(.callout)
                    .foregroundStyle(DayColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(DayColor.muted)
            .accessibilityLabel("关闭成就提示")
        }
        .padding(14)
        .frame(width: 360, alignment: .leading)
        .dayGlass(cornerRadius: 16, interactive: true)
        .scaleEffect(isVisible || reduceMotion ? 1 : 0.98)
        .opacity(isVisible ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isVisible)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("解锁成就，\(record.kind.accessibilityText)，\(toastSubtitle)")
        .onAppear {
            isVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
                onDismiss()
            }
        }
    }

    private var toastSubtitle: String {
        if let relatedTask {
            return "\(record.kind.subtitle) 关联任务：\(relatedTask.name)"
        }
        return record.kind.subtitle
    }
}

struct ReminderToastView: View {
    let event: TaskEvent
    let relatedTask: LearningTask?
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: event.type.symbolName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.type == .overdueReminder ? "逾期提醒" : "截止提醒")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DayColor.muted)
                Text(relatedTask?.name ?? "学习任务")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DayColor.text)
                    .lineLimit(2)
                Text(event.note)
                    .font(.callout)
                    .foregroundStyle(DayColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(DayColor.muted)
            .accessibilityLabel("关闭提醒")
        }
        .padding(14)
        .frame(width: 380, alignment: .leading)
        .dayGlass(cornerRadius: 16, interactive: true)
        .scaleEffect(isVisible || reduceMotion ? 1 : 0.98)
        .opacity(isVisible ? 1 : 0)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isVisible)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.type.title)，\(relatedTask?.name ?? "学习任务")，\(event.note)")
        .onAppear {
            isVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                onDismiss()
            }
        }
    }

    private var tint: Color {
        event.type == .overdueReminder ? DayColor.danger : DayColor.warning
    }
}

struct AchievementShelfView: View {
    let achievements: [AchievementRecord]
    let tasks: [LearningTask]

    private var unlockedKinds: Set<String> {
        Set(achievements.map(\.kindRaw))
    }

    private var recentAchievements: [AchievementRecord] {
        Array(achievements.sorted { $0.unlockedAt > $1.unlockedAt }.prefix(4))
    }

    private var nextKinds: [AchievementKind] {
        Array(AchievementKind.allCases.filter { !unlockedKinds.contains($0.rawValue) }.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "学习里程碑", systemImage: "sparkles")
                Spacer()
                Text("\(achievements.count) / \(AchievementKind.allCases.count)")
                    .font(.system(.callout, design: .monospaced).weight(.semibold))
                    .foregroundStyle(DayColor.primaryDeep)
                    .accessibilityLabel("已解锁 \(achievements.count) 个，共 \(AchievementKind.allCases.count) 个")
            }

            if achievements.isEmpty {
                EmptyStateView(
                    title: "还没有解锁里程碑",
                    subtitle: "完成第一个任务后，这里会记录你的学习节点。"
                )
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], spacing: 12) {
                    ForEach(recentAchievements, id: \.id) { record in
                        AchievementCard(record: record, relatedTask: relatedTask(for: record))
                    }
                }
            }

            if !nextKinds.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("下一批可解锁")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DayColor.muted)
                    HStack(spacing: 8) {
                        ForEach(nextKinds) { kind in
                            Label(kind.title, systemImage: kind.symbolName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(DayColor.muted)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(DayColor.surface, in: Capsule())
                                .accessibilityLabel("未解锁，\(kind.accessibilityText)")
                        }
                    }
                }
            }
        }
        .padding(20)
        .dayPanel(cornerRadius: 14)
    }

    private func relatedTask(for record: AchievementRecord) -> LearningTask? {
        record.relatedTaskID.flatMap { id in tasks.first(where: { $0.id == id }) }
    }
}

struct AchievementCard: View {
    let record: AchievementRecord
    let relatedTask: LearningTask?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: record.kind.symbolName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(record.kind.tint)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(record.kind.title)
                    .font(.headline)
                    .foregroundStyle(DayColor.text)
                Text(record.kind.subtitle)
                    .font(.caption)
                    .foregroundStyle(DayColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Text(relatedTask?.name ?? "学习档案里程碑")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(record.kind.tint)
                    .lineLimit(1)
                Text(record.unlockedAt.formattedDateTime())
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(DayColor.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(record.kind.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(record.kind.tint.opacity(0.28)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(record.kind.accessibilityText)，解锁时间 \(record.unlockedAt.formattedDateTime())")
    }
}

struct RelatedAchievementsPanel: View {
    let achievements: [AchievementRecord]

    var body: some View {
        if !achievements.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "关联里程碑", systemImage: "sparkles")
                ForEach(achievements.sorted { $0.unlockedAt > $1.unlockedAt }, id: \.id) { record in
                    HStack(spacing: 8) {
                        Image(systemName: record.kind.symbolName)
                            .foregroundStyle(record.kind.tint)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.kind.title)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(DayColor.text)
                            Text(record.unlockedAt.formattedDateTime())
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(DayColor.muted)
                        }
                        Spacer()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(record.kind.accessibilityText)，解锁时间 \(record.unlockedAt.formattedDateTime())")
                }
            }
            .padding(14)
            .dayPanel(cornerRadius: 12)
        }
    }
}

struct EmptyInspectorView: View {
    let onNewTask: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            SquirrelImage(mood: .empty, size: 108)
            Text("还没有任务")
                .font(.headline)
            Text("写下任务名称、内容和截止时间，先把第一颗松果放进仓库。")
                .multilineTextAlignment(.center)
                .foregroundStyle(DayColor.muted)
            Button(action: onNewTask) {
                Label("新建任务", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dayPageBackground()
    }
}

struct EmptyStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "basket")
                .font(.largeTitle)
                .foregroundStyle(DayColor.squirrel)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(DayColor.text)
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(DayColor.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(24)
        .dayPanel(cornerRadius: 12)
        .accessibilityElement(children: .combine)
    }
}

struct CountdownText: View {
    let deadline: Date
    let completedAt: Date?
    var compact = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let text = countdownString(now: context.date)
            VStack(alignment: .leading, spacing: compact ? 4 : 8) {
                Text(completedAt == nil ? (deadline > context.date ? "剩余时间" : "逾期时间") : "完成状态")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DayColor.muted)
                Text(text)
                    .font(.system(size: compact ? 28 : 46, weight: .semibold, design: .monospaced))
                    .foregroundStyle(displayColor(now: context.date))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityText(now: context.date, text: text))
        }
    }

    private func countdownString(now: Date) -> String {
        if completedAt != nil {
            return "任务完成啦，开始干饭！"
        }

        let interval = abs(deadline.timeIntervalSince(now))
        let totalSeconds = Int(interval)
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d 天 %02d:%02d:%02d", days, hours, minutes, seconds)
    }

    private func displayColor(now: Date) -> Color {
        if let completedAt {
            return completedAt > deadline ? DayColor.recovered : DayColor.success
        }
        return now > deadline ? DayColor.danger : DayColor.primaryDeep
    }

    private func accessibilityText(now: Date, text: String) -> String {
        if completedAt != nil {
            return "任务完成啦，开始干饭"
        }
        return deadline > now ? "剩余时间 \(text)" : "逾期时间 \(text)"
    }
}

struct GlassHost<Content: View>: View {
    var spacing: CGFloat? = nil
    @ViewBuilder var content: Content
    @Namespace private var glassNamespace

    init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
                    .glassEffectUnion(id: "daydayup-glass-host", namespace: glassNamespace)
            }
        } else {
            content
        }
    }
}

extension Array where Element == LearningTask {
    var nearestIncomplete: LearningTask? {
        nearestIncomplete(now: .now)
    }

    func nearestIncomplete(now: Date) -> LearningTask? {
        filter { $0.completedAt == nil }
            .sortedForExecution(now: now)
            .first
    }

    var latestCompleted: LearningTask? {
        filter { $0.completedAt != nil }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .first
    }

    func sortedForExecution() -> [LearningTask] {
        sortedForExecution(now: .now)
    }

    func sortedForExecution(now: Date) -> [LearningTask] {
        sorted { lhs, rhs in
            let lhsRank = lhs.status(now: now).sortRank
            let rhsRank = rhs.status(now: now).sortRank
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return lhs.deadline < rhs.deadline
        }
    }

    func sortedForJourney() -> [LearningTask] {
        sortedForJourney(now: .now)
    }

    func sortedForJourney(now: Date) -> [LearningTask] {
        sorted {
            let lhsRank = $0.status(now: now).sortRank
            let rhsRank = $1.status(now: now).sortRank
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            let lhsDate = $0.updatedAt
            let rhsDate = $1.updatedAt
            if lhsDate != rhsDate {
                return lhsDate > rhsDate
            }
            return $0.deadline < $1.deadline
        }
    }
}

extension Array where Element == LearningSession {
    func merging(_ extraSessions: [LearningSession]) -> [LearningSession] {
        var seen = Set(map(\.id))
        var merged = self
        for session in extraSessions where !seen.contains(session.id) {
            seen.insert(session.id)
            merged.append(session)
        }
        return merged
    }
}

extension Array where Element == TaskEvent {
    func merging(_ extraEvents: [TaskEvent]) -> [TaskEvent] {
        var seen = Set(map(\.id))
        var merged = self
        for event in extraEvents where !seen.contains(event.id) {
            seen.insert(event.id)
            merged.append(event)
        }
        return merged
    }
}

extension TaskStatus {
    var sortRank: Int {
        switch self {
        case .overdue: 0
        case .warning: 1
        case .active: 2
        case .recovered: 3
        case .completed: 4
        }
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension LearningTask {
    var isEarlyCompleted: Bool {
        guard let completedAt else { return false }
        return progress >= 1 && completedAt < deadline
    }

    func isRelevantToday(now: Date = .now, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: now)
        return calendar.startOfDay(for: deadline) == day
            || startedAt.map { calendar.startOfDay(for: $0) == day } == true
            || completedAt.map { calendar.startOfDay(for: $0) == day } == true
            || status(now: now) == .overdue
    }
}

func durationString(from start: Date, to end: Date) -> String {
    let interval = max(0, Int(end.timeIntervalSince(start)))
    return durationString(seconds: Double(interval))
}

func durationString(seconds: Double) -> String {
    let interval = max(0, Int(seconds))
    let hours = interval / 3_600
    let minutes = (interval % 3_600) / 60
    let seconds = interval % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
}
