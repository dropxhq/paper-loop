import SwiftUI
import WebKit

struct HTMLReaderView: UIViewRepresentable {
    let url: URL
    let elementId: String?
    let highlightText: String
    var onLoaded: (() -> Void)? = nil
    var onFailed: ((String) -> Void)? = nil

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
        context.coordinator.elementId = elementId
        context.coordinator.highlightText = highlightText
        context.coordinator.onLoaded = onLoaded
        context.coordinator.onFailed = onFailed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(elementId: elementId, highlightText: highlightText, onLoaded: onLoaded, onFailed: onFailed)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var elementId: String?
        var highlightText: String
        var onLoaded: (() -> Void)?
        var onFailed: ((String) -> Void)?

        init(elementId: String?, highlightText: String, onLoaded: (() -> Void)?, onFailed: ((String) -> Void)?) {
            self.elementId = elementId
            self.highlightText = highlightText
            self.onLoaded = onLoaded
            self.onFailed = onFailed
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectScrollAndHighlight(webView)
            DispatchQueue.main.async { [weak self] in
                self?.onLoaded?()
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let message = (error as NSError).localizedDescription
            DispatchQueue.main.async { [weak self] in
                self?.onFailed?(message)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsErr = error as NSError
            // Ignore cancellation (happens on rapid reloads)
            guard nsErr.code != NSURLErrorCancelled else { return }
            let message = nsErr.localizedDescription
            DispatchQueue.main.async { [weak self] in
                self?.onFailed?(message)
            }
        }

        private func injectScrollAndHighlight(_ webView: WKWebView) {
            let safeText = highlightText
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: " ")

            var js = """
            (function() {
              // inject highlight style
              var style = document.createElement('style');
              style.textContent = '.pl-highlight { background: #FFD70066; border-radius: 3px; }';
              document.head.appendChild(style);

              // highlight matching text
              function highlightText(node, text) {
                if (node.nodeType === 3) {
                  var idx = node.nodeValue.indexOf(text);
                  if (idx >= 0) {
                    var span = document.createElement('span');
                    span.className = 'pl-highlight';
                    var after = node.splitText(idx);
                    after.splitText(text.length);
                    var clone = after.cloneNode(true);
                    span.appendChild(clone);
                    after.parentNode.replaceChild(span, after);
                    span.scrollIntoView({ behavior: 'smooth', block: 'center' });
                    return true;
                  }
                } else {
                  for (var i = 0; i < node.childNodes.length; i++) {
                    if (highlightText(node.childNodes[i], text)) return true;
                  }
                }
                return false;
              }
            """

            if let eid = elementId, !eid.isEmpty {
                js += """
                  var el = document.getElementById('\(eid)');
                  if (el) { el.scrollIntoView({ behavior: 'smooth', block: 'start' }); }
                """
            }

            js += """
              highlightText(document.body, '\(safeText)');
            })();
            """

            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}

struct HTMLReaderViewWrapper: View {
    let url: URL
    let elementId: String?
    let highlightText: String

    var body: some View {
        NavigationStack {
            HTMLReaderView(url: url, elementId: elementId, highlightText: highlightText)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("原文")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
