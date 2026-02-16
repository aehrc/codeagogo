import XCTest
import WebKit
@testable import Codeagogo

/// Tests for diagram rendering with actual API data
final class DiagramRendererTests: XCTestCase {

    /// Generates an image of the Panadol Night concept diagram for visual inspection.
    /// This test fetches real data from the server and renders the SVG to an image.
    func testGeneratePanadolNightDiagram() async throws {
        let conceptId = "1367601000168103"
        let system = "http://snomed.info/sct"

        // Create a concept result
        let conceptResult = ConceptResult(
            conceptId: conceptId,
            branch: "Australian (20260131)",
            fsn: "Panadol Night tablet",
            pt: "Panadol Night tablet",
            active: true,
            effectiveTime: "20240930",
            moduleId: "32506021000036107",
            system: system
        )

        // Use VisualizationViewModel to fetch properties AND definition status
        let viewModel = VisualizationViewModel()
        await viewModel.loadProperties(for: conceptResult)

        guard let data = viewModel.visualizationData else {
            XCTFail("Failed to load visualization data")
            return
        }

        print("Fetched \(data.properties.count) properties for concept \(conceptId)")
        print("Definition status map has \(data.definitionStatusMap.count) entries")

        // Generate HTML
        let html = DiagramRenderer.generateHTML(for: data)

        // Save HTML for inspection
        let htmlPath = "/tmp/panadol_night_diagram.html"
        try html.write(toFile: htmlPath, atomically: true, encoding: String.Encoding.utf8)
        print("Saved HTML to: \(htmlPath)")

        // Render to image
        let image = try await renderHTMLToImage(html: html, width: 1200, height: 1000)

        // Save image
        let imagePath = "/tmp/panadol_night_diagram.png"
        if let pngData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: pngData),
           let pngOutput = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) {
            try pngOutput.write(to: URL(fileURLWithPath: imagePath))
            print("Saved image to: \(imagePath)")
            print("Open with: open \(imagePath)")
        }

        // Test passes if we got here
        XCTAssertTrue(true, "Diagram generated successfully")
    }

    /// Renders HTML to an NSImage using WKWebView
    private func renderHTMLToImage(html: String, width: CGFloat, height: CGFloat) async throws -> NSImage {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: height))

                // Load HTML
                webView.loadHTMLString(html, baseURL: nil)

                // Wait for load to complete, then capture
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    let config = WKSnapshotConfiguration()
                    config.rect = NSRect(x: 0, y: 0, width: width, height: height)

                    webView.takeSnapshot(with: config) { image, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let image = image {
                            continuation.resume(returning: image)
                        } else {
                            continuation.resume(throwing: NSError(
                                domain: "DiagramRendererTests",
                                code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "Failed to capture image"]
                            ))
                        }
                    }
                }
            }
        }
    }
}
