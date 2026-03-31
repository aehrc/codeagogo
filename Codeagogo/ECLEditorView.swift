// Copyright 2026 Commonwealth Scientific and Industrial Research Organisation (CSIRO)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI
import WebKit

/// SwiftUI wrapper for the ECL editor powered by Monaco + ecl-editor web component.
///
/// Hosts a WKWebView containing the `<ecl-editor>` web component with syntax
/// highlighting, autocomplete, diagnostics, and formatting. Communicates with
/// Swift via `WKScriptMessageHandler` for content changes and evaluation triggers.
struct ECLEditorView: NSViewRepresentable {
    /// The initial ECL expression to load in the editor.
    let initialValue: String

    /// The FHIR server URL for concept completion and validation.
    let fhirServerURL: String

    /// Whether to use dark theme.
    let darkTheme: Bool

    /// Called when the editor content changes (debounced by the JS side).
    var onValueChanged: ((String) -> Void)?

    /// Called when the user explicitly requests evaluation (Ctrl+Enter).
    var onEvaluate: ((String) -> Void)?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()

        contentController.add(context.coordinator, name: "eclEditor")
        config.userContentController = contentController

        // Allow local file access for Monaco workers
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")

        // Load the editor HTML
        let html = Self.buildEditorHTML(
            value: initialValue,
            fhirServerURL: fhirServerURL,
            darkTheme: darkTheme
        )

        // Load with a base URL pointing to the bundle resources for local file access
        if let resourceURL = Bundle.main.resourceURL {
            webView.loadHTMLString(html, baseURL: resourceURL)
        } else {
            webView.loadHTMLString(html, baseURL: nil)
        }

        context.coordinator.webView = webView
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Don't reload on every SwiftUI update — the editor manages its own state
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onValueChanged: onValueChanged, onEvaluate: onEvaluate)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKScriptMessageHandler {
        var onValueChanged: ((String) -> Void)?
        var onEvaluate: ((String) -> Void)?
        weak var webView: WKWebView?

        init(onValueChanged: ((String) -> Void)?, onEvaluate: ((String) -> Void)?) {
            self.onValueChanged = onValueChanged
            self.onEvaluate = onEvaluate
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "eclEditor",
                  let body = message.body as? [String: Any],
                  let event = body["event"] as? String else { return }

            switch event {
            case "change":
                if let value = body["value"] as? String {
                    onValueChanged?(value)
                }
            case "evaluate":
                if let value = body["value"] as? String {
                    onEvaluate?(value)
                }
            default:
                break
            }
        }

        /// Sets the editor value from Swift.
        func setValue(_ value: String) {
            let escaped = value
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
            webView?.evaluateJavaScript(
                "document.querySelector('ecl-editor').value = '\(escaped)'"
            )
        }
    }

    // MARK: - HTML Generation

    /// Builds the HTML page hosting the ECL editor web component.
    static func buildEditorHTML(value: String, fhirServerURL: String, darkTheme: Bool) -> String {
        let escapedValue = value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        let theme = darkTheme ? "vs-dark" : "vs"

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                html, body { height: 100%; overflow: hidden; background: transparent; }
                ecl-editor {
                    display: block;
                    height: 100%;
                    width: 100%;
                }
                /* Hide the ecl-editor's internal resize handle — resizing is
                   controlled by the SwiftUI drag handle in the parent panel */
                ecl-editor > div[style*="ns-resize"] {
                    display: none !important;
                }
            </style>
        </head>
        <body>
            <!-- Monaco AMD loader from CDN -->
            <script src="https://cdn.jsdelivr.net/npm/monaco-editor@0.52.2/min/vs/loader.js"></script>
            <script>
                require.config({
                    paths: { vs: 'https://cdn.jsdelivr.net/npm/monaco-editor@0.52.2/min/vs' }
                });
                require(['vs/editor/editor.main'], function() {
                    // Monaco loaded — ecl-editor will auto-initialize
                    document.getElementById('loading').style.display = 'none';
                });
            </script>

            <!-- ECL Editor standalone bundle -->
            <script src="ecl-editor.standalone.js"></script>

            <div id="loading" style="padding: 12px; color: #888; font-family: system-ui; font-size: 12px;">
                Loading editor...
            </div>

            <ecl-editor
                value="\(escapedValue)"
                fhir-server-url="\(fhirServerURL)"
                theme="\(theme)"
                height="100vh"
                minimap="false"
                semantic-validation="true"
            ></ecl-editor>


            <script>
                // Debounced change forwarding to Swift
                var changeTimer = null;
                var editor = document.querySelector('ecl-editor');

                editor.addEventListener('ecl-change', function(e) {
                    clearTimeout(changeTimer);
                    changeTimer = setTimeout(function() {
                        window.webkit.messageHandlers.eclEditor.postMessage({
                            event: 'change',
                            value: e.detail.value
                        });
                    }, 500);
                });

                // Fix editor after initialization
                function fixEditor() {
                    var el = editor.querySelector('div[style*="ns-resize"]');
                    if (el && editor.editor) {
                        // Hide the ecl-editor's internal resize handle
                        el.style.display = 'none';
                        // Remove top padding so line 1 starts at the top
                        editor.editor.updateOptions({ padding: { top: 0, bottom: 0 } });
                        editor.editor.setScrollTop(0);
                    } else {
                        setTimeout(fixEditor, 200);
                    }
                }
                setTimeout(fixEditor, 500);

                // Ctrl+Enter / Cmd+Enter to evaluate
                document.addEventListener('keydown', function(e) {
                    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
                        e.preventDefault();
                        window.webkit.messageHandlers.eclEditor.postMessage({
                            event: 'evaluate',
                            value: editor.value
                        });
                    }
                });
            </script>
        </body>
        </html>
        """
    }
}
