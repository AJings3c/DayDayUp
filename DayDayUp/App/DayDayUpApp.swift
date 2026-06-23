import AppKit
import SwiftData
import SwiftUI

@main
struct DayDayUpApp: App {
    private let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try DayDayUpModelStore.makeContainer()
            DayDayUpNotificationRouter.shared.register()
        } catch {
            fatalError("Unable to create DayDayUp model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup("DayDayUp", id: "main") {
            AppBootstrapView()
                .modelContainer(modelContainer)
                .frame(minWidth: 1500, minHeight: 820)
                .background(ApplicationIconAppearanceSync())
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1600, height: 920)
        .defaultLaunchBehavior(.presented)
        .restorationBehavior(.disabled)
        .commands {
            CommandGroup(after: .newItem) {
                Button("新建任务") {
                    NotificationCenter.default.post(name: .dayDayUpNewTask, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }

        MenuBarExtra {
            MenuBarCountdownView()
                .modelContainer(modelContainer)
        } label: {
            Label("DayDayUp", systemImage: "timer")
        }
        .menuBarExtraStyle(.window)
    }
}

enum DayDayUpModelStore {
    static let directoryName = "DayDayUp"
    static let storeFileName = "DayDayUp.store"

    static var applicationSupportDirectory: URL {
        get throws {
            let baseURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return baseURL.appendingPathComponent(directoryName, isDirectory: true)
        }
    }

    static var storeURL: URL {
        get throws {
            try applicationSupportDirectory.appendingPathComponent(storeFileName, isDirectory: false)
        }
    }

    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            LearningTask.self,
            LearningSession.self,
            TaskEvent.self,
            AchievementRecord.self,
            ActiveFocusState.self,
            AppSettings.self
        ])
        let url = try storeURL
        try prepareStoreDirectory(for: url)
        let configuration = ModelConfiguration("DayDayUp", schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func prepareStoreDirectory(for url: URL) throws {
        let fileManager = FileManager.default
        let directoryURL = url.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try migrateLegacyDefaultStoreIfNeeded(to: url)
    }

    private static func migrateLegacyDefaultStoreIfNeeded(to storeURL: URL) throws {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: storeURL.path) else { return }

        let legacyStoreURL = storeURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("default.store", isDirectory: false)
        guard fileManager.fileExists(atPath: legacyStoreURL.path) else { return }

        for suffix in ["", "-wal", "-shm"] {
            let sourceURL = URL(fileURLWithPath: legacyStoreURL.path + suffix)
            let destinationURL = URL(fileURLWithPath: storeURL.path + suffix)
            guard fileManager.fileExists(atPath: sourceURL.path),
                  !fileManager.fileExists(atPath: destinationURL.path) else {
                continue
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }
    }
}

private struct ApplicationIconAppearanceSync: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                ApplicationIconController.apply(colorScheme)
            }
            .onChange(of: colorScheme) { _, newValue in
                ApplicationIconController.apply(newValue)
            }
    }
}

struct ApplicationAppearanceSync: View {
    let mode: AppAppearanceMode

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                ApplicationAppearanceController.apply(mode)
            }
            .onChange(of: mode) { _, newMode in
                ApplicationAppearanceController.apply(newMode)
            }
    }
}

@MainActor
private enum ApplicationAppearanceController {
    static func apply(_ mode: AppAppearanceMode) {
        switch mode {
        case .system:
            NSApplication.shared.appearance = nil
        case .light:
            NSApplication.shared.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

@MainActor
private enum ApplicationIconController {
    static func apply(_ colorScheme: ColorScheme) {
        let assetName = colorScheme == .dark ? "AppIconRuntimeDark" : "AppIconRuntimeLight"
        guard let image = NSImage(named: assetName) else {
            return
        }

        NSApplication.shared.applicationIconImage = image
    }
}

extension Notification.Name {
    static let dayDayUpNewTask = Notification.Name("DayDayUpNewTask")
    static let dayDayUpStartTask = Notification.Name("DayDayUpStartTask")
    static let dayDayUpOpenTaskFromNotification = Notification.Name("DayDayUpOpenTaskFromNotification")
}
