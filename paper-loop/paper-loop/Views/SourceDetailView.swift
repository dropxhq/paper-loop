import SwiftUI

struct SourceDetailView: View {
    let card: Card

    @State private var openReader = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                if let paper = card.paper {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("来源论文")
                            .font(.caption).textCase(.uppercase)
                            .foregroundStyle(.secondary)
                        Text(paper.title)
                            .font(.headline)
                    }
                }

                anchorLocationView

                VStack(alignment: .leading, spacing: 8) {
                    Text("前文")
                        .font(.caption).textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Text(card.contextBefore.isEmpty ? "—" : card.contextBefore)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("原句")
                        .font(.caption).textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    highlightedSentence
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("后文")
                        .font(.caption).textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Text(card.contextAfter.isEmpty ? "—" : card.contextAfter)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                openSourceButton
            }
            .padding()
        }
        .navigationTitle("回到原文")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $openReader) {
            readerSheet
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var anchorLocationView: some View {
        if let anchor = card.anchor {
            switch anchor {
            case .html(let elementId, _):
                Label("HTML 版本 · \(elementId)", systemImage: "doc.richtext")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .pdf(let page, _):
                Label("PDF 第 \(page + 1) 页", systemImage: "doc")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var highlightedSentence: some View {
        let sentence = card.sourceSentence
        let term = card.term
        if let range = sentence.range(of: term, options: .caseInsensitive) {
            var attributed = AttributedString(sentence)
            if let attrRange = attributed.range(of: term, options: .caseInsensitive) {
                attributed[attrRange].backgroundColor = .yellow.opacity(0.4)
                attributed[attrRange].font = .callout.bold()
            }
            return Text(attributed)
        } else {
            return Text(sentence)
        }
    }

    private var openSourceButton: some View {
        Button {
            openReader = true
        } label: {
            Label("打开原文", systemImage: "arrow.up.right.square")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var readerSheet: some View {
        if let anchor = card.anchor {
            switch anchor {
            case .html(let elementId, let htmlURL):
                HTMLReaderView(url: htmlURL, elementId: elementId, highlightText: card.sourceSentence)
            case .pdf(let page, _):
                if let paper = card.paper {
                    PDFReaderView(pdfURL: paper.pdfURL, targetPage: page, searchText: card.sourceSentence)
                }
            }
        } else if let paper = card.paper, let htmlURL = paper.htmlURL {
            HTMLReaderView(url: htmlURL, elementId: nil, highlightText: card.sourceSentence)
        }
    }
}
