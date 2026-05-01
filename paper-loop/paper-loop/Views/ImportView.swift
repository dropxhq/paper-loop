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
            VStack(spacing: 24) {
                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Text("粘贴 arXiv 链接")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("https://arxiv.org/abs/...", text: $urlText)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal)

                statusView

                Button(action: startImport) {
                    Label("导入", systemImage: "arrow.down.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .disabled(!canImport)

                Spacer()
            }
            .navigationTitle("导入")
        }
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
            Label("导入成功！", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private func progressRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView()
            Image(systemName: icon)
            Text(text)
                .foregroundStyle(.secondary)
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
        let deadline = Date().addingTimeInterval(120)
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
