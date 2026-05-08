import SwiftUI
import SwiftData

@main
struct paper_loopApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Paper.self,
            Card.self,
            Occurrence.self,
            ReviewLog.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        func makeContainer() throws -> ModelContainer {
            try ModelContainer(for: schema, configurations: [modelConfiguration])
        }

        func destroyStore() {
            let storeURL = modelConfiguration.url
            let shmURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
            let walURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
            for url in [storeURL, shmURL, walURL] {
                try? FileManager.default.removeItem(at: url)
            }
        }

        do {
            return try makeContainer()
        } catch {
            // Schema incompatible — destroy all data and rebuild
            destroyStore()
            do {
                return try makeContainer()
            } catch {
                fatalError("Could not create ModelContainer even after destroying data: \(error)")
            }
        }
    }()

    @AppStorage("appColorScheme") private var appColorScheme = "auto"

    private var preferredScheme: ColorScheme? {
        switch appColorScheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(preferredScheme)
                .task { runIntroducedAtMigrationIfNeeded() }
        }
        .modelContainer(sharedModelContainer)
    }

    /// 一次性迁移：为已有复习记录的卡片设置 introducedAt，新卡保持 nil（pending）。
    @MainActor
    private func runIntroducedAtMigrationIfNeeded() {
        let key = "migration_introducedAt_v1_done"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let context = sharedModelContainer.mainContext
        let cards = (try? context.fetch(FetchDescriptor<Card>())) ?? []
        for card in cards {
            if card.introducedAt != nil { continue }
            // repetitions==0 && interval==0 → 从未成功复习，保持 pending (nil)
            if card.repetitions == 0 && card.interval == 0 {
                card.introducedAt = nil
            } else {
                card.introducedAt = Date()
            }
        }
        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }
}
