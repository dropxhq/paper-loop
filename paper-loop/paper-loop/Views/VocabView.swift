import SwiftUI
import SwiftData

struct VocabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Card.term)
    private var cards: [Card]

    @State private var searchText = ""
    @State private var selectedType: CardType? = nil
    @State private var isEditing = false
    @State private var selectedCards: Set<PersistentIdentifier> = []
    @State private var showDeleteConfirm = false

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
                ToolbarItem(placement: .topBarLeading) {
                    if isEditing {
                        Button(selectedCards.count == filteredCards.count ? "取消全选" : "全选") {
                            if selectedCards.count == filteredCards.count {
                                selectedCards.removeAll()
                            } else {
                                selectedCards = Set(filteredCards.map(\.persistentModelID))
                            }
                        }
                        .foregroundStyle(Theme.primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                        HStack(spacing: 16) {
                            Button(role: .destructive) {
                                if !selectedCards.isEmpty { showDeleteConfirm = true }
                            } label: {
                                Label("删除", systemImage: "trash")
                                    .foregroundStyle(selectedCards.isEmpty ? Theme.textMuted : .red)
                            }
                            .disabled(selectedCards.isEmpty)
                            Button("完成") {
                                isEditing = false
                                selectedCards.removeAll()
                            }
                            .foregroundStyle(Theme.primary)
                        }
                    } else {
                        HStack(spacing: 16) {
                            Button {
                                isEditing = true
                            } label: {
                                Text("管理")
                                    .foregroundStyle(Theme.primary)
                            }
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
            .confirmationDialog(
                "删除 \(selectedCards.count) 张词卡？",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    for card in filteredCards where selectedCards.contains(card.persistentModelID) {
                        modelContext.delete(card)
                    }
                    selectedCards.removeAll()
                    isEditing = false
                }
                Button("取消", role: .cancel) {}
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
                        if isEditing {
                            Button {
                                let id = card.persistentModelID
                                if selectedCards.contains(id) {
                                    selectedCards.remove(id)
                                } else {
                                    selectedCards.insert(id)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selectedCards.contains(card.persistentModelID) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedCards.contains(card.persistentModelID) ? Theme.primary : Theme.textMuted)
                                        .font(.system(size: 22))
                                    VocabRowView(card: card)
                                }
                            }
                            .buttonStyle(.plain)
                        } else {
                            NavigationLink(destination: SourceDetailView(card: card)) {
                                VocabRowView(card: card)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    modelContext.delete(card)
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
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
                if let paperTitle = card.occurrences.first?.paper?.title {
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
        let (text, color): (LocalizedStringKey, Color) = switch card.type {
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
        .modelContainer(for: [Paper.self, Card.self, Occurrence.self, ReviewLog.self], inMemory: true)
}
