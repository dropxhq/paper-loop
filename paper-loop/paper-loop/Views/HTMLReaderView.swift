import SwiftUI
import WebKit

struct HTMLReaderView: UIViewRepresentable {
    let url: URL
    let elementId: String?
    let highlightText: String

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
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(elementId: elementId, highlightText: highlightText)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var elementId: String?
        var highlightText: String

        init(elementId: String?, highlightText: String) {
            self.elementId = elementId
            self.highlightText = highlightText
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            injectScrollAndHighlight(webView)
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
