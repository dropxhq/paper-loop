import SwiftUI

struct SourceDetailView: View {
    let card: Card

    @State private var selectedOccurrence: Occurrence? = nil
    @State private var openReader = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {

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

                    // Occurrences list
                    if card.occurrences.isEmpty {
                        Text("暂无出现记录")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textMuted)
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .paperCardStyle()
                    } else {
                        VStack(spacing: 0) {
                            SectionHeader("出现记录", badge: "\(card.occurrences.count)")
                                .padding(.bottom, 10)
                            LazyVStack(spacing: 10) {
                                ForEach(card.occurrences) { occurrence in
                                    OccurrenceRowView(occurrence: occurrence) {
                                        selectedOccurrence = occurrence
                                        openReader = true
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .paperCardStyle()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("回到原文")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $openReader) {
            if let occurrence = selectedOccurrence {
                readerSheet(for: occurrence)
            }
        }
    }

    @ViewBuilder
    private func readerSheet(for occurrence: Occurrence) -> some View {
        if let anchor = occurrence.anchor {
            switch anchor {
            case .html(let elementId, let htmlURL, _):
                HTMLReaderView(url: htmlURL, elementId: elementId, highlightText: occurrence.sourceSentence)
            case .pdf(let page, _):
                if let paper = occurrence.paper {
                    PDFReaderView(pdfURL: paper.pdfURL, targetPage: page, searchText: occurrence.sourceSentence)
                }
            }
        } else if let paper = occurrence.paper, let htmlURL = paper.htmlURL {
            HTMLReaderView(url: htmlURL, elementId: nil, highlightText: occurrence.sourceSentence)
        }
    }
}

// MARK: - Occurrence Row

struct OccurrenceRowView: View {
    let occurrence: Occurrence
    let onViewContext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Paper title + anchor location
            if let paper = occurrence.paper {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.primary)
                    Text(paper.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.primary)
                        .lineLimit(1)
                }
            }

            anchorLocationLabel(for: occurrence)

            // Source sentence
            if !occurrence.sourceSentence.isEmpty {
                highlightedSentence(sentence: occurrence.sourceSentence, term: occurrence.termInContext)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.r16))
                    .overlay(RoundedRectangle(cornerRadius: Theme.r16).stroke(Theme.line, lineWidth: 1))
            }

            Button("查看上下文") {
                onViewContext()
            }
            .buttonStyle(ChipButtonStyle(filled: true))
        }
        .padding(12)
        .listItemStyle()
    }

    @ViewBuilder
    private func anchorLocationLabel(for occurrence: Occurrence) -> some View {
        if let anchor = occurrence.anchor {
            switch anchor {
            case .html(let elementId, _, _):
                Label("HTML 版本 · \(elementId)", systemImage: "doc.richtext")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
            case .pdf(let page, _):
                Label("PDF 第 \(page + 1) 页", systemImage: "doc")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textMuted)
            }
        }
    }

    private func highlightedSentence(sentence: String, term: String) -> Text {
        var attributed = AttributedString(sentence)
        if let attrRange = attributed.range(of: term, options: .caseInsensitive) {
            attributed[attrRange].backgroundColor = Theme.primarySoft
            attributed[attrRange].foregroundColor = Theme.primary
            attributed[attrRange].font = .system(size: 14, weight: .semibold)
        }
        return Text(attributed)
    }
}
