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
        }
        .modelContainer(sharedModelContainer)
    }
}
