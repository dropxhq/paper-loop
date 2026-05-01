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
    @State private var urlText = ""
    @State private var importState: ImportState = .idle
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
                        LinearGradient(colors: [Theme.surface, Color(red: 0.961, green: 0.937, blue: 0.902)],
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
        } // NavigationStack
    }

    @ViewBuilder
    private var statusView: some View {
        switch importState {
        case .idle:
            EmptyView()
        case .parsing:
            progressRow(icon: "doc.text.magnifyingglass", text: "解析论文内容中…")
        case .parsingPDF:
            progressRow(icon: "doc.richtext", text: "使用 PDF 解析中…")
        case .generatingCards:
            progressRow(icon: "sparkles", text: "生成卡片中…")
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

    private func progressRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(Theme.primary)
            Image(systemName: icon)
                .foregroundStyle(Theme.textMuted)
            Text(text)
                .foregroundStyle(Theme.textMuted)
                .font(.system(size: 14))
        }
        .padding(.top, 4)
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

    private func startImport() {
        let url = urlText.trimmingCharacters(in: .whitespaces)
        importState = .parsing
        Task {
            do {
                let jobId = try await ImportService.shared.startImport(url: url)
                try await pollProgress(jobId: jobId)
            } catch {
                importState = .failed(error.localizedDescription)
            }
        }
    }

    private func pollProgress(jobId: String) async throws {
        let deadline = Date().addingTimeInterval(300)
        while Date() < deadline {
            let status = try await ImportService.shared.pollStatus(jobId: jobId)
            switch status.status {
            case "parsing":
                importState = .parsing
            case "parsing_pdf":
                importState = .parsingPDF
            case "generating_cards":
                importState = .generatingCards
            case "done":
                guard let paper = status.paper, let cards = status.cards else {
                    importState = .failed("服务器返回数据异常")
                    return
                }
                await saveAndNavigate(paperResponse: paper, cardResponses: cards)
                return
            case "error":
                importState = .failed(status.error ?? "导入失败")
                return
            default:
                break
            }
            try await Task.sleep(nanoseconds: 1_500_000_000)
        }
        importState = .failed("导入超时，请重试")
    }

    @MainActor
    private func saveAndNavigate(paperResponse: PaperResponse, cardResponses: [CardResponse]) {
        let paper = Paper(
            arxivId: paperResponse.arxivId,
            title: paperResponse.title,
            abstract: paperResponse.abstract,
            htmlURL: paperResponse.htmlURL.flatMap { URL(string: $0) },
            pdfURL: URL(string: paperResponse.pdfURL)!
        )
        modelContext.insert(paper)

        for cr in cardResponses {
            let cardType = CardType(rawValue: cr.type) ?? .word
            let anchor: AnchorData? = cr.anchor.flatMap { ar in
                if ar.type == "html", let eid = ar.elementId, let hu = ar.htmlURL ?? paperResponse.htmlURL, let url = URL(string: hu) {
                    return .html(elementId: eid, htmlURL: url)
                } else if ar.type == "pdf", let page = ar.page {
                    let bbox = ar.bbox.map { coords in
                        CGRect(x: coords[0], y: coords[1], width: coords[2] - coords[0], height: coords[3] - coords[1])
                    } ?? .zero
                    return .pdf(page: page, bbox: bbox)
                }
                return nil
            }
            let card = Card(
                term: cr.term,
                type: cardType,
                sourceSentence: cr.sourceSentence,
                contextBefore: cr.contextBefore,
                contextAfter: cr.contextAfter,
                zhHint: cr.zhHint,
                valueScore: cr.valueScore,
                anchor: anchor,
                occurrenceCount: cr.occurrenceCount,
                paper: paper
            )
            modelContext.insert(card)
        }

        importState = .done
        selectedTab = 1
    }
}

#Preview {
    @Previewable @State var tab = 0
    ImportView(selectedTab: $tab)
        .modelContainer(for: [Paper.self, Card.self, ReviewLog.self], inMemory: true)
}
