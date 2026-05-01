import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ImportView(selectedTab: $selectedTab)
                .tabItem {
                    Label("导入", systemImage: "arrow.down.doc")
                }
                .tag(0)
            ReviewView()
                .tabItem {
                    Label("复习", systemImage: "rectangle.on.rectangle")
                }
                .tag(1)
            VocabView()
                .tabItem {
                    Label("词表", systemImage: "list.bullet")
                }
                .tag(2)
            ProfileView()
                .tabItem {
                    Label("我的", systemImage: "person")
                }
                .tag(3)
        }
        .tint(Theme.primary)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Paper.self, Card.self, ReviewLog.self], inMemory: true)
}
