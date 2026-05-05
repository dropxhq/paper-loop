import Foundation
import SwiftData

@Model
final class Occurrence {
    var id: UUID
    var termInContext: String
    var sourceSentence: String
    var anchorData: Data?

    var paper: Paper?
    var card: Card?

    var anchor: AnchorData? {
        get {
            guard let data = anchorData else { return nil }
            return try? JSONDecoder().decode(AnchorData.self, from: data)
        }
        set {
            anchorData = try? JSONEncoder().encode(newValue)
        }
    }

    init(id: UUID = UUID(), termInContext: String, sourceSentence: String, anchor: AnchorData? = nil, paper: Paper? = nil) {
        self.id = id
        self.termInContext = termInContext
        self.sourceSentence = sourceSentence
        self.anchorData = try? JSONEncoder().encode(anchor)
        self.paper = paper
    }
}
