import Foundation
import SwiftData

struct CardIntroductionService {

    /// 检查今日已引入新卡数量，若不足 dailyLimit 则从 pending 池按优先级补充。
    /// 优先级公式：valueScore × log₂(occurrenceCount + 1)
    @MainActor
    static func introduceIfNeeded(context: ModelContext, dailyLimit: Int) {
        let calendar = Calendar.current

        guard let allCards = try? context.fetch(FetchDescriptor<Card>()) else { return }

        // 今日已引入数量
        let todayCount = allCards.filter { card in
            guard let introducedAt = card.introducedAt else { return false }
            return calendar.isDateInToday(introducedAt)
        }.count

        let remaining = max(0, dailyLimit - todayCount)
        guard remaining > 0 else { return }

        // 从 pending 池取出并按优先级排序
        let pendingCards = allCards.filter { $0.introducedAt == nil }
        let sorted = pendingCards.sorted { a, b in
            let aScore = Double(a.valueScore) * log2(Double(a.occurrences.count) + 1)
            let bScore = Double(b.valueScore) * log2(Double(b.occurrences.count) + 1)
            return aScore > bScore
        }

        // 引入 top-N 张
        let now = Date()
        for card in sorted.prefix(remaining) {
            card.introducedAt = now
            card.nextReviewAt = now
        }

        try? context.save()
    }
}
