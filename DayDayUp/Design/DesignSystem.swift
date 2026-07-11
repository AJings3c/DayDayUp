import AppKit
import SwiftUI

enum DayColor {
    static let primary = Color.dayAdaptive(light: 0x197BBE, dark: 0x7BCBFF)
    static let primaryAction = Color.dayAdaptive(light: 0x1679B8, dark: 0x3588B8)
    static let primaryDeep = Color.dayAdaptive(light: 0x234B66, dark: 0xDDF2FF)
    static let squirrel = Color.dayAdaptive(light: 0xF09A4A, dark: 0xFFBC79)
    static let background = Color.dayAdaptive(light: 0xF7FCFF, dark: 0x21333D)
    static let workbench = Color.dayAdaptive(light: 0xFFFFFF, dark: 0x273A45)
    static let surface = Color.dayAdaptive(light: 0xEFF8FC, dark: 0x2D434E)
    static let glass = Color.dayAdaptive(light: 0xE6F5FA, dark: 0x344C57)
    static let selected = Color.dayAdaptive(light: 0xDAF2FF, dark: 0x2C5B70)
    static let text = Color.dayAdaptive(light: 0x17313F, dark: 0xF3FAFC)
    static let muted = Color.dayAdaptive(light: 0x526D7A, dark: 0xBED0D8)
    static let border = Color.dayAdaptive(light: 0xCBE4EE, dark: 0x49636E)
    static let success = Color.dayAdaptive(light: 0x137E62, dark: 0x6BDBB7)
    static let warning = Color.dayAdaptive(light: 0xAE620F, dark: 0xF5BC68)
    static let danger = Color.dayAdaptive(light: 0xC34859, dark: 0xFF929D)
    static let recovered = Color.dayAdaptive(light: 0x6B5FC2, dark: 0xC0B2FF)
    static let squirrelSoft = Color.dayAdaptive(light: 0xFFF1E4, dark: 0x58402D)
    static let focusSurface = Color.dayAdaptive(light: 0xDFF5FF, dark: 0x295469)
    static let hover = Color.dayAdaptive(light: 0xE5F5FB, dark: 0x36515D)
}

enum DayMotion {
    static let feedback = Animation.timingCurve(0.25, 1, 0.5, 1, duration: 0.14)
    static let state = Animation.timingCurve(0.22, 1, 0.36, 1, duration: 0.22)
    static let navigation = Animation.timingCurve(0.16, 1, 0.3, 1, duration: 0.24)
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
                .shadow(color: DayColor.primaryDeep.opacity(emphasized ? 0.08 : 0.04), radius: emphasized ? 6 : 3, x: 0, y: 2)
                .scaleEffect(interactive && isHovered && allowsMotion ? 1.003 : 1)
                .onHover { hovering in
                    guard interactive && allowsMotion else { return }
                    isHovered = hovering
                }
                .animation(allowsMotion ? DayMotion.feedback : nil, value: isHovered)
        }
    }

    @available(macOS 26.0, *)
    @ViewBuilder
    private func liquidGlassSurface(_ content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let allowsMotion = glassMotionEnabled && !reduceMotion
        let hoverLift = interactive && isHovered && allowsMotion
        let tintOpacity = panelTintOpacity(emphasized: emphasized)
        let surface = content
            .background {
                shape.fill(.regularMaterial)
                shape.fill(DayColor.glass.opacity(tintOpacity))
            }
            .overlay {
                shape
                    .strokeBorder(DayColor.border.opacity(isHovered ? 0.82 : 0.58), lineWidth: 1)
            }
            .shadow(color: DayColor.primaryDeep.opacity(hoverLift ? 0.10 : (emphasized ? 0.07 : 0.03)), radius: hoverLift ? 7 : (emphasized ? 5 : 2), x: 0, y: 2)
            .scaleEffect(hoverLift ? 1.003 : 1)
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
                .animation(DayMotion.state, value: isHovered)
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
                        Rectangle().fill(.ultraThinMaterial)
                        Rectangle().fill(DayColor.background.opacity(0.97 - glassTransparency * 0.16))
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
                    shape.fill(DayColor.workbench.opacity(0.94 - glassTransparency * 0.38))
                }
                .overlay {
                    shape.strokeBorder(DayColor.border.opacity(0.76 - glassTransparency * 0.30), lineWidth: 1)
                }
        }
    }
}

struct AcornProgressTrack: View {
    let progress: Double
    var tint: Color = DayColor.primary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let markerCount = 9

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("松果进度", systemImage: "leaf.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DayColor.muted)
                Spacer()
                Text(progress.percentText)
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .foregroundStyle(tint)
            }

            GeometryReader { proxy in
                let clamped = min(max(progress, 0), 1)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DayColor.border.opacity(0.65))
                        .frame(height: 3)
                    Capsule()
                        .fill(tint)
                        .frame(width: max(3, proxy.size.width * clamped), height: 3)

                    HStack(spacing: 0) {
                        ForEach(0..<markerCount, id: \.self) { index in
                            let threshold = Double(index) / Double(markerCount - 1)
                            Circle()
                                .fill(clamped >= threshold ? tint : DayColor.workbench)
                                .overlay(Circle().stroke(clamped >= threshold ? tint : DayColor.border, lineWidth: 1.5))
                                .frame(width: index == markerCount - 1 ? 12 : 9, height: index == markerCount - 1 ? 12 : 9)
                            if index < markerCount - 1 {
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                .frame(height: 14)
                .animation(reduceMotion ? nil : DayMotion.state, value: clamped)
            }
            .frame(height: 14)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("任务完成度 \(progress.percentText)")
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
        case .active:
            return feedbackPhase ? 1.022 : 1
        case .overdue, .empty:
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
        case .completed, .recovered, .warning, .active:
            withAnimation(DayMotion.state) {
                feedbackPhase = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(DayMotion.state) {
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
        case .empty:
            break
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    var tint: Color = DayColor.primary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(DayColor.muted)
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : DayMotion.state, value: value)
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
        formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
    }
}

extension Double {
    var percentText: String {
        "\(Int((self * 100).rounded()))%"
    }
}
