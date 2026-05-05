import Foundation
import SwiftData

@Model
final class Paper {
    var id: UUID
    var arxivId: String
    var title: String
    var abstract: String
    var htmlURL: URL?
    var pdfURL: URL
    var importedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Occurrence.paper)
    var occurrences: [Occurrence] = []

    init(id: UUID = UUID(), arxivId: String, title: String, abstract: String, htmlURL: URL? = nil, pdfURL: URL, importedAt: Date = Date()) {
        self.id = id
        self.arxivId = arxivId
        self.title = title
        self.abstract = abstract
        self.htmlURL = htmlURL
        self.pdfURL = pdfURL
        self.importedAt = importedAt
    }
}
