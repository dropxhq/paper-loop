import SwiftUI
import SwiftData

struct VocabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Card.term)
    private var cards: [Card]

    @State private var searchText = ""
    @State private var selectedType: CardType? = nil

    private var filteredCards: [Card] {
        cards.filter { card in
            let matchesSearch = searchText.isEmpty ||
                card.term.localizedCaseInsensitiveContains(searchText) ||
                card.zhHint.localizedCaseInsensitiveContains(searchText)
            let matchesType = selectedType == nil || card.type == selectedType
            return matchesSearch && matchesType
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    emptyStateView
                } else {
                    cardListView
                }
            }
            .navigationTitle("词表")
            .searchable(text: $searchText, prompt: "搜索词汇")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("全部") { selectedType = nil }
                        Button("单词") { selectedType = .word }
                        Button("短语") { selectedType = .phrase }
                        Button("句子") { selectedType = .sentence }
                    } label: {
                        Label("筛选", systemImage: selectedType == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("暂无词汇")
                .font(.title2.bold())
            Text("导入论文后，词汇将自动出现在这里")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var cardListView: some View {
        List {
            if filteredCards.isEmpty {
                Text("无匹配结果")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(filteredCards) { card in
                    NavigationLink(destination: SourceDetailView(card: card)) {
                        VocabRowView(card: card)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

struct VocabRowView: View {
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(card.term)
                    .font(.headline)
                Spacer()
                typeLabel
            }
            if !card.zhHint.isEmpty {
                Text(card.zhHint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let paperTitle = card.paper?.title {
                Text(paperTitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }

    private var typeLabel: some View {
        let (text, color): (String, Color) = switch card.type {
        case .word: ("词", .blue)
        case .phrase: ("短语", .orange)
        case .sentence: ("句", .purple)
        }
        return Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

#Preview {
    VocabView()
        .modelContainer(for: [Paper.self, Card.self, ReviewLog.self], inMemory: true)
}
