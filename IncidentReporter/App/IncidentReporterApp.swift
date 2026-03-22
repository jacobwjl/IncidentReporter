import SwiftUI
import SwiftData
import Sparkle

@MainActor
final class UpdaterViewModel: ObservableObject {
    let updaterController: SPUStandardUpdaterController
    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }
    func checkForUpdates() { updaterController.checkForUpdates(nil) }
    var canCheckForUpdates: Bool { updaterController.updater.canCheckForUpdates }
}

@main
struct IncidentReporterApp: App {
    let modelContainer: ModelContainer
    @StateObject private var updaterViewModel = UpdaterViewModel()

    init() {
        let schema = Schema([
            Incident.self, IncidentField.self, Report.self, ReportSection.self,
            FileAttachment.self, Tag.self, Contact.self, Deadline.self,
            ActivityLogEntry.self, ReportTemplate.self
        ])
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let storeDir = appSupport.appendingPathComponent("IncidentReporter", isDirectory: true)
        try? FileManager.default.createDirectory(at: storeDir, withIntermediateDirectories: true)
        let storeURL = storeDir.appendingPathComponent("IncidentReporter.store")
        let config = ModelConfiguration(url: storeURL)
        do {
            modelContainer = try ModelContainer(for: schema, migrationPlan: IncidentReporterMigrationPlan.self, configurations: [config])
        } catch {
            let backupURL = storeDir.appendingPathComponent("IncidentReporter-backup-\(Int(Date.now.timeIntervalSince1970)).store")
            try? FileManager.default.moveItem(at: storeURL, to: backupURL)
            for ext in ["wal", "shm"] {
                let src = storeURL.appendingPathExtension(ext)
                let dst = backupURL.appendingPathExtension(ext)
                try? FileManager.default.moveItem(at: src, to: dst)
            }
            do {
                modelContainer = try ModelContainer(for: schema, migrationPlan: IncidentReporterMigrationPlan.self, configurations: [config])
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 780, height: 520)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updaterViewModel.checkForUpdates()
                }
                .disabled(!updaterViewModel.canCheckForUpdates)
            }
        }

        Settings {
            SettingsView(updaterViewModel: updaterViewModel)
        }
        .modelContainer(modelContainer)
    }
}
