import SwiftUI
import SwiftData

@main
struct paper_loopApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Paper.self,
            Card.self,
            ReviewLog.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
