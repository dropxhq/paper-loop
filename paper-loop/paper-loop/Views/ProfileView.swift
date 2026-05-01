import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var papers: [Paper]
    @Query private var cards: [Card]
    @Query private var reviewLogs: [ReviewLog]

    private var todayReviews: Int {
        let calendar = Calendar.current
        return reviewLogs.filter { calendar.isDateInToday($0.reviewedAt) }.count
    }

    private var masteredCards: Int {
        cards.filter { $0.repetitions >= 3 }.count
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Stats Section
                Section {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(value: "\(papers.count)", label: "已导入论文")
                        StatCard(value: "\(cards.count)", label: "词卡总数")
                        StatCard(value: "\(todayReviews)", label: "今日复习")
                        StatCard(value: "\(masteredCards)", label: "已掌握")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("学习统计")
                }

                // MARK: - Papers Section
                Section {
                    if papers.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "doc.badge.plus")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.secondary)
                                Text("还没有导入论文")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 12)
                            Spacer()
                        }
                    } else {
                        ForEach(papers.sorted(by: { $0.importedAt > $1.importedAt })) { paper in
                            PaperRowView(paper: paper)
                        }
                    }
                } header: {
                    Text("已导入论文")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的")
        }
    }
}

// MARK: - Subviews

private struct StatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct PaperRowView: View {
    let paper: Paper

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(paper.title)
                .font(.subheadline)
                .lineLimit(2)
            HStack {
                Text(paper.arxivId)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(paper.importedAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if !paper.cards.isEmpty {
                Text("\(paper.cards.count) 张词卡")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [Paper.self, Card.self, ReviewLog.self], inMemory: true)
}
