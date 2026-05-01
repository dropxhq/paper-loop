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
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        // Stats card
                        VStack(spacing: 10) {
                            SectionHeader("学习统计")
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                MiniStatBox(value: "\(cards.count)", label: "词卡总数")
                                MiniStatBox(value: "\(todayReviews)", label: "今日复习")
                                MiniStatBox(value: "\(masteredCards)", label: "已掌握")
                            }
                        }
                        .padding(14)
                        .paperCardStyle()

                        // Papers card
                        VStack(spacing: 0) {
                            SectionHeader("已导入论文", badge: "\(papers.count)")
                                .padding(.bottom, 10)
                            if papers.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "doc.badge.plus")
                                        .font(.system(size: 36))
                                        .foregroundStyle(Theme.textMuted)
                                    Text("还没有导入论文")
                                        .foregroundStyle(Theme.textMuted)
                                        .font(.system(size: 14))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                            } else {
                                ForEach(papers.sorted(by: { $0.importedAt > $1.importedAt })) { paper in
                                    PaperRowView(paper: paper)
                                        .padding(.top, paper == papers.sorted(by: { $0.importedAt > $1.importedAt }).first ? 0 : 8)
                                }
                            }
                        }
                        .padding(14)
                        .paperCardStyle()

                        // Settings card
                        VStack(spacing: 0) {
                            SectionHeader("设置")
                                .padding(.bottom, 10)
                            settingsRow(title: "字体大小", subtitle: "正文 15pt")
                            settingsRow(title: "朗读速度", subtitle: "正常")
                            settingsRow(title: "深色模式", subtitle: "跟随系统")
                        }
                        .padding(14)
                        .paperCardStyle()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func settingsRow(title: String, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(12)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.r18))
        .overlay(RoundedRectangle(cornerRadius: Theme.r18).stroke(Theme.line, lineWidth: 1))
        .padding(.top, 4)
    }
}

// MARK: - Subviews

private struct PaperRowView: View {
    let paper: Paper

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(paper.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
            Text(paper.arxivId)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
            if !paper.cards.isEmpty {
                Text("\(paper.cards.count) 张词卡")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.r18))
        .overlay(RoundedRectangle(cornerRadius: Theme.r18).stroke(Theme.line, lineWidth: 1))
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [Paper.self, Card.self, ReviewLog.self], inMemory: true)
}
