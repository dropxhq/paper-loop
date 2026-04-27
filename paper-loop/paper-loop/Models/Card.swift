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
    var term: String
    var type: CardType
    var sourceSentence: String
    var contextBefore: String
    var contextAfter: String
    var zhHint: String
    var valueScore: Int
    var anchorData: Data?
    var occurrenceCount: Int

    var nextReviewAt: Date
    var easeFactor: Double
    var interval: Int
    var repetitions: Int

    var paper: Paper?

    @Relationship(deleteRule: .cascade, inverse: \ReviewLog.card)
    var reviewLogs: [ReviewLog] = []

    var anchor: AnchorData? {
        get {
            guard let data = anchorData else { return nil }
            return try? JSONDecoder().decode(AnchorData.self, from: data)
        }
        set {
            anchorData = try? JSONEncoder().encode(newValue)
        }
    }

    init(id: UUID = UUID(), term: String, type: CardType, sourceSentence: String, contextBefore: String = "", contextAfter: String = "", zhHint: String, valueScore: Int, anchor: AnchorData? = nil, occurrenceCount: Int = 1, paper: Paper? = nil) {
        self.id = id
        self.term = term
        self.type = type
        self.sourceSentence = sourceSentence
        self.contextBefore = contextBefore
        self.contextAfter = contextAfter
        self.zhHint = zhHint
        self.valueScore = valueScore
        self.anchorData = try? JSONEncoder().encode(anchor)
        self.occurrenceCount = occurrenceCount
        self.paper = paper
        self.nextReviewAt = Date()
        self.easeFactor = 2.5
        self.interval = 0
        self.repetitions = 0
    }
}
