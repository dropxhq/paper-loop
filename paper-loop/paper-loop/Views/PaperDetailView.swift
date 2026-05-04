import SwiftUI
import SwiftData

struct PaperDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let paper: Paper

    @State private var navigateToSource: Card? = nil
    @State private var showReimportConfirm = false
    @State private var reimportDeleted = false

    private var sortedCards: [Card] {
        paper.cards.sorted { $0.term.lowercased() < $1.term.lowercased() }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                if reimportDeleted {
                    deletedStateView
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            paperInfoCard
                            cardsSection
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                        .padding(.bottom, 100)
                    }
                    .navigationDestination(item: $navigateToSource) { card in
                        SourceDetailView(card: card)
                    }
                    // Floating reimport button
                    VStack {
                        Spacer()
                        Button("重新导入") {
                            showReimportConfirm = true
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, 14)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("论文详情")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "重新导入将删除此论文的所有词卡",
                isPresented: $showReimportConfirm,
                titleVisibility: .visible
            ) {
                Button("删除并重新导入", role: .destructive) {
                    modelContext.delete(paper)
                    reimportDeleted = true
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("词卡将被完全移除，请前往「导入」页面重新导入此论文。")
            }
        }
    }

    // MARK: - Paper Info Card

    private var paperInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            EyebrowBadge(text: paper.arxivId)
            Text(paper.title)
                .font(Font.custom("Georgia", size: 20).weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineSpacing(3)
            HStack(spacing: 16) {
                MiniStatBox(value: "\(paper.cards.count)", label: "词卡")
                MiniStatBox(
                    value: paper.importedAt.formatted(.dateTime.month().day()),
                    label: "导入日期"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .paperCardStyle()
    }

    // MARK: - Cards Section

    private var cardsSection: some View {
        VStack(spacing: 0) {
            SectionHeader("词卡列表", badge: "\(sortedCards.count)")
                .padding(.bottom, 10)
            if sortedCards.isEmpty {
                Text("暂无词卡")
                    .foregroundStyle(Theme.textMuted)
                    .font(.system(size: 14))
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(sortedCards) { card in
                        NavigationLink(destination: SourceDetailView(card: card)) {
                            VocabRowView(card: card)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .paperCardStyle()
    }

    // MARK: - Deleted State

    private var deletedStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(Theme.primary)
            Text("词卡已删除")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
            Text("请前往「导入」页面重新导入此论文")
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("返回") {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 40)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Paper.self, Card.self, ReviewLog.self, configurations: config)
    let paper = Paper(
        arxivId: "2301.00001",
        title: "Attention Is All You Need",
        abstract: "Preview paper",
        pdfURL: URL(string: "https://arxiv.org/pdf/2301.00001")!
    )
    container.mainContext.insert(paper)
    return PaperDetailView(paper: paper)
        .modelContainer(container)
}
