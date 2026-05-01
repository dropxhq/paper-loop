import SwiftUI

struct SourceDetailView: View {
    let card: Card

    @State private var openReader = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Source paper card
                    if let paper = card.paper {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("来源论文")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.textMuted)
                                .textCase(.uppercase)
                            Text(paper.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            anchorLocationView
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .paperCardStyle()
                    }

                    // Term + hint
                    VStack(alignment: .leading, spacing: 8) {
                        Text(card.term)
                            .font(Font.custom("Georgia", size: 24).weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        if !card.zhHint.isEmpty {
                            Text(card.zhHint)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .paperCardStyle()

                    // Context card
                    VStack(alignment: .leading, spacing: 12) {
                        if !card.contextBefore.isEmpty {
                            contextBlock(label: "前文", text: card.contextBefore, highlighted: false)
                        }
                        contextBlock(label: "原句", text: card.sourceSentence, highlighted: true)
                        if !card.contextAfter.isEmpty {
                            contextBlock(label: "后文", text: card.contextAfter, highlighted: false)
                        }
                    }
                    .padding(14)
                    .paperCardStyle()

                    // Action chips
                    HStack(spacing: 8) {
                        Button("回到原文") { openReader = true }
                            .buttonStyle(ChipButtonStyle(filled: true))
                        Button("看上下文") { openReader = true }
                            .buttonStyle(ChipButtonStyle())
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
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
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.primary)
            case .pdf(let page, _):
                Label("PDF 第 \(page + 1) 页", systemImage: "doc")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.primary)
            }
        }
    }

    private func contextBlock(label: String, text: String, highlighted: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
                .textCase(.uppercase)
            if highlighted {
                highlightedSentence
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.r16))
                    .overlay(RoundedRectangle(cornerRadius: Theme.r16).stroke(Theme.line, lineWidth: 1))
            } else {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textMuted)
                    .lineSpacing(4)
            }
        }
    }

    private var highlightedSentence: Text {
        let sentence = card.sourceSentence
        let term = card.term
        var attributed = AttributedString(sentence)
        if let attrRange = attributed.range(of: term, options: .caseInsensitive) {
            attributed[attrRange].backgroundColor = Theme.primarySoft
            attributed[attrRange].foregroundColor = Theme.primary
            attributed[attrRange].font = .system(size: 14, weight: .semibold)
        }
        return Text(attributed)
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
