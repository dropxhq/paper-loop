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
            ZStack {
                Theme.bg.ignoresSafeArea()
                Group {
                    if cards.isEmpty {
                        emptyStateView
                    } else {
                        cardListView
                    }
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
                            .foregroundStyle(Theme.primary)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 56))
                .foregroundStyle(Theme.textMuted)
            Text("暂无词汇")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
            Text("导入论文后，词汇将自动出现在这里")
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var cardListView: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if filteredCards.isEmpty {
                    Text("无匹配结果")
                        .foregroundStyle(Theme.textMuted)
                        .padding(.top, 40)
                } else {
                    ForEach(filteredCards) { card in
                        NavigationLink(destination: SourceDetailView(card: card)) {
                            VocabRowView(card: card)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

struct VocabRowView: View {
    let card: Card

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.term)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                if !card.zhHint.isEmpty {
                    Text(card.zhHint)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textMuted)
                        .lineLimit(1)
                }
                if let paperTitle = card.paper?.title {
                    Text(paperTitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textMuted.opacity(0.7))
                        .lineLimit(1)
                }
            }
            Spacer()
            typeLabel
        }
        .padding(12)
        .listItemStyle()
    }

    private var typeLabel: some View {
        let (text, color): (String, Color) = switch card.type {
        case .word: ("词", Theme.primary)
        case .phrase: ("短语", Color(red: 0.8, green: 0.45, blue: 0.1))
        case .sentence: ("句", Color(red: 0.5, green: 0.3, blue: 0.7))
        }
        return Text(text)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

#Preview {
    VocabView()
        .modelContainer(for: [Paper.self, Card.self, ReviewLog.self], inMemory: true)
}
