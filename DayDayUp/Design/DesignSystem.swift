import AppKit
import SwiftUI

enum DayColor {
    static let primary = Color.dayAdaptive(light: 0x3F6FA8, dark: 0x8EB8EC)
    static let primaryDeep = Color.dayAdaptive(light: 0x18324D, dark: 0xC7DDF7)
    static let squirrel = Color.dayAdaptive(light: 0xB56A2A, dark: 0xD58A47)
    static let background = Color.dayAdaptive(light: 0xF7F9FF, dark: 0x11151B)
    static let workbench = Color.dayAdaptive(light: 0xFFFFFF, dark: 0x1A2029)
    static let surface = Color.dayAdaptive(light: 0xF6F8FB, dark: 0x202733)
    static let glass = Color.dayAdaptive(light: 0xEEF3F8, dark: 0x2A3340)
    static let selected = Color.dayAdaptive(light: 0xE8F0FA, dark: 0x25384D)
    static let text = Color.dayAdaptive(light: 0x15202B, dark: 0xEDF3FA)
    static let muted = Color.dayAdaptive(light: 0x5D6976, dark: 0xA7B2C0)
    static let border = Color.dayAdaptive(light: 0xD8E0EA, dark: 0x374454)
    static let success = Color.dayAdaptive(light: 0x247C5E, dark: 0x65C8A0)
    static let warning = Color.dayAdaptive(light: 0xB46919, dark: 0xD9A15C)
    static let danger = Color.dayAdaptive(light: 0xB54848, dark: 0xE47378)
    static let recovered = Color.dayAdaptive(light: 0x7A5CCF, dark: 0xA993F4)
}

enum DaySpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

private struct DayGlassTransparencyKey: EnvironmentKey {
    static let defaultValue = AppSettings.defaultGlassTransparency
}

private struct DayGlassMotionEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var dayGlassTransparency: Double {
        get { self[DayGlassTransparencyKey.self] }
        set { self[DayGlassTransparencyKey.self] = AppSettings.clampedGlassTransparency(newValue) }
    }

    var dayGlassMotionEnabled: Bool {
        get { self[DayGlassMotionEnabledKey.self] }
        set { self[DayGlassMotionEnabledKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xff) / 255
        let g = Double((hex >> 8) & 0xff) / 255
        let b = Double(hex & 0xff) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    static func dayAdaptive(
        light: UInt32,
        dark: UInt32,
        lightAlpha: Double = 1,
        darkAlpha: Double? = nil
    ) -> Color {
        Color(nsColor: .dayAdaptive(
            light: light,
            dark: dark,
            lightAlpha: CGFloat(lightAlpha),
            darkAlpha: CGFloat(darkAlpha ?? lightAlpha)
        ))
    }
}

private extension NSColor {
    convenience init(dayHex hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xff) / 255
        let g = CGFloat((hex >> 8) & 0xff) / 255
        let b = CGFloat(hex & 0xff) / 255
        self.init(calibratedRed: r, green: g, blue: b, alpha: alpha)
    }

    static func dayAdaptive(
        light: UInt32,
        dark: UInt32,
        lightAlpha: CGFloat = 1,
        darkAlpha: CGFloat = 1
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(dayHex: isDark ? dark : light, alpha: isDark ? darkAlpha : lightAlpha)
        }
    }
}

extension TaskStatus {
    var color: Color {
        switch self {
        case .active: DayColor.muted
        case .warning: DayColor.warning
        case .overdue: DayColor.danger
        case .completed: DayColor.success
        case .recovered: DayColor.recovered
        }
    }

    var backgroundColor: Color {
        color.opacity(0.12)
    }
}

extension AchievementKind {
    var tint: Color {
        switch self {
        case .firstTaskCompleted, .firstOnTimeClosure, .firstEarlyClosure, .cleanWeek, .monthlyClosureRate:
            DayColor.success
        case .firstRecoveredClosure:
            DayColor.recovered
        case .focusStreak3, .focusStreak7, .focusStreak14, .totalFocusOneHour, .totalFocusTenHours:
            DayColor.primary
        case .reviewStreak3:
            DayColor.squirrel
        }
    }
}

