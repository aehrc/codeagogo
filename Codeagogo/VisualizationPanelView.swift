import SwiftUI
import WebKit
import UniformTypeIdentifiers

/// SwiftUI view for the concept visualization panel.
///
/// Displays a WebView with the generated visualization, along with loading
/// and error states.
struct VisualizationPanelView: View {
    @ObservedObject var viewModel: VisualizationViewModel
    let onClose: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Content (no header - panel title bar has controls)
            if let error = viewModel.error {
                VStack {
                    Spacer()
                    Text("Error loading visualization")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                    Spacer()
                }
            } else if let data = viewModel.visualizationData {
                WebViewRepresentable(html: DiagramRenderer.generateHTML(for: data))
            } else {
                VStack {
                    Spacer()
                    ProgressView()
                    Text("Loading properties...")
                        .padding()
                    Spacer()
                }
            }
        }
        .frame(minWidth: 500, idealWidth: 700, maxWidth: .infinity,
               minHeight: 400, idealHeight: 600, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

/// NSViewRepresentable wrapper for WKWebView.
///
/// Displays HTML content in a WebView within SwiftUI.
struct WebViewRepresentable: NSViewRepresentable {
    let html: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()

        // Add message handler for download requests
        contentController.add(context.coordinator, name: "downloadHandler")
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "downloadHandler",
                  let body = message.body as? [String: String],
                  let type = body["type"],
                  let data = body["data"],
                  let window = message.webView?.window else { return }

            // Extract concept info for filename
            let conceptId = body["conceptId"] ?? ""
            let conceptTerm = body["conceptTerm"] ?? ""

            // Show save panel attached to the visualization window
            let savePanel = NSSavePanel()
            savePanel.canCreateDirectories = true
            savePanel.showsTagField = false

            // Generate sanitized filename
            let sanitizedName = Self.sanitizeFilename(conceptId: conceptId, conceptTerm: conceptTerm)

            if type == "svg" {
                savePanel.nameFieldStringValue = sanitizedName + ".svg"
                savePanel.allowedContentTypes = [.svg]
            } else if type == "png" {
                savePanel.nameFieldStringValue = sanitizedName + ".png"
                savePanel.allowedContentTypes = [.png]
            }

            // Present as a sheet attached to the visualization window
            savePanel.beginSheetModal(for: window) { response in
                guard response == .OK, let url = savePanel.url else { return }

                do {
                    if type == "svg" {
                        try data.write(to: url, atomically: true, encoding: .utf8)
                    } else if type == "png" {
                        // Decode base64 PNG data
                        if let imageData = Data(base64Encoded: data) {
                            try imageData.write(to: url)
                        }
                    }
                } catch {
                    print("Failed to save file: \(error)")
                }
            }
        }

        /// Sanitizes concept ID and term into a safe, meaningful filename.
        ///
        /// Format: `{conceptId}-{sanitized-term}`
        /// - Removes semantic tags (content in parentheses at end)
        /// - Keeps only alphanumeric and spaces
        /// - Replaces spaces with hyphens
        /// - Truncates term to ~40 chars at word boundary
        /// - Returns just concept ID if term is empty
        ///
        /// Examples:
        /// - "73211009" + "Diabetes mellitus (disorder)" → "73211009-diabetes-mellitus"
        /// - "51451002" + "Arthrotomy of glenohumeral joint..." → "51451002-arthrotomy-of-glenohumeral-joint"
        static func sanitizeFilename(conceptId: String, conceptTerm: String) -> String {
            // If no term, just use concept ID
            guard !conceptTerm.isEmpty else {
                return conceptId
            }

            var sanitized = conceptTerm.lowercased()

            // Remove semantic tag (anything in parentheses at the end, e.g., "(disorder)", "(procedure)")
            if let lastParenIndex = sanitized.lastIndex(of: "(") {
                sanitized = String(sanitized[..<lastParenIndex])
            }

            // Keep only alphanumeric and spaces
            sanitized = sanitized.components(separatedBy: CharacterSet.alphanumerics.union(.whitespaces).inverted).joined()

            // Replace multiple spaces with single space
            sanitized = sanitized.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

            // Trim whitespace
            sanitized = sanitized.trimmingCharacters(in: .whitespaces)

            // Truncate to ~40 chars at word boundary
            if sanitized.count > 40 {
                if let truncateIndex = sanitized[..<sanitized.index(sanitized.startIndex, offsetBy: 40)].lastIndex(of: " ") {
                    sanitized = String(sanitized[..<truncateIndex])
                } else {
                    sanitized = String(sanitized.prefix(40))
                }
            }

            // Replace spaces with hyphens
            sanitized = sanitized.replacingOccurrences(of: " ", with: "-")

            // Remove trailing hyphens
            sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "-"))

            // Combine with concept ID
            if sanitized.isEmpty {
                return conceptId
            } else {
                return "\(conceptId)-\(sanitized)"
            }
        }
    }
}
