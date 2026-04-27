import Foundation

enum ReviewRating: Int, CaseIterable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    var label: String {
        switch self {
        case .again: return "不认识"
        case .hard: return "模糊"
        case .good: return "认识"
        case .easy: return "已掌握"
        }
    }
}

struct ReviewScheduler {
    static func schedule(card: Card, rating: ReviewRating) {
        let q = rating.rawValue - 1  // SM-2 uses 0-based quality

        if q < 2 {
            // failed: reset repetitions
            card.repetitions = 0
            card.interval = 1
        } else {
            switch card.repetitions {
            case 0:
                card.interval = 1
            case 1:
                card.interval = 6
            default:
                card.interval = Int((Double(card.interval) * card.easeFactor).rounded())
            }
            card.repetitions += 1
        }

        let ef = card.easeFactor + (0.1 - Double(5 - q) * (0.08 + Double(5 - q) * 0.02))
        card.easeFactor = max(1.3, ef)
        card.nextReviewAt = Calendar.current.date(byAdding: .day, value: card.interval, to: Date()) ?? Date()
    }
}
