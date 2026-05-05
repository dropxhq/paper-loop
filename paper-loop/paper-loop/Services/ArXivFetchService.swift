import Foundation
import PDFKit
import SwiftSoup

struct PaperMeta {
    let title: String
    let abstract: String
}

struct Paragraph {
    let text: String
    let anchor: String   // e.g. "element:some-id" or "page:3"
    let section: String
}

enum ArXivError: Error, LocalizedError {
    case scanOnlyPDF
    case fetchFailed

    var errorDescription: String? {
        switch self {
        case .scanOnlyPDF: return "该论文为扫描版，暂不支持"
        case .fetchFailed: return "论文内容获取失败"
        }
    }
}

actor ArXivFetchService {
    static let shared = ArXivFetchService()

    private let session = URLSession.shared

    // MARK: - Metadata (Atom XML)

    func fetchMetadata(arxivId: String) async throws -> PaperMeta {
        let url = URL(string: "https://export.arxiv.org/api/query?id_list=\(arxivId)")!
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("application/xml", forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)
        let xml = String(data: data, encoding: .utf8) ?? ""

        let title = extractXMLTag("title", from: xml, skip: 1) ?? arxivId
        let abstract = extractXMLTag("summary", from: xml) ?? ""

        return PaperMeta(title: title, abstract: abstract)
    }

    private func extractXMLTag(_ tag: String, from xml: String, skip: Int = 0) -> String? {
        let pattern = "<\(tag)[^>]*>([\\s\\S]*?)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(xml.startIndex..., in: xml)
        let matches = regex.matches(in: xml, range: range)
        let index = skip < matches.count ? skip : 0
        guard index < matches.count,
              let contentRange = Range(matches[index].range(at: 1), in: xml) else { return nil }
        return String(xml[contentRange])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
    }

    // MARK: - HTML paragraphs (primary path)

    func fetchHTMLParagraphs(arxivId: String) async -> [Paragraph]? {
        let url = URL(string: "https://arxiv.org/html/\(arxivId)")!
        guard let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }

        return parseHTMLParagraphs(html: html)
    }

    private func parseHTMLParagraphs(html: String) -> [Paragraph]? {
        guard let doc = try? SwiftSoup.parse(html) else { return nil }

        var results: [Paragraph] = []
        let sections = (try? doc.select("section")) ?? Elements()

        for section in sections.array() {
            let sectionTitle = (try? section.select("h1, h2, h3, h4").first()?.text()) ?? ""

            let paragraphs = (try? section.select("p")) ?? Elements()
            for p in paragraphs.array() {
                guard let text = try? p.text(),
                      text.count >= 30 else { continue }
                let elementId = (try? p.attr("id")) ?? ""
                let anchor = elementId.isEmpty ? "" : "element:\(elementId)"
                results.append(Paragraph(text: text, anchor: anchor, section: sectionTitle))
            }
        }

        // Fallback: top-level paragraphs not inside sections
        if results.isEmpty {
            let paragraphs = (try? doc.select("p")) ?? Elements()
            for p in paragraphs.array() {
                guard let text = try? p.text(), text.count >= 30 else { continue }
                let elementId = (try? p.attr("id")) ?? ""
                let anchor = elementId.isEmpty ? "" : "element:\(elementId)"
                results.append(Paragraph(text: text, anchor: anchor, section: ""))
            }
        }

        return results.isEmpty ? nil : results
    }

    // MARK: - PDF paragraphs (fallback)

    func fetchPDFParagraphs(arxivId: String) async throws -> [Paragraph] {
        let url = URL(string: "https://arxiv.org/pdf/\(arxivId)")!
        let (data, _) = try await session.data(from: url)

        guard let pdfDoc = PDFDocument(data: data) else {
            throw ArXivError.fetchFailed
        }

        var results: [Paragraph] = []

        for pageIndex in 0..<pdfDoc.pageCount {
            guard let page = pdfDoc.page(at: pageIndex),
                  let pageText = page.string,
                  !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            // Split into rough paragraphs by double newlines
            let chunks = pageText.components(separatedBy: "\n\n")
            for chunk in chunks {
                let text = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
                guard text.count >= 30 else { continue }
                results.append(Paragraph(text: text, anchor: "page:\(pageIndex + 1)", section: ""))
            }
        }

        if results.isEmpty {
            throw ArXivError.scanOnlyPDF
        }

        return results
    }

    // MARK: - Combined: HTML first, PDF fallback

    func fetchParagraphs(arxivId: String) async throws -> [Paragraph] {
        if let htmlParas = await fetchHTMLParagraphs(arxivId: arxivId) {
            return htmlParas
        }
        return try await fetchPDFParagraphs(arxivId: arxivId)
    }
}
