import Foundation

struct ImportResult {
    let meta: PaperMeta
    let arxivId: String
    let htmlURL: URL?
    let pdfURL: URL
    let cards: [CardData]
}

enum ImportError: Error, LocalizedError {
    case invalidURL
    case noContent
    case importFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "仅支持 arXiv 链接"
        case .noContent: return "无法获取论文内容"
        case .importFailed(let msg): return msg
        }
    }
}

actor ImportService {
    static let shared = ImportService()

    func startImport(url: String, onProgress: (@Sendable (Double) -> Void)? = nil) async throws -> ImportResult {
        guard let arxivId = extractArxivId(from: url) else {
            throw ImportError.invalidURL
        }

        // Check API Key early
        guard let key = KeychainHelper.read(key: "llm_api_key"), !key.isEmpty else {
            throw LLMError.missingAPIKey
        }

        // 1. Fetch metadata (→ 5%)
        let meta: PaperMeta
        do {
            meta = try await ArXivFetchService.shared.fetchMetadata(arxivId: arxivId)
        } catch {
            meta = PaperMeta(title: arxivId, abstract: "")
        }
        onProgress?(0.05)

        // 2. Fetch paragraphs (→ 20%)
        let paragraphs = try await ArXivFetchService.shared.fetchParagraphs(arxivId: arxivId)
        onProgress?(0.20)

        let htmlURL = URL(string: "https://arxiv.org/html/\(arxivId)")
        let pdfURL = URL(string: "https://arxiv.org/pdf/\(arxivId)")!

        // 3. Generate cards via LLM (20% → 100%)
        let paperContext = "\(meta.title). \(meta.abstract.prefix(200))"
        let cards = try await CardPipeline.shared.generateCards(
            paragraphs: paragraphs,
            paperContext: String(paperContext),
            onProgress: { fraction in
                onProgress?(0.20 + 0.80 * fraction)
            }
        )

        return ImportResult(
            meta: meta,
            arxivId: arxivId,
            htmlURL: htmlURL,
            pdfURL: pdfURL,
            cards: cards
        )
    }

    private func extractArxivId(from url: String) -> String? {
        let pattern = #"arxiv\.org/(?:abs|pdf)/([0-9]{4}\.[0-9]{4,5}(?:v\d+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(url.startIndex..., in: url)
        guard let match = regex.firstMatch(in: url, range: range),
              let idRange = Range(match.range(at: 1), in: url) else { return nil }
        return String(url[idRange])
    }
}
