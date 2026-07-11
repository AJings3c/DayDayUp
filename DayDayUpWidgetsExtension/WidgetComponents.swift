import AppIntents
import AppKit
import SwiftUI
import WidgetKit

struct WidgetHeader: View {
    let trailing: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("DayDayUp")
                .font(.system(.caption, design: .rounded, weight: .semibold))
            Spacer(minLength: 8)
            Text(trailing)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(WidgetPalette.accent)
                .lineLimit(1)
        }
    }
}

struct WidgetValueLine: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}

struct CompactMetric: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TaskQueueRow: View {
    let task: WidgetTaskSnapshot
    let date: Date

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(WidgetPalette.tint(for: task.status))
                .frame(width: 6, height: 6)
            Text(task.name)
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Spacer(minLength: 10)
            Text(timeText)
                .font(.caption2)
                .foregroundStyle(task.status == .overdue ? WidgetPalette.danger : .secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
    }

    private var timeText: String {
        if task.status == .overdue {
            return DayDayUpWidgetShared.countdownText(
                deadline: task.deadline,
                completedAt: task.completedAt,
                now: date,
                compact: true
            )
        }
        if Calendar.current.isDate(task.deadline, inSameDayAs: date) {
            return "今天 \(Self.timeFormatter.string(from: task.deadline))"
        }
        return DayDayUpWidgetShared.deadlineText(task.deadline)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

struct StartFocusButton: View {
    let taskID: UUID

    var body: some View {
        Button(intent: StartFocusIntent(taskID: taskID.uuidString)) {
            Label("开始专注", systemImage: "play.fill")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }
}

struct OpenTodayButton: View {
    var body: some View {
        Button(intent: OpenTodayExecutionIntent()) {
            Label("打开今日执行", systemImage: "play.circle")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

struct OpenScoreButton: View {
    var body: some View {
        Button(intent: OpenScoreDashboardIntent()) {
            Label("查看数据", systemImage: "chart.xyaxis.line")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }
}

struct StatusBadge: View {
    let status: WidgetTaskStatus
    let progress: Double

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbolName)
                .font(.caption2.weight(.bold))
            Text("\(status.title) \(DayDayUpWidgetShared.percentText(progress))")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(WidgetPalette.tint(for: status))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.thinMaterial, in: Capsule())
    }

    private var symbolName: String {
        switch status {
        case .active: "circle.dotted"
        case .warning: "exclamationmark.triangle.fill"
        case .overdue: "xmark.octagon.fill"
        case .completed: "checkmark.circle.fill"
        case .recovered: "arrow.triangle.2.circlepath.circle.fill"
        }
    }
}

struct EmptyWidgetView: View {
    let title: String
    let subtitle: String
    let isMedium: Bool
    let glassTransparency: Double

    var body: some View {
        VStack(alignment: .leading, spacing: isMedium ? 14 : 10) {
            WidgetHeader(trailing: "")

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(isMedium ? .title3 : .headline, design: .rounded, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(isMedium ? 1 : 2)
            }

            Spacer(minLength: 0)

            Button(intent: OpenDayDayUpIntent()) {
                Label("打开 DayDayUp", systemImage: "macwindow")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(isMedium ? 16 : 14)
        .dayDayUpWidgetGlass(transparency: glassTransparency)
    }
}

struct EmptyRhythmView: View {
    let isMedium: Bool
    let glassTransparency: Double

    var body: some View {
        VStack(alignment: .leading, spacing: isMedium ? 14 : 10) {
            WidgetHeader(trailing: isMedium ? "节奏仪表" : "本周")

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 6) {
                Text("暂无评分")
                    .font(.system(isMedium ? .title3 : .headline, design: .rounded, weight: .semibold))
                Text("创建任务后会生成学习节奏。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(isMedium ? 1 : 2)
            }

            Spacer(minLength: 0)

            Button(intent: OpenDayDayUpIntent()) {
                Label("打开 DayDayUp", systemImage: "macwindow")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(isMedium ? 16 : 14)
        .dayDayUpWidgetGlass(transparency: glassTransparency)
    }
}

enum WidgetPalette {
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let accent = Color.dayWidgetAdaptive(light: 0x3F6FA8, dark: 0x8EB8EC)
    static let warning = Color.dayWidgetAdaptive(light: 0xB46919, dark: 0xD9A15C)
    static let danger = Color.dayWidgetAdaptive(light: 0xB54848, dark: 0xE47378)
    static let success = Color.dayWidgetAdaptive(light: 0x247C5E, dark: 0x65C8A0)
    static let recovered = Color.dayWidgetAdaptive(light: 0x7A5CCF, dark: 0xA993F4)
    static let glass = Color.dayWidgetAdaptive(light: 0xEEF3F8, dark: 0x2A3340)
    static let surface = Color.dayWidgetAdaptive(light: 0xF6F8FB, dark: 0x202733)
    static let border = Color.dayWidgetAdaptive(light: 0xD8E0EA, dark: 0x374454)
    static let primaryDeep = Color.dayWidgetAdaptive(light: 0x18324D, dark: 0xC7DDF7)

    static func tint(for status: WidgetTaskStatus) -> Color {
        switch status {
        case .active: accent
        case .warning: warning
        case .overdue: danger
        case .completed: success
        case .recovered: recovered
        }
    }

    static func scoreTint(for score: Int) -> Color {
        switch score {
        case 90...100: success
        case 75..<90: accent
        case 60..<75: warning
        default: danger
        }
    }
}

private extension Color {
    static func dayWidgetAdaptive(
        light: UInt32,
        dark: UInt32,
        lightAlpha: Double = 1,
        darkAlpha: Double? = nil
    ) -> Color {
        Color(nsColor: .dayWidgetAdaptive(
            light: light,
            dark: dark,
            lightAlpha: CGFloat(lightAlpha),
            darkAlpha: CGFloat(darkAlpha ?? lightAlpha)
        ))
    }
}

private extension NSColor {
    convenience init(dayWidgetHex hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xff) / 255
        let green = CGFloat((hex >> 8) & 0xff) / 255
        let blue = CGFloat(hex & 0xff) / 255
        self.init(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }

    static func dayWidgetAdaptive(
        light: UInt32,
        dark: UInt32,
        lightAlpha: CGFloat = 1,
        darkAlpha: CGFloat = 1
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(dayWidgetHex: isDark ? dark : light, alpha: isDark ? darkAlpha : lightAlpha)
        }
    }
}

extension WidgetTodaySnapshot {
    var totalCount: Int {
        max(completedCount + incompleteCount, 1)
    }

    var hasContent: Bool {
        incompleteCount > 0 || completedCount > 0 || focusMinutes > 0
    }
}

private struct WidgetGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let transparency: Double

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let resolvedTransparency = DayDayUpWidgetShared.clampedGlassTransparency(transparency)
        let tintOpacity = min(max(0.46 - resolvedTransparency * 0.50, 0.07), 0.46)
        let highlightOpacity = 0.06 + resolvedTransparency * 0.26
        let borderOpacity = 0.34 + resolvedTransparency * 0.24
        let shadowOpacity = max(0.02, 0.08 - resolvedTransparency * 0.04)

        if #available(macOSApplicationExtension 26.0, *) {
            content
                .background {
                    shape.fill(.regularMaterial)
                    shape.fill(WidgetPalette.glass.opacity(tintOpacity))
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(highlightOpacity),
                                    WidgetPalette.accent.opacity(max(0.04, tintOpacity * 0.42)),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.screen)
                }
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(borderOpacity),
                                WidgetPalette.accent.opacity(max(0.08, tintOpacity * 0.55)),
                                WidgetPalette.border.opacity(max(0.28, tintOpacity))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
                }
                .overlay(alignment: .topLeading) {
                    shape
                        .trim(from: 0.03, to: 0.30)
                        .stroke(Color.white.opacity(highlightOpacity * 0.86), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                        .blur(radius: 0.7)
                        .padding(1)
                }
                .shadow(color: WidgetPalette.primaryDeep.opacity(shadowOpacity), radius: 5, x: 0, y: 2)
                .glassEffect(.regular.tint(WidgetPalette.glass.opacity(tintOpacity)), in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background {
                    shape.fill(.regularMaterial)
                    shape.fill(WidgetPalette.glass.opacity(tintOpacity))
                }
                .overlay {
                    shape.stroke(WidgetPalette.border.opacity(0.55), lineWidth: 1)
                }
        }
    }
}

extension View {
    func dayDayUpWidgetGlass(transparency: Double = DayDayUpWidgetShared.defaultGlassTransparency) -> some View {
        modifier(WidgetGlassModifier(cornerRadius: 22, transparency: transparency))
    }
}

#Preview("下一颗松果 Small", as: .systemSmall) {
    NextTaskWidget()
} timeline: {
    DayDayUpWidgetEntry.placeholder
}

#Preview("下一颗松果 Medium", as: .systemMedium) {
    NextTaskWidget()
} timeline: {
    DayDayUpWidgetEntry.placeholder
}

#Preview("今日篮子 Small", as: .systemSmall) {
    TodayBasketWidget()
} timeline: {
    DayDayUpWidgetEntry.placeholder
}

#Preview("今日篮子 Medium", as: .systemMedium) {
    TodayBasketWidget()
} timeline: {
    DayDayUpWidgetEntry.placeholder
}

#Preview("节奏仪表 Small", as: .systemSmall) {
    RhythmGaugeWidget()
} timeline: {
    DayDayUpWidgetEntry.placeholder
}

#Preview("节奏仪表 Medium", as: .systemMedium) {
    RhythmGaugeWidget()
} timeline: {
    DayDayUpWidgetEntry.placeholder
}

#Preview("空状态 Small", as: .systemSmall) {
    NextTaskWidget()
} timeline: {
    DayDayUpWidgetEntry.empty
}

#Preview("长任务 Medium", as: .systemMedium) {
    TodayBasketWidget()
} timeline: {
    DayDayUpWidgetEntry.longTask
}

#Preview("逾期 Medium", as: .systemMedium) {
    TodayBasketWidget()
} timeline: {
    DayDayUpWidgetEntry.overdue
}

#Preview("无评分 Small", as: .systemSmall) {
    RhythmGaugeWidget()
} timeline: {
    DayDayUpWidgetEntry.empty
}
