import SwiftUI

// MARK: - Reader destination

enum ReaderDestination {
    case html(url: URL, elementId: String?, highlightText: String)
    case pdf(pdfURL: URL, targetPage: Int, searchText: String)
}

// MARK: - ReaderContainerView

/// Unified loading/error wrapper for HTML and PDF readers.
/// Shows a loading indicator while the reader initialises,
/// and an error page with retry + PDF fallback on failure.
struct ReaderContainerView: View {
    let initialDestination: ReaderDestination
    /// PDF fallback — if non-nil and the primary load fails, offer "改用 PDF 打开"
    let pdfFallback: ReaderDestination?

    @State private var activeDestination: ReaderDestination
    @State private var loadState: LoadState = .loading
    @Environment(\.dismiss) private var dismiss

    enum LoadState: Equatable {
        case loading
        case success
        case failure(String)

        static func == (lhs: LoadState, rhs: LoadState) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading), (.success, .success): return true
            case (.failure(let a), .failure(let b)): return a == b
            default: return false
            }
        }
    }

    init(destination: ReaderDestination, pdfFallback: ReaderDestination? = nil) {
        self.initialDestination = destination
        self.pdfFallback = pdfFallback
        self._activeDestination = State(initialValue: destination)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Reader always present, hidden until loaded
                readerView(for: activeDestination)
                    .opacity(loadState == .success ? 1 : 0)

                // Loading overlay
                if loadState == .loading {
                    loadingView
                } else if case .failure(let message) = loadState {
                    failureView(message: message)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
            }
            .onChange(of: activeDestination.id) {
                loadState = .loading
            }
        }
    }

    // MARK: - Sub-views

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.4)
                .tint(Theme.primary)
            Text("正在加载原文…")
                .font(.system(size: 15))
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
    }

    @ViewBuilder
    private func readerView(for dest: ReaderDestination) -> some View {
        switch dest {
        case .html(let url, let elementId, let highlight):
            HTMLReaderView(
                url: url,
                elementId: elementId,
                highlightText: highlight,
                onLoaded: { loadState = .success },
                onFailed: { err in loadState = .failure(err) }
            )
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("原文")
        case .pdf(let pdfURL, let page, let search):
            PDFReaderView(
                pdfURL: pdfURL,
                targetPage: page,
                searchText: search,
                onLoaded: { loadState = .success },
                onFailed: { err in loadState = .failure(err) }
            )
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("PDF 原文")
        }
    }

    private func failureView(message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(Theme.textMuted)
            VStack(spacing: 8) {
                Text("原文加载失败")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            VStack(spacing: 12) {
                Button("重试") {
                    activeDestination = initialDestination
                    loadState = .loading
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 40)

                if let fallback = pdfFallback {
                    Button("改用 PDF 打开") {
                        activeDestination = fallback
                        loadState = .loading
                    }
                    .buttonStyle(ChipButtonStyle(filled: false))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg.ignoresSafeArea())
    }
}

// MARK: - Destination identity for onChange

private extension ReaderDestination {
    var id: String {
        switch self {
        case .html(let url, let eid, _): return "html:\(url)\(eid ?? "")"
        case .pdf(let url, let page, _): return "pdf:\(url)\(page)"
        }
    }
}

// MARK: - Convenience initialiser from Occurrence

extension ReaderContainerView {
    init(occurrence: Occurrence) {
        let dest: ReaderDestination
        var fallback: ReaderDestination? = nil

        if let anchor = occurrence.anchor {
            switch anchor {
            case .html(let elementId, let htmlURL, _):
                dest = .html(url: htmlURL, elementId: elementId, highlightText: occurrence.sourceSentence)
                if let paper = occurrence.paper {
                    fallback = .pdf(pdfURL: paper.pdfURL, targetPage: 0, searchText: occurrence.sourceSentence)
                }
            case .pdf(let page, _):
                if let paper = occurrence.paper {
                    dest = .pdf(pdfURL: paper.pdfURL, targetPage: page, searchText: occurrence.sourceSentence)
                } else {
                    dest = .html(url: URL(string: "about:blank")!, elementId: nil, highlightText: "")
                }
            }
        } else if let paper = occurrence.paper, let htmlURL = paper.htmlURL {
            dest = .html(url: htmlURL, elementId: nil, highlightText: occurrence.sourceSentence)
            fallback = .pdf(pdfURL: paper.pdfURL, targetPage: 0, searchText: occurrence.sourceSentence)
        } else if let paper = occurrence.paper {
            dest = .pdf(pdfURL: paper.pdfURL, targetPage: 0, searchText: occurrence.sourceSentence)
        } else {
            dest = .html(url: URL(string: "about:blank")!, elementId: nil, highlightText: "")
        }

        self.init(destination: dest, pdfFallback: fallback)
    }
}