private struct DayGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let interactive: Bool
    let emphasized: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dayGlassTransparency) private var glassTransparency
    @Environment(\.dayGlassMotionEnabled) private var glassMotionEnabled
    @State private var isHovered = false
    @State private var glassID = UUID()
    @Namespace private var glassNamespace

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(DayColor.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(DayColor.border, lineWidth: 1)
                )
        } else if #available(macOS 26.0, *) {
            liquidGlassSurface(content)
        } else {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let tintOpacity = panelTintOpacity(emphasized: emphasized)
            let allowsMotion = glassMotionEnabled && !reduceMotion

            content
                .background {
                    shape.fill(.regularMaterial)
                    shape.fill(DayColor.glass.opacity(tintOpacity))
                }
                .overlay(
                    shape
                        .stroke(DayColor.border.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: DayColor.primaryDeep.opacity(emphasized ? 0.10 : 0.05), radius: emphasized ? 10 : 5, x: 0, y: emphasized ? 5 : 2)
                .scaleEffect(interactive && isHovered && allowsMotion ? 1.006 : 1)
                .onHover { hovering in
                    guard interactive && allowsMotion else { return }
                    isHovered = hovering
                }
                .animation(allowsMotion ? .easeOut(duration: 0.18) : nil, value: isHovered)
        }
    }

    @available(macOS 26.0, *)
    @ViewBuilder
    private func liquidGlassSurface(_ content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let allowsMotion = glassMotionEnabled && !reduceMotion
        let hoverLift = interactive && isHovered && allowsMotion
        let tintOpacity = panelTintOpacity(emphasized: emphasized)
        let highlightOpacity = 0.06 + glassTransparency * 0.26

        let surface = content
            .background {
                shape.fill(.regularMaterial)
                shape.fill(DayColor.glass.opacity(tintOpacity))
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? highlightOpacity + 0.10 : highlightOpacity),
                                DayColor.primary.opacity(isHovered ? 0.10 : 0.04),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
            }
            .overlay {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.72 : 0.46),
                                DayColor.primary.opacity(isHovered ? 0.24 : 0.10),
                                DayColor.border.opacity(isHovered ? 0.52 : 0.36)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHovered ? 1.2 : 0.9
                    )
            }
            .overlay(alignment: .topLeading) {
                shape
                    .trim(from: 0.03, to: 0.33)
                    .stroke(Color.white.opacity(isHovered ? 0.52 : 0.28), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                    .blur(radius: isHovered ? 0.2 : 0.7)
                    .padding(1)
            }
            .shadow(color: DayColor.primaryDeep.opacity(hoverLift ? 0.17 : (emphasized ? 0.10 : 0.05)), radius: hoverLift ? 14 : (emphasized ? 10 : 5), x: 0, y: hoverLift ? 7 : (emphasized ? 5 : 2))
            .scaleEffect(hoverLift ? 1.008 : 1)
            .contentShape(shape)

        if allowsMotion {
            surface
                .glassEffect(
                    interactive
                        ? .regular.tint(DayColor.glass.opacity(tintOpacity)).interactive()
                        : .regular.tint(DayColor.glass.opacity(tintOpacity)),
                    in: .rect(cornerRadius: cornerRadius)
                )
                .glassEffectID(glassID, in: glassNamespace)
                .glassEffectTransition(interactive ? .matchedGeometry : .materialize)
                .onHover { hovering in
                    guard interactive else { return }
                    isHovered = hovering
                }
                .animation(.easeOut(duration: 0.20), value: isHovered)
        } else {
            surface
                .glassEffect(
                    .regular.tint(DayColor.glass.opacity(tintOpacity)),
                    in: .rect(cornerRadius: cornerRadius)
                )
        }
    }

    private func panelTintOpacity(emphasized: Bool) -> Double {
        let base = emphasized ? 0.58 : 0.46
        let minimum = emphasized ? 0.10 : 0.07
        return min(max(base - glassTransparency * 0.50, minimum), base)
    }
}

private struct DayPageBackgroundModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dayGlassTransparency) private var glassTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(DayColor.background)
        } else {
            content
                .background {
                    ZStack {
                        Rectangle().fill(.regularMaterial)
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        DayColor.glass.opacity(0.78 - glassTransparency * 0.64),
                                        DayColor.primary.opacity(0.24 - glassTransparency * 0.19),
                                        DayColor.background.opacity(0.46 - glassTransparency * 0.34)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .ignoresSafeArea()
                }
        }
    }
}

private struct DayPanelModifier: ViewModifier {
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dayGlassTransparency) private var glassTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency {
            content
                .background(DayColor.workbench.opacity(0.92), in: shape)
                .overlay(shape.stroke(DayColor.border.opacity(0.82), lineWidth: 1))
        } else {
            content
                .background {
                    shape.fill(.regularMaterial)
                    shape.fill(DayColor.workbench.opacity(0.86 - glassTransparency * 0.70))
                }
                .overlay {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.52 - glassTransparency * 0.18),
                                DayColor.border.opacity(0.76 - glassTransparency * 0.42)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                }
        }
    }
}

