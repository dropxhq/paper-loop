import SwiftUI
import SwiftData

private enum ImportState {
    case idle
    case parsing
    case parsingPDF
    case generatingCards
    case done
    case failed(String)
}

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPapers: [Paper]
    @State private var urlText = ""
    @State private var importState: ImportState = .idle
    @State private var importProgress: Double = 0
    @State private var showDupDialog = false
    @State private var existingPaperForDup: Paper? = nil
    @State private var navigateToPaperDetail: Paper? = nil
    @Binding var selectedTab: Int

    var body: some View {
        NavigationStack {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    // Hero card
                    VStack(alignment: .leading, spacing: 12) {
                        EyebrowBadge(text: "arXiv · PDF · 自动卡片")
                        Text("导入论文，自动生成可复习词卡")
                            .font(Font.custom("Georgia", size: 24).weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineSpacing(3)
                        Text("粘贴 arXiv 链接或上传本地 PDF，词卡自动就绪。")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textMuted)
                            .lineSpacing(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        LinearGradient(colors: [Theme.surface, Theme.surface2],
                                       startPoint: .top, endPoint: .bottom)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Theme.r24))
                    .overlay(RoundedRectangle(cornerRadius: Theme.r24).stroke(Theme.line, lineWidth: 1))
                    .shadow(color: Theme.cardShadow, radius: 13, x: 0, y: 10)

                    // Input card
                    VStack(spacing: 10) {
                        SectionHeader("导入来源", badge: "入口")

                        // URL input styled as HTML .input
                        HStack {
                            Image(systemName: "link")
                                .foregroundStyle(Theme.textMuted)
                            TextField("https://arxiv.org/abs/...", text: $urlText)
                                .keyboardType(.URL)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .font(.system(size: 14))
                                .foregroundStyle(urlText.isEmpty ? Theme.textMuted : Theme.textPrimary)
                        }
                        .frame(minHeight: 48)
                        .padding(.horizontal, 14)
                        .background(Theme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.r16))
                        .overlay(RoundedRectangle(cornerRadius: Theme.r16).stroke(Theme.line, lineWidth: 1))

                        Button(action: startImport) {
                            Text("导入论文")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!canImport)

                        statusView
                    }
                    .padding(14)
                    .paperCardStyle()
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("导入")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $navigateToPaperDetail) { paper in
            PaperDetailView(paper: paper)
        }
        .confirmationDialog(
            "该论文已导入过",
            isPresented: $showDupDialog,
            titleVisibility: .visible
        ) {
            Button("查看已有词卡") {
                navigateToPaperDetail = existingPaperForDup
            }
            Button("合并（追加新词卡）") {
                guard let existing = existingPaperForDup else { return }
                performImport(mergeInto: existing)
            }
            Button("替换（重新生成）", role: .destructive) {
                guard let existing = existingPaperForDup else { return }
                modelContext.delete(existing)
                performImport(mergeInto: nil)
            }
            Button("取消", role: .cancel) {
                existingPaperForDup = nil
            }
        } message: {
            Text("你可以查看已有词卡、追加新词卡合并，或删除旧词卡重新生成。")
        }
        } // NavigationStack
    }

    @ViewBuilder
    private var statusView: some View {
        switch importState {
        case .idle:
            EmptyView()
        case .parsing, .parsingPDF, .generatingCards:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    ProgressView()
                        .tint(Theme.primary)
                        .scaleEffect(0.8)
                    Text(stageLabel)
                        .foregroundStyle(Theme.textMuted)
                        .font(.system(size: 14))
                    Spacer()
                    Text("\(Int(importProgress * 100))%")
                        .foregroundStyle(Theme.primary)
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                }
                ProgressView(value: importProgress)
                    .tint(Theme.primary)
                    .animation(.easeInOut(duration: 0.4), value: importProgress)
            }
            .padding(.top, 4)
        case .done:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.primary)
                Text("导入成功！")
                    .foregroundStyle(Theme.primary)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.top, 4)
        case .failed(let msg):
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(msg)
                    .foregroundStyle(.red)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.leading)
            }
            .padding(.top, 4)
        }
    }

    private var stageLabel: String {
        switch importState {
        case .parsing: return String(localized: "解析论文内容中…")
        case .parsingPDF: return String(localized: "使用 PDF 解析中…")
        case .generatingCards: return String(localized: "生成卡片中…")
        default: return ""
        }
    }

    private var canImport: Bool {
        !urlText.trimmingCharacters(in: .whitespaces).isEmpty && isIdleOrDone
    }

    private var isIdleOrDone: Bool {
        switch importState {
        case .idle, .done, .failed: return true
        default: return false
        }
    }

    // MARK: - ArXiv ID Extraction

    private func extractArxivId(from url: String) -> String? {
        // Matches patterns like arxiv.org/abs/2301.00001 or arxiv.org/pdf/2301.00001
        let pattern = #"arxiv\.org/(?:abs|pdf)/([0-9]{4}\.[0-9]{4,5}(?:v\d+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let range = NSRange(url.startIndex..., in: url)
        guard let match = regex.firstMatch(in: url, range: range),
              let idRange = Range(match.range(at: 1), in: url) else { return nil }
        return String(url[idRange])
    }

    private func startImport() {
        let url = urlText.trimmingCharacters(in: .whitespaces)
        // Check for duplicate arxivId before importing
        if let arxivId = extractArxivId(from: url),
           let existing = allPapers.first(where: { $0.arxivId == arxivId }) {
            existingPaperForDup = existing
            showDupDialog = true
            return
        }
        performImport(mergeInto: nil)
    }

    private func performImport(mergeInto existingPaper: Paper?) {
        let url = urlText.trimmingCharacters(in: .whitespaces)
        importState = .parsing
        importProgress = 0
        Task {
            do {
                let result = try await ImportService.shared.startImport(url: url) { progress in
                    Task { @MainActor in
                        importProgress = progress
                        if progress > 0.20 {
                            importState = .generatingCards
                        }
                    }
                }
                await saveAndNavigate(result: result, mergeInto: existingPaper)
            } catch LLMError.missingAPIKey {
                importState = .failed("请先在「我的」中设置 API Key")
            } catch {
                importState = .failed(error.localizedDescription)
            }
        }
    }

    @MainActor
    private func saveAndNavigate(result: ImportResult, mergeInto existingPaper: Paper?) {
        let paper: Paper
        if let existing = existingPaper {
            paper = existing
        } else {
            paper = Paper(
                arxivId: result.arxivId,
                title: result.meta.title,
                abstract: result.meta.abstract,
                htmlURL: result.htmlURL,
                pdfURL: result.pdfURL
            )
            modelContext.insert(paper)
        }

        // Build a lemma → Card lookup from all existing cards for dedup
        let allCards = (try? modelContext.fetch(FetchDescriptor<Card>())) ?? []
        var lemmaToCard: [String: Card] = [:]
        for card in allCards {
            lemmaToCard[card.term.lowercased()] = card
        }

        for cd in result.cards {
            let lowerLemma = cd.lemma.lowercased()
            let anchor = buildAnchor(from: cd, htmlURL: result.htmlURL)

            let occurrence = Occurrence(
                termInContext: cd.termInContext,
                sourceSentence: cd.sourceSentence,
                anchor: anchor,
                paper: paper
            )

            if let existingCard = lemmaToCard[lowerLemma] {
                // Append occurrence to existing card
                existingCard.occurrences.append(occurrence)
            } else {
                // Create new card + occurrence
                let cardType = CardType(rawValue: cd.type) ?? .word
                let card = Card(
                    term: cd.lemma,
                    type: cardType,
                    zhHint: cd.zhHint,
                    valueScore: cd.valueScore
                )
                modelContext.insert(card)
                card.occurrences.append(occurrence)
                lemmaToCard[lowerLemma] = card
            }
        }

        importState = .done
        selectedTab = 1
    }

    private func buildAnchor(from cd: CardData, htmlURL: URL?) -> AnchorData? {
        if cd.paragraphAnchor.hasPrefix("element:") {
            let elementId = String(cd.paragraphAnchor.dropFirst("element:".count))
            if let url = htmlURL {
                return .html(elementId: elementId, htmlURL: url, charOffset: cd.charOffset)
            }
        } else if cd.paragraphAnchor.hasPrefix("page:") {
            let pageStr = String(cd.paragraphAnchor.dropFirst("page:".count))
            if let page = Int(pageStr) {
                // ArXivFetchService stores 1-based page numbers; convert to 0-based for PDFDocument.page(at:)
                return .pdf(page: max(0, page - 1), bbox: .zero)
            }
        }
        return nil
    }
}

#Preview {
    @Previewable @State var tab = 0
    ImportView(selectedTab: $tab)
        .modelContainer(for: [Paper.self, Card.self, Occurrence.self, ReviewLog.self], inMemory: true)
}
