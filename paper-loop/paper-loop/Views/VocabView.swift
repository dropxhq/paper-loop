import SwiftUI
import SwiftData

// MARK: - Alphabet grouping helpers

private let kAlphabetLetters: [String] = (65...90).map { String(UnicodeScalar($0)!) } + ["#"]

private func groupLetter(for term: String) -> String {
    guard let first = term.first else { return "#" }
    let upper = String(first).uppercased()
    return upper >= "A" && upper <= "Z" ? upper : "#"
}

// MARK: - VocabView

struct VocabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Card.term)
    private var cards: [Card]

    @State private var searchText = ""
    @State private var selectedType: CardType? = nil
    @State private var isEditing = false
    @State private var selectedCards: Set<PersistentIdentifier> = []
    @State private var showDeleteConfirm = false
    @State private var draggingLetter: String? = nil

    // MARK: - Filtered & Grouped data

    private var filteredCards: [Card] {
        cards.filter { card in
            let matchesSearch = searchText.isEmpty ||
                card.term.localizedCaseInsensitiveContains(searchText) ||
                card.zhHint.localizedCaseInsensitiveContains(searchText)
            let matchesType = selectedType == nil || card.type == selectedType
            return matchesSearch && matchesType
        }
    }

    /// Groups filteredCards by first letter, ordered A-Z then #.
    private var groupedCards: [(letter: String, cards: [Card])] {
        var dict: [String: [Card]] = [:]
        for card in filteredCards {
            let letter = groupLetter(for: card.term)
            dict[letter, default: []].append(card)
        }
        let sorted = kAlphabetLetters.compactMap { letter -> (String, [Card])? in
            guard let group = dict[letter], !group.isEmpty else { return nil }
            return (letter, group)
        }
        return sorted
    }

    /// Letters that actually have cards, for the index bar.
    private var availableLetters: [String] {
        groupedCards.map(\.letter)
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

    // MARK: - Grouped list with alphabet index

    private var cardListView: some View {
        ZStack(alignment: .trailing) {
            if filteredCards.isEmpty {
                Text("无匹配结果")
                    .foregroundStyle(Theme.textMuted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 40)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: []) {
                            // When searching, show flat list; otherwise show grouped
                            if !searchText.isEmpty {
                                flatList
                            } else {
                                groupedList
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .overlay(alignment: .trailing) {
                        // Show index bar only when not searching and not editing
                        if searchText.isEmpty && !isEditing && availableLetters.count > 1 {
                            AlphabetIndexBar(
                                activeLetters: Set(availableLetters),
                                draggingLetter: $draggingLetter
                            ) { letter in
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    proxy.scrollTo("section-\(letter)", anchor: .top)
                                }
                            }
                            .padding(.trailing, 4)
                        }
                    }
                }
            }

            // Floating letter indicator shown during drag
            if let letter = draggingLetter {
                Text(letter)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(Theme.primary.opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder
    private var groupedList: some View {
        ForEach(groupedCards, id: \.letter) { group in
            Color.clear
                .frame(height: 0)
                .id("section-\(group.letter)")
            ForEach(group.cards) { card in
                cardRow(card)
                    .padding(.bottom, 8)
            }
        }
    }

    @ViewBuilder
    private var flatList: some View {
        ForEach(filteredCards) { card in
            cardRow(card)
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private func cardRow(_ card: Card) -> some View {
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

// MARK: - Alphabet Index Bar

struct AlphabetIndexBar: View {
    /// Letters that actually have content (used for highlighting & scrolling).
    let activeLetters: Set<String>
    @Binding var draggingLetter: String?
    let onSelect: (String) -> Void

    /// Always show the full alphabet so spacing stays consistent.
    private let allLetters: [String] = kAlphabetLetters

    var body: some View {
        VStack(spacing: 2) {
            ForEach(allLetters, id: \.self) { letter in
                let isActive = activeLetters.contains(letter)
                Text(letter)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(
                        draggingLetter == letter
                            ? Theme.primary
                            : isActive ? Theme.textMuted : Theme.textMuted.opacity(0.3)
                    )
                    .frame(width: 22, height: 14)
                    .contentShape(Rectangle())
            }
        }
        .frame(width: 22)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let itemHeight: CGFloat = 16 // spacing(2) + height(14)
                    let index = max(0, min(allLetters.count - 1, Int(value.location.y / itemHeight)))
                    let letter = allLetters[index]
                    guard activeLetters.contains(letter) else { return }
                    if draggingLetter != letter {
                        draggingLetter = letter
                        onSelect(letter)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
                .onEnded { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        draggingLetter = nil
                    }
                }
        )
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