extension View {
    func dayGlass(cornerRadius: CGFloat = 16, interactive: Bool = false) -> some View {
        modifier(DayGlassModifier(cornerRadius: cornerRadius, interactive: interactive, emphasized: true))
    }

    func dayLiquidPanel(cornerRadius: CGFloat = 14, interactive: Bool = false, emphasized: Bool = false) -> some View {
        modifier(DayGlassModifier(cornerRadius: cornerRadius, interactive: interactive, emphasized: emphasized))
    }

    func dayPanel(cornerRadius: CGFloat = 12) -> some View {
        modifier(DayPanelModifier(cornerRadius: cornerRadius))
    }

    func dayPageBackground() -> some View {
        modifier(DayPageBackgroundModifier())
    }

    func dayGlassMotionEnabled(_ enabled: Bool) -> some View {
        environment(\.dayGlassMotionEnabled, enabled)
    }
}

struct StatusBadge: View {
    let status: TaskStatus

    var body: some View {
        Label(status.title, systemImage: status.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.color)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(status.backgroundColor, in: Capsule())
            .accessibilityLabel(status.accessibilityText)
    }
}

enum SquirrelMood {
    case active
    case warning
    case overdue
    case completed
    case recovered
    case empty

    init(status: TaskStatus?) {
        switch status {
        case .active: self = .active
        case .warning: self = .warning
        case .overdue: self = .overdue
        case .completed: self = .completed
        case .recovered: self = .recovered
        case nil: self = .empty
        }
    }

    var assetName: String {
        switch self {
        case .active: "squirrel-active"
        case .warning: "squirrel-warning"
        case .overdue: "squirrel-overdue"
        case .completed: "squirrel-completed"
        case .recovered: "squirrel-recovered"
        case .empty: "squirrel-empty"
        }
    }

    var accessibilityText: String {
        switch self {
        case .active: "小松鼠拿着笔记本，正在专注执行"
        case .warning: "小松鼠拿着时钟，提醒任务接近截止"
        case .overdue: "小松鼠叉腰跺脚，旁边是空篮子，表示逾期未完成"
        case .completed: "小松鼠开心抱着松果，表示任务完成"
        case .recovered: "小松鼠把松果放进带紫色标记的篮子，表示逾期后补完成"
        case .empty: "小松鼠拿着空篮子，等待新任务"
        }
    }
}

struct SquirrelImage: View {
    var mood: SquirrelMood = .active
    var size: CGFloat = 176
    var animated = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var feedbackPhase = false
    @State private var shakePhase: CGFloat = 0

    var body: some View {
        Group {
            if let image = NSImage(named: mood.assetName) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else if let image = NSImage(named: "AppLogo") {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "leaf.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(DayColor.squirrel)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(feedbackScale)
        .offset(x: shakeOffset)
        .shadow(color: DayColor.primaryDeep.opacity(0.12), radius: 14, x: 0, y: 8)
        .accessibilityLabel("DayDayUp \(mood.accessibilityText)")
        .onAppear(perform: playFeedback)
        .onChange(of: mood.assetName) { _, _ in
            playFeedback()
        }
    }

    private var feedbackScale: CGFloat {
        guard animated, !reduceMotion else { return 1 }
        switch mood {
        case .completed, .recovered:
            return feedbackPhase ? 1.045 : 1
        case .warning:
            return feedbackPhase ? 1.018 : 1
        case .active, .overdue, .empty:
            return 1
        }
    }

    private var shakeOffset: CGFloat {
        guard animated, !reduceMotion, mood == .overdue else { return 0 }
        return shakePhase
    }

    private func playFeedback() {
        guard animated, !reduceMotion else { return }

        switch mood {
        case .completed, .recovered, .warning:
            withAnimation(.easeOut(duration: 0.18)) {
                feedbackPhase = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    feedbackPhase = false
                }
            }
        case .overdue:
            let offsets: [CGFloat] = [-5, 5, -3, 3, 0]
            for (index, offset) in offsets.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.055) {
                    withAnimation(.easeInOut(duration: 0.055)) {
                        shakePhase = offset
                    }
                }
            }
        case .active, .empty:
            break
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    var tint: Color = DayColor.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(DayColor.muted)
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(DayColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .dayPanel()
    }
}

extension Date {
    func dayKey(calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: self)
    }

    func monthStart(calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .month, for: self)?.start ?? dayKey(calendar: calendar)
    }

    func formattedShortDate() -> String {
        formatted(.dateTime.month(.twoDigits).day(.twoDigits))
    }

    func formattedDateTime() -> String {
        formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }
}

extension Double {
    var percentText: String {
        "\(Int((self * 100).rounded()))%"
    }
}
