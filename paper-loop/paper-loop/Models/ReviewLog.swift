import Foundation
import SwiftData

@Model
final class ReviewLog {
    var id: UUID
    var card: Card?
    var rating: Int
    var reviewedAt: Date

    init(id: UUID = UUID(), card: Card? = nil, rating: Int, reviewedAt: Date = Date()) {
        self.id = id
        self.card = card
        self.rating = rating
        self.reviewedAt = reviewedAt
    }
}
