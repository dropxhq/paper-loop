import Foundation
import SwiftData

enum CardType: String, Codable {
    case word
    case phrase
    case sentence
}

@Model
final class Card {
    var id: UUID
    var term: String   // lemma (word/phrase base form)
    var type: CardType
    var zhHint: String
    var valueScore: Int

    var nextReviewAt: Date
    var easeFactor: Double
    var interval: Int
    var repetitions: Int

    @Relationship(deleteRule: .cascade, inverse: \Occurrence.card)
    var occurrences: [Occurrence] = []

    @Relationship(deleteRule: .cascade, inverse: \ReviewLog.card)
    var reviewLogs: [ReviewLog] = []

    init(id: UUID = UUID(), term: String, type: CardType, zhHint: String, valueScore: Int) {
        self.id = id
        self.term = term
        self.type = type
        self.zhHint = zhHint
        self.valueScore = valueScore
        self.nextReviewAt = Date()
        self.easeFactor = 2.5
        self.interval = 0
        self.repetitions = 0
    }
}

