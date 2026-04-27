import SwiftUI
import PDFKit

struct PDFReaderView: UIViewRepresentable {
    let pdfURL: URL
    let targetPage: Int
    let searchText: String

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        Task {
            let localURL = await PDFCache.shared.localURL(for: pdfURL)
            await MainActor.run {
                guard let document = PDFDocument(url: localURL) else { return }
                pdfView.document = document
                navigateAndHighlight(pdfView: pdfView, document: document)
            }
        }
    }

    private func navigateAndHighlight(pdfView: PDFView, document: PDFDocument) {
        guard targetPage < document.pageCount,
              let page = document.page(at: targetPage) else { return }

        pdfView.go(to: page)

        // text search highlight
        if let selections = document.findString(searchText, withOptions: .caseInsensitive), !selections.isEmpty {
            let selection = selections[0]
            pdfView.go(to: selection)
            pdfView.currentSelection = selection
            pdfView.setCurrentSelection(selection, animate: true)

            // add a highlight annotation
            let bounds = selection.bounds(for: page)
            let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            annotation.color = UIColor.systemYellow.withAlphaComponent(0.5)
            page.addAnnotation(annotation)
        }
    }
}

actor PDFCache {
    static let shared = PDFCache()

    private let cacheDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PDFCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    func localURL(for remoteURL: URL) async -> URL {
        let filename = remoteURL.absoluteString
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .appending(".pdf")
        let localURL = cacheDir.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: remoteURL)
            try data.write(to: localURL)
        } catch {
            // return remote URL as fallback
            return remoteURL
        }

        return localURL
    }
}

struct PDFReaderViewWrapper: View {
    let pdfURL: URL
    let targetPage: Int
    let searchText: String

    var body: some View {
        NavigationStack {
            PDFReaderView(pdfURL: pdfURL, targetPage: targetPage, searchText: searchText)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("PDF 原文")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
