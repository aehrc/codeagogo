import Foundation

/// Generates HTML visualizations for concept properties.
///
/// Creates different visualization styles depending on the code system:
/// - **SNOMED CT**: Relationship diagram following SNOMED CT Diagramming specification
/// - **LOINC/Other**: Simple property list with colored boxes
struct DiagramRenderer {
    /// Generates HTML for the visualization based on code system type.
    ///
    /// - Parameter data: The visualization data containing concept and properties
    /// - Returns: Complete HTML string ready to load in a WebView
    static func generateHTML(for data: VisualizationData) -> String {
        if data.isSNOMEDCT {
            return generateSNOMEDDiagram(data)
        } else {
            return generateLOINCDiagram(data)
        }
    }

    // MARK: - LOINC/Generic Diagram

    /// Generates a simple property list visualization for non-SNOMED systems.
    ///
    /// Creates a list of colored property boxes with their values, similar to
    /// the LOINC visualization reference design.
    private static func generateLOINCDiagram(_ data: VisualizationData) -> String {
        let propertiesHTML = data.properties.map { prop in
            let displayValue = htmlEscape(prop.value.displayString)
            let displayCode = htmlEscape(prop.display ?? prop.code)
            return """
            <div class="property-row">
                <div class="property-key">\(displayCode)</div>
                <div class="property-value">\(displayValue)</div>
            </div>
            """
        }.joined()

        let conceptDisplay = htmlEscape(data.concept.pt ?? data.concept.conceptId)

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    margin: 20px;
                    background: white;
                }
                .concept-header {
                    font-size: 14px;
                    font-weight: bold;
                    margin-bottom: 20px;
                    padding: 10px;
                    background: #f0f0f0;
                    border-radius: 4px;
                }
                .property-row {
                    display: flex;
                    margin-bottom: 8px;
                    align-items: center;
                }
                .property-key {
                    background: #e8b4b4;
                    padding: 6px 12px;
                    border-radius: 3px;
                    min-width: 120px;
                    font-weight: 500;
                    font-size: 13px;
                }
                .property-value {
                    margin-left: 12px;
                    padding: 6px 12px;
                    background: #f5f5f5;
                    border-radius: 3px;
                    flex: 1;
                    font-size: 13px;
                }
            </style>
        </head>
        <body>
            <div class="concept-header">\(htmlEscape(data.concept.conceptId)) | \(conceptDisplay)</div>
            \(propertiesHTML)
        </body>
        </html>
        """
    }

    // MARK: - SNOMED CT Diagram

    /// Generates a relationship diagram for SNOMED CT concepts.
    ///
    /// Following the SNOMED CT Diagramming specification, this creates an SVG-based
    /// diagram showing the concept's relationships and attributes.
    private static func generateSNOMEDDiagram(_ data: VisualizationData) -> String {
        // Look for normalForm (with terms) first, then normalFormTerse (IDs only) as fallback
        let normalFormProp = data.properties.first { $0.code == "normalForm" }
            ?? data.properties.first { $0.code == "normalFormTerse" }

        // If we have normal form, parse and render it
        if let normalForm = normalFormProp?.value.displayString {
            return generateFromNormalForm(normalForm, data: data)
        }

        // Fallback to simple property listing if no normal form available
        return generateSimpleSNOMEDDiagram(data)
    }

    /// Generates diagram from parsed SNOMED CT normal form.
    private static func generateFromNormalForm(_ normalForm: String, data: VisualizationData) -> String {
        // Clean up the normal form - remove line breaks and normalize whitespace
        let cleaned = normalForm
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            // Replace multiple spaces with single space
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse the normal form expression
        let parser = SNOMEDExpressionParser(input: cleaned)

        let expression: SNOMEDExpression
        do {
            expression = try parser.parse()

            // Debug: log parsed expression
            print("✅ Parsed expression: \(expression.debugDescription)")
            print("   - Concept being defined: \(data.concept.conceptId)")
            print("   - Focus concepts in normal form: \(expression.focusConcepts.map { $0.conceptId }.joined(separator: ", "))")
            if let ref = expression.refinement {
                print("   - Attribute groups: \(ref.attributeGroups.count)")
                print("   - Ungrouped attributes: \(ref.ungroupedAttributes.count)")
            } else {
                print("   - No refinement found!")
            }

            // Check if the normal form incorrectly has the concept as its own parent
            // This can happen with primitive concepts - if so, replace with actual parent
            if expression.focusConcepts.count == 1 &&
               expression.focusConcepts[0].conceptId == data.concept.conceptId {
                print("⚠️ Normal form has concept as its own parent - looking for parent property")

                // Find ALL parent properties (there may be multiple)
                let parentProps = data.properties.filter { $0.code == "parent" }
                if !parentProps.isEmpty {
                    // Extract ALL parent IDs from ALL parent properties
                    var allParentIds: [String] = []

                    for parentProp in parentProps {
                        // Handle different value types
                        switch parentProp.value {
                        case .coding(let coding):
                            if let code = coding.code {
                                allParentIds.append(code)
                            }

                        case .string(let str):
                            // Extract ALL IDs from the string (may be multiple parents joined by +)
                            let pattern = #"\b(\d{6,18})\b"#
                            if let regex = try? NSRegularExpression(pattern: pattern) {
                                let range = NSRange(str.startIndex..., in: str)
                                let matches = regex.matches(in: str, range: range)
                                for match in matches {
                                    if let matchRange = Range(match.range(at: 1), in: str) {
                                        allParentIds.append(String(str[matchRange]))
                                    }
                                }
                            }

                        case .code(let code):
                            allParentIds.append(code)

                        default:
                            print("⚠️ Unexpected parent property value type: \(parentProp.value)")
                        }
                    }

                    guard !allParentIds.isEmpty else {
                        print("⚠️ No parent IDs extracted from \(parentProps.count) parent properties")
                        return generateSimpleSNOMEDDiagram(data)
                    }

                    print("✅ Found \(parentProps.count) parent properties with \(allParentIds.count) total parent ID(s): \(allParentIds.joined(separator: ", "))")

                    // Create concept references for all parents, using display names from the map
                    let parentRefs = allParentIds.map { parentId in
                        let displayName = data.displayName(for: parentId)
                        return SNOMEDConceptReference(conceptId: parentId, term: displayName)
                    }

                    // Create a new expression with ALL correct parents
                    let correctedExpression = SNOMEDExpression(
                        definitionStatus: expression.definitionStatus,
                        focusConcepts: parentRefs,
                        refinement: expression.refinement
                    )

                    // Continue with normal diagram generation using corrected expression
                    let diagramSVG = generateDiagramSVG(correctedExpression, conceptDisplay: data.concept.pt ?? data.concept.conceptId, data: data)

                    // Return the full HTML (copy the code from below)
                    let metadataProperties = ["effectiveTime", "moduleId", "inactive", "sufficientlyDefined"]
                    let attributes = data.properties.filter { prop in
                        metadataProperties.contains(prop.code)
                    }

                    let attributesHTML = attributes.map { attr in
                        let displayValue = htmlEscape(attr.value.displayString)
                        let displayCode = htmlEscape(attr.code)
                        return """
                        <div class="attribute-row">
                            <span class="attribute-key">\(displayCode)</span>
                            <span class="attribute-value">\(displayValue)</span>
                        </div>
                        """
                    }.joined()

                    return generateFullDiagramHTML(
                        diagramSVG: diagramSVG,
                        attributesHTML: attributesHTML,
                        hasAttributes: !attributes.isEmpty,
                        conceptId: data.concept.conceptId,
                        conceptTerm: data.concept.pt ?? data.concept.fsn
                    )
                } else {
                    print("⚠️ No parent property found - falling back to simple diagram")
                    return generateSimpleSNOMEDDiagram(data)
                }
            }
        } catch {
            // Log the specific error
            print("❌ Failed to parse normal form")
            print("   Error: \(error)")
            print("   Input (first 200 chars): \(String(cleaned.prefix(200)))")
            return generateNormalFormText(normalForm, data: data)
        }

        // Get metadata properties
        let metadataProperties = ["effectiveTime", "moduleId", "inactive", "sufficientlyDefined"]
        let attributes = data.properties.filter { prop in
            metadataProperties.contains(prop.code)
        }

        let attributesHTML = attributes.map { attr in
            let displayValue = htmlEscape(attr.value.displayString)
            let displayCode = htmlEscape(attr.code)
            return """
            <div class="attribute-row">
                <span class="attribute-key">\(displayCode)</span>
                <span class="attribute-value">\(displayValue)</span>
            </div>
            """
        }.joined()

        // Generate SVG diagram from expression with definition status
        let diagramSVG = generateDiagramSVG(expression, conceptDisplay: data.concept.pt ?? data.concept.conceptId, data: data)

        return generateFullDiagramHTML(
            diagramSVG: diagramSVG,
            attributesHTML: attributesHTML,
            hasAttributes: !attributes.isEmpty,
            conceptId: data.concept.conceptId,
            conceptTerm: data.concept.pt ?? data.concept.fsn
        )
    }

    /// Generates SVG diagram from parsed SNOMED CT expression with definition status.
    private static func generateDiagramSVG(_ expression: SNOMEDExpression, conceptDisplay: String, data: VisualizationData) -> String {
        var svgElements: [String] = []
        var currentY = 5  // Start higher
        let startX = 10    // Start more to the left

        // Get focus concept ID from data
        let focusConceptId = data.concept.conceptId
        let isFocusDefined = data.isDefinedConcept(focusConceptId) ?? false

        // Determine focus box color based on definition status
        let focusColor = isFocusDefined ? (fill: "#CCCCFF", stroke: "#6666CC") : (fill: "#99CCFF", stroke: "#3366CC")

        // Draw focus concept at top with status-based color (ID + wrapped term)
        // Calculate width based on actual text content
        let focusMaxWidth = 400
        let idWidth = focusConceptId.count * 5 + 20  // ID width estimate
        let termWidth = min(conceptDisplay.count * 5 + 20, focusMaxWidth - 20)  // Term width estimate
        let focusWidth = min(max(idWidth, termWidth, 100) + 20, focusMaxWidth)  // Use longest + padding
        let (focusTextSVG, focusLines) = generateConceptText(
            id: focusConceptId,
            term: conceptDisplay,
            x: startX + 7,
            y: currentY + 12,
            maxWidth: focusWidth - 20
        )
        let focusBoxHeight = max(30, 10 + focusLines * 11)
        let focusBoxY = currentY

        // Draw outer rectangle
        svgElements.append("""
            <rect x="\(startX)" y="\(focusBoxY)" width="\(focusWidth)" height="\(focusBoxHeight)" rx="3" fill="\(focusColor.fill)" stroke="\(focusColor.stroke)" stroke-width="1.5"/>
        """)

        // Draw inner rectangle for double border if defined
        if isFocusDefined {
            svgElements.append("""
                <rect x="\(startX + 3)" y="\(focusBoxY + 3)" width="\(focusWidth - 6)" height="\(focusBoxHeight - 6)" rx="2" fill="none" stroke="\(focusColor.stroke)" stroke-width="1"/>
            """)
        }

        svgElements.append(focusTextSVG)

        // Initial vertical line from focus box
        let symbolCircleX = startX + 15
        currentY = focusBoxY + focusBoxHeight

        // Draw vertical line down from focus box to symbol
        svgElements.append("""
            <line x1="\(symbolCircleX)" y1="\(currentY)" x2="\(symbolCircleX)" y2="\(currentY + 20)" stroke="#000" stroke-width="2"/>
        """)
        currentY += 20

        // Draw definition status symbol in a circle
        let symbolY = currentY
        let symbol: String
        if expression.definitionStatus == .defined {
            // Equivalence symbol (≡) for defined concepts
            symbol = """
            <circle cx="\(symbolCircleX)" cy="\(symbolY)" r="10" fill="white" stroke="#000" stroke-width="2"/>
            <line x1="\(symbolCircleX - 6)" y1="\(symbolY - 3)" x2="\(symbolCircleX + 6)" y2="\(symbolY - 3)" stroke="#000" stroke-width="1.5"/>
            <line x1="\(symbolCircleX - 6)" y1="\(symbolY)" x2="\(symbolCircleX + 6)" y2="\(symbolY)" stroke="#000" stroke-width="1.5"/>
            <line x1="\(symbolCircleX - 6)" y1="\(symbolY + 3)" x2="\(symbolCircleX + 6)" y2="\(symbolY + 3)" stroke="#000" stroke-width="1.5"/>
            """
        } else {
            // Subsumed by symbol (⊑) for primitive concepts
            symbol = """
            <circle cx="\(symbolCircleX)" cy="\(symbolY)" r="10" fill="white" stroke="#000" stroke-width="2"/>
            <text x="\(symbolCircleX)" y="\(symbolY + 5)" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, sans-serif" font-size="16" font-weight="bold">⊑</text>
            """
        }
        svgElements.append(symbol)

        // Horizontal line from symbol to tree junction
        let treeX = symbolCircleX + 35  // Tree line at x=50 (15+35)
        currentY = symbolY
        svgElements.append("""
            <line x1="\(symbolCircleX + 10)" y1="\(symbolY)" x2="\(treeX)" y2="\(symbolY)" stroke="#000" stroke-width="2"/>
        """)

        // Draw conjunction dot at tree junction
        svgElements.append("""
            <circle cx="\(treeX)" cy="\(symbolY)" r="4" fill="black" stroke="black" stroke-width="1"/>
        """)

        // Vertical line down from junction (this will be calculated for proper end point)
        let treeStartY = symbolY

        // Track rightmost element (start with focus box)
        var maxX = startX + focusWidth
        var parentEndY = symbolY  // Track where parents end vertically

        // Draw parent concept(s) with status-based color - aligned with horizontal line
        if !expression.focusConcepts.isEmpty {
            let parentSpacing = 10  // Vertical spacing between multiple parents
            var parentYOffset = 0  // Track Y offset for multiple parents
            var parentYPositions: [(y: Int, height: Int)] = []  // Track Y positions for vertical line

            for (index, parentRef) in expression.focusConcepts.enumerated() {
                let parentConceptId = parentRef.conceptId
                let isParentDefined = data.isDefinedConcept(parentConceptId) ?? false
                let parentColor = isParentDefined ? (fill: "#CCCCFF", stroke: "#6666CC") : (fill: "#99CCFF", stroke: "#3366CC")

                let parentTerm = parentRef.term ?? parentRef.conceptId
                // Calculate width based on actual text content
                let parentMaxWidth = 500
                let parentIdWidth = parentConceptId.count * 5 + 20  // ID width estimate
                let parentTermWidth = min(parentTerm.count * 5 + 20, parentMaxWidth - 20)  // Term width estimate
                let parentWidth = min(max(parentIdWidth, parentTermWidth, 100) + 20, parentMaxWidth)  // Use longest + padding
                let (parentTextSVG, parentLines) = generateConceptText(
                    id: parentConceptId,
                    term: parentTerm,
                    x: treeX + 35 + 8,
                    y: symbolY - 10,  // Will be adjusted based on height
                    maxWidth: parentWidth - 20
                )
                let parentBoxHeight = max(30, 10 + parentLines * 11)

                let parentX = treeX + 35

                // For first parent, center on horizontal line. For subsequent parents, stack below.
                let parentY: Int
                if index == 0 {
                    parentY = symbolY - (parentBoxHeight / 2)  // Center on horizontal line
                } else {
                    parentY = parentYOffset  // Use accumulated offset
                }

                // Track Y offset for next parent and overall end position
                parentYOffset = parentY + parentBoxHeight + parentSpacing
                parentEndY = max(parentEndY, parentY + parentBoxHeight)

                // Store parent Y position and height for drawing vertical line later
                parentYPositions.append((y: parentY, height: parentBoxHeight))

                // Arrow Y is at the middle of the parent box
                let arrowY = parentY + (parentBoxHeight / 2)

                // Draw horizontal line with open-headed arrow from tree X to parent
                svgElements.append("""
                    <line x1="\(treeX)" y1="\(arrowY)" x2="\(parentX)" y2="\(arrowY)" stroke="#000" stroke-width="2" marker-end="url(#isA)"/>
                """)

                // Draw parent box with double border if defined
                svgElements.append("""
                    <rect x="\(parentX)" y="\(parentY)" width="\(parentWidth)" height="\(parentBoxHeight)" rx="3" fill="\(parentColor.fill)" stroke="\(parentColor.stroke)" stroke-width="1.5"/>
                """)

                if isParentDefined {
                    svgElements.append("""
                        <rect x="\(parentX + 3)" y="\(parentY + 3)" width="\(parentWidth - 6)" height="\(parentBoxHeight - 6)" rx="2" fill="none" stroke="\(parentColor.stroke)" stroke-width="1"/>
                    """)
                }

                // Adjust text Y position for proper centering
                let adjustedTextY = parentY + 12
                let adjustedTextSVG = parentTextSVG.replacingOccurrences(of: "y=\"\(symbolY - 10)\"", with: "y=\"\(adjustedTextY)\"")
                svgElements.append(adjustedTextSVG)

                maxX = max(maxX, parentX + parentWidth)
            }

            // If there are multiple parents, draw a vertical line from tree junction through all parents
            if expression.focusConcepts.count > 1 {
                let firstParentMidY = parentYPositions[0].y + (parentYPositions[0].height / 2)
                let lastParentMidY = parentYPositions[parentYPositions.count - 1].y + (parentYPositions[parentYPositions.count - 1].height / 2)
                svgElements.insert("""
                    <line x1="\(treeX)" y1="\(firstParentMidY)" x2="\(treeX)" y2="\(lastParentMidY)" stroke="#000" stroke-width="2"/>
                """, at: svgElements.count - expression.focusConcepts.count * 4)  // Insert before parent elements
            }
        }

        // Set currentY to start role groups below the symbol/parent area
        // Use the actual end of parent boxes plus spacing
        currentY = max(symbolY + 32, parentEndY + 15)

        // Draw refinement (attribute groups and ungrouped attributes)
        var treeEndY = currentY

        if let refinement = expression.refinement {
            // Separate multi-attribute groups from single-attribute groups
            // Single-attribute groups should be treated as ungrouped
            var multiAttrGroups: [SNOMEDAttributeGroup] = []
            var singleAttrGroups: [SNOMEDAttribute] = []

            for group in refinement.attributeGroups {
                if group.attributes.count > 1 {
                    multiAttrGroups.append(group)
                } else if group.attributes.count == 1 {
                    singleAttrGroups.append(group.attributes[0])
                }
            }

            // Combine single-attribute groups with ungrouped attributes
            let allUngrouped = singleAttrGroups + refinement.ungroupedAttributes

            // Reverse the order of multi-attribute groups to match target diagram
            // (Paracetamol should come before Diphenhydramine)
            let reversedGroups = multiAttrGroups.reversed()

            let adjustedRefinement = SNOMEDRefinement(
                attributeGroups: Array(reversedGroups),
                ungroupedAttributes: allUngrouped
            )

            let result = drawRefinement(adjustedRefinement, startY: currentY, treeX: treeX, treeStartY: treeStartY, svgElements: &svgElements, data: data)
            currentY = result.endY
            maxX = max(maxX, result.maxX)
            treeEndY = result.treeEndY
        }

        // Calculate tight bounds for SVG
        let svgWidth = maxX + 20
        let svgHeight = currentY + 20

        return """
        <svg width="\(svgWidth)" height="\(svgHeight)" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <marker id="isA" markerWidth="8" markerHeight="6" refX="8" refY="3" orient="auto">
                    <path d="M0,0 L8,3 L0,6 Z" fill="white" stroke="#000" stroke-width="1.5" stroke-linejoin="miter"/>
                </marker>
            </defs>
            \(svgElements.joined(separator: "\n"))
        </svg>
        """
    }

    /// Draws refinement (attribute groups and ungrouped attributes).
    /// Returns (endY, maxX, treeEndY) for layout calculation
    private static func drawRefinement(_ refinement: SNOMEDRefinement, startY: Int, treeX: Int, treeStartY: Int, svgElements: inout [String], data: VisualizationData) -> (endY: Int, maxX: Int, treeEndY: Int) {
        var currentY = startY
        let circleX = treeX + 15   // Circle position relative to tree
        let dotX = circleX + 12    // Small dot after circle
        let vertLineX = dotX + 15  // Vertical line through attributes
        let attrStartX = vertLineX + 15  // Where attribute names start
        let attributeHeight = 26  // Height per attribute
        let groupSpacing = 2      // Minimal space between groups

        var maxX = treeX  // Track rightmost element
        var lastCircleY = startY  // Track last role group circle Y for tree line end

        // Draw attribute groups
        for group in refinement.attributeGroups {
            let groupStartY = currentY + 4
            lastCircleY = groupStartY  // Track for tree line end

            // Draw horizontal line from tree to circle
            svgElements.append("""
                <line x1="\(treeX)" y1="\(groupStartY)" x2="\(circleX)" y2="\(groupStartY)" stroke="#000" stroke-width="2"/>
            """)

            // Draw open circle for role group
            svgElements.append("""
                <circle cx="\(circleX)" cy="\(groupStartY)" r="7" fill="white" stroke="#000" stroke-width="2"/>
            """)

            // Draw small filled dot after circle
            svgElements.append("""
                <circle cx="\(dotX)" cy="\(groupStartY)" r="3" fill="#000"/>
            """)

            // Draw horizontal line from dot to vertical line start
            svgElements.append("""
                <line x1="\(dotX)" y1="\(groupStartY)" x2="\(vertLineX)" y2="\(groupStartY)" stroke="#000" stroke-width="1.5"/>
            """)

            // Draw each attribute in the group (we'll draw the vertical line after to get correct end position)
            var attrY = groupStartY
            var lastAttrY = groupStartY
            var lastHeight = 0
            for attribute in group.attributes {
                // Draw horizontal line from vertical line to attribute start
                svgElements.append("""
                    <line x1="\(vertLineX)" y1="\(attrY)" x2="\(attrStartX)" y2="\(attrY)" stroke="#000" stroke-width="1"/>
                """)

                let (attrMaxX, attrHeight) = drawAttribute(attribute, x: attrStartX, y: attrY, svgElements: &svgElements, data: data)
                maxX = max(maxX, attrMaxX)
                lastAttrY = attrY  // Track the Y position of the last attribute
                lastHeight = attrHeight
                attrY += max(attrHeight + 5, attributeHeight)  // Use dynamic height + spacing, minimum attributeHeight
            }

            // Draw vertical line down through all attributes in this group (now that we know the actual end position)
            svgElements.append("""
                <line x1="\(vertLineX)" y1="\(groupStartY)" x2="\(vertLineX)" y2="\(lastAttrY)" stroke="#000" stroke-width="1.5"/>
            """)

            // Add spacing for gap between groups
            currentY = attrY - lastHeight + 30
        }

        // Draw ungrouped attributes
        for attribute in refinement.ungroupedAttributes {
            let attrY = currentY + 4
            lastCircleY = attrY  // Track for tree line end

            // Draw horizontal line from tree to circle
            svgElements.append("""
                <line x1="\(treeX)" y1="\(attrY)" x2="\(circleX)" y2="\(attrY)" stroke="#000" stroke-width="2"/>
            """)

            // Draw open circle for ungrouped attribute
            svgElements.append("""
                <circle cx="\(circleX)" cy="\(attrY)" r="7" fill="white" stroke="#000" stroke-width="2"/>
            """)

            // Draw small filled dot after circle
            svgElements.append("""
                <circle cx="\(dotX)" cy="\(attrY)" r="3" fill="#000"/>
            """)

            // Draw horizontal line from dot to attribute
            svgElements.append("""
                <line x1="\(dotX)" y1="\(attrY)" x2="\(attrStartX)" y2="\(attrY)" stroke="#000" stroke-width="1"/>
            """)

            let (attrMaxX, attrHeight) = drawAttribute(attribute, x: attrStartX, y: attrY, svgElements: &svgElements, data: data)
            maxX = max(maxX, attrMaxX)
            currentY = attrY + max(attrHeight + 0, 28)  // Dynamic spacing based on height
        }

        // Draw the main tree vertical line from start to last circle (insert at beginning so it's behind everything)
        svgElements.insert("""
            <line x1="\(treeX)" y1="\(treeStartY)" x2="\(treeX)" y2="\(lastCircleY)" stroke="#000" stroke-width="2"/>
        """, at: 0)

        return (endY: currentY + 20, maxX: maxX, treeEndY: lastCircleY)
    }

    /// Draws a single attribute with its value.
    /// Returns (maxX, height) where height is the tallest element drawn (for spacing calculation)
    private static func drawAttribute(_ attribute: SNOMEDAttribute, x: Int, y: Int, svgElements: inout [String], data: VisualizationData) -> (maxX: Int, height: Int) {
        // Use two-row format for attribute name: ID on first row, term on second row
        let attrTerm = attribute.name.term ?? attribute.name.conceptId
        let attrId = attribute.name.conceptId
        let maxAttrWidth = 300  // Max width for attribute pill

        // Calculate actual width needed based on text content
        let attrIdWidth = attrId.count * 5 + 20  // ID width estimate
        let attrTermWidth = min(attrTerm.count * 5 + 20, maxAttrWidth - 20)  // Term width estimate
        let attrWidth = min(max(attrIdWidth, attrTermWidth, 90) + 20, maxAttrWidth)  // Use longest + padding

        let (attrTextSVG, attrLines) = generateConceptText(
            id: attrId,
            term: attrTerm,
            x: x + 8,
            y: y - 12 + 12,
            maxWidth: attrWidth - 20
        )
        let attrHeight = max(24, 10 + attrLines * 11)

        // Calculate Y position to center the attribute pill on y
        let attrBoxY = y - (attrHeight / 2)

        // Draw attribute name with double border (per SNOMED CT spec)
        svgElements.append("""
            <rect x="\(x)" y="\(attrBoxY)" width="\(attrWidth)" height="\(attrHeight)" rx="\(attrHeight/2)" fill="#FFFFCC" stroke="#000" stroke-width="1.5"/>
            <rect x="\(x + 3)" y="\(attrBoxY + 3)" width="\(attrWidth - 6)" height="\(attrHeight - 6)" rx="\((attrHeight-6)/2)" fill="none" stroke="#000" stroke-width="1"/>
        """)

        // Adjust text Y position for proper centering in the taller box
        let adjustedTextY = attrBoxY + 12
        let adjustedAttrTextSVG = attrTextSVG.replacingOccurrences(of: "y=\"\(y - 12 + 12)\"", with: "y=\"\(adjustedTextY)\"")
        svgElements.append(adjustedAttrTextSVG)

        // Draw short line to value - standard short distance from attribute
        let lineStartX = x + attrWidth
        let valueX = lineStartX + 8  // Standard 8px gap
        svgElements.append("""
            <line x1="\(lineStartX)" y1="\(y)" x2="\(valueX)" y2="\(y)" stroke="#000" stroke-width="1.5"/>
        """)

        // Determine value text, color, and dimensions based on type
        let valueColor: (fill: String, stroke: String, textColor: String)
        var isValueDefined = false  // Track if value is a defined concept for double border
        var valueWidth: Int
        var valueHeight: Int
        var valueTextSVG: String

        switch attribute.value {
        case .conceptReference(let ref):
            // Use two-row format: ID on first row, wrapped term on following rows
            let valueTerm = ref.term ?? ref.conceptId
            let maxValueWidth = 400  // Reasonable max width

            // Calculate width based on actual text content
            let valueIdWidth = ref.conceptId.count * 5 + 20  // ID width estimate
            let valueTermWidth = min(valueTerm.count * 5 + 20, maxValueWidth - 20)  // Term width estimate
            valueWidth = min(max(valueIdWidth, valueTermWidth, 75) + 20, maxValueWidth)  // Use longest + padding

            let (textSVG, lines) = generateConceptText(
                id: ref.conceptId,
                term: valueTerm,
                x: valueX + 6,
                y: y - 12 + 12,
                maxWidth: valueWidth - 20
            )
            valueTextSVG = textSVG
            valueHeight = max(24, 10 + lines * 11)

            // Determine color based on whether concept is defined or primitive
            isValueDefined = data.isDefinedConcept(ref.conceptId) ?? false
            valueColor = isValueDefined
                ? (fill: "#CCCCFF", stroke: "#6666CC", textColor: "#000")  // Purple for defined
                : (fill: "#99CCFF", stroke: "#3366CC", textColor: "#000")  // Blue for primitive

        case .concreteValue(let val):
            // Format concrete values: remove # prefix, add = prefix, clean up decimals and quotes
            var cleanValue = val
            if cleanValue.hasPrefix("#") {
                cleanValue = String(cleanValue.dropFirst())
                // Remove .0 from whole numbers
                if cleanValue.hasSuffix(".0") {
                    cleanValue = String(cleanValue.dropLast(2))
                }
                cleanValue = "= " + cleanValue
            } else if cleanValue.hasPrefix("\"") && cleanValue.hasSuffix("\"") {
                // Remove quotes and add = prefix
                cleanValue = String(cleanValue.dropFirst().dropLast())
                cleanValue = "= " + cleanValue
            }
            let valueText = htmlEscape(cleanValue)
            // Single-line text for concrete values
            valueTextSVG = """
                <text x="\(valueX + 6)" y="\(y + 4)" font-size="11" font-family="-apple-system, BlinkMacSystemFont, sans-serif">\(valueText)</text>
            """
            valueWidth = max(50, min(valueText.count * 5 + 16, 250))
            valueHeight = 24
            // Green for concrete data values
            valueColor = (fill: "#A5E0B6", stroke: "#5CB574", textColor: "#000")

        case .expression(let expr):
            // Extract the focus concept and use two-row format
            if let focusConcept = expr.focusConcepts.first {
                let valueTerm = focusConcept.term ?? focusConcept.conceptId
                let maxValueWidth = 400  // Reasonable max width

                // Calculate width based on actual text content
                let valueIdWidth = focusConcept.conceptId.count * 5 + 20  // ID width estimate
                let valueTermWidth = min(valueTerm.count * 5 + 20, maxValueWidth - 20)  // Term width estimate
                valueWidth = min(max(valueIdWidth, valueTermWidth, 75) + 20, maxValueWidth)  // Use longest + padding

                let (textSVG, lines) = generateConceptText(
                    id: focusConcept.conceptId,
                    term: valueTerm,
                    x: valueX + 6,
                    y: y - 12 + 12,
                    maxWidth: valueWidth - 20
                )
                valueTextSVG = textSVG
                valueHeight = max(24, 10 + lines * 11)

                // Determine color based on definition status
                isValueDefined = data.isDefinedConcept(focusConcept.conceptId) ?? false
                valueColor = isValueDefined
                    ? (fill: "#CCCCFF", stroke: "#6666CC", textColor: "#000")  // Purple for defined
                    : (fill: "#99CCFF", stroke: "#3366CC", textColor: "#000")  // Blue for primitive
            } else {
                // Fallback for nested expressions without focus concept
                let valueText = "(nested)"
                valueTextSVG = """
                    <text x="\(valueX + 6)" y="\(y + 4)" font-size="11" font-family="-apple-system, BlinkMacSystemFont, sans-serif">\(valueText)</text>
                """
                valueWidth = max(50, min(valueText.count * 5 + 16, 250))
                valueHeight = 24
                valueColor = (fill: "#99CCFF", stroke: "#3366CC", textColor: "#000")
            }
        }

        // Calculate the Y position for the value box (center it on the attribute Y position)
        let valueBoxY = y - (valueHeight / 2)

        // Draw value box with double border if defined concept
        svgElements.append("""
            <rect x="\(valueX)" y="\(valueBoxY)" width="\(valueWidth)" height="\(valueHeight)" rx="3" fill="\(valueColor.fill)" stroke="\(valueColor.stroke)" stroke-width="1.5"/>
        """)

        if isValueDefined {
            svgElements.append("""
                <rect x="\(valueX + 3)" y="\(valueBoxY + 3)" width="\(valueWidth - 6)" height="\(valueHeight - 6)" rx="2" fill="none" stroke="\(valueColor.stroke)" stroke-width="1"/>
            """)
        }

        svgElements.append(valueTextSVG)

        // Return rightmost X coordinate and height of tallest element
        let maxHeight = max(attrHeight, valueHeight)
        return (maxX: valueX + valueWidth, height: maxHeight)
    }

    /// Generates fallback text display for normal form.
    private static func generateNormalFormText(_ normalForm: String, data: VisualizationData) -> String {
        let metadataProperties = ["effectiveTime", "moduleId", "inactive", "sufficientlyDefined"]
        let attributes = data.properties.filter { prop in
            metadataProperties.contains(prop.code)
        }

        let attributesHTML = attributes.map { attr in
            let displayValue = htmlEscape(attr.value.displayString)
            let displayCode = htmlEscape(attr.code)
            return """
            <div class="attribute-row">
                <span class="attribute-key">\(displayCode)</span>
                <span class="attribute-value">\(displayValue)</span>
            </div>
            """
        }.joined()

        var formatted = htmlEscape(normalForm)
        formatted = formatted.replacingOccurrences(of: "===", with: "<strong style='color: #e74c3c;'>===</strong>")
        formatted = formatted.replacingOccurrences(of: "{", with: "<strong style='color: #3498db;'>{</strong>")
        formatted = formatted.replacingOccurrences(of: "}", with: "<strong style='color: #3498db;'>}</strong>")

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    margin: 20px;
                    background: white;
                    font-size: 12px;
                }
                .normal-form-section {
                    margin: 20px 0;
                    font-family: monospace;
                    font-size: 11px;
                    line-height: 1.6;
                    white-space: pre-wrap;
                    background: #f8f8f8;
                    padding: 15px;
                    border-radius: 4px;
                    border-left: 4px solid #4a90e2;
                }
                .attributes-section {
                    margin-top: 10px;
                    padding: 15px;
                    background: #f9f9f9;
                    border-radius: 4px;
                    border-left: 4px solid #cd853f;
                }
                .attribute-row {
                    margin-bottom: 5px;
                    font-size: 12px;
                }
                .attribute-key {
                    background: #cd853f;
                    color: white;
                    padding: 2px 8px;
                    border-radius: 3px;
                    font-weight: 500;
                    display: inline-block;
                    min-width: 100px;
                }
                .attribute-value {
                    color: #000;
                    margin-left: 10px;
                    background: white;
                    padding: 2px 8px;
                    border-radius: 3px;
                }
            </style>
        </head>
        <body>
            <div class="normal-form-section">\(formatted)</div>
            \(attributes.isEmpty ? "" : """
            <div class="attributes-section">
                \(attributesHTML)
            </div>
            """)
        </body>
        </html>
        """
    }

    /// Fallback diagram for concepts without normal form.
    private static func generateSimpleSNOMEDDiagram(_ data: VisualizationData) -> String {
        // Separate metadata properties from relationships
        let metadataProperties = ["effectiveTime", "moduleId", "inactive", "sufficientlyDefined"]
        let attributes = data.properties.filter { prop in
            metadataProperties.contains(prop.code)
        }

        // Find parent relationship for "Is a"
        let parentProp = data.properties.first { $0.code == "parent" }

        // Get all other relationships (excluding parent and metadata)
        let relationships = data.properties.filter { prop in
            prop.code != "parent" && !metadataProperties.contains(prop.code)
        }

        // Build the attributes HTML (effectiveTime, moduleId at bottom)
        let attributesHTML = attributes.map { attr in
            let displayValue = htmlEscape(attr.value.displayString)
            let displayCode = htmlEscape(attr.code)
            return """
            <div class="attribute-row">
                <span class="attribute-key">\(displayCode)</span>
                <span class="attribute-value">\(displayValue)</span>
            </div>
            """
        }.joined()

        // Build the relationships tree (simplified hierarchical layout)
        var relationshipsHTML = ""
        if !relationships.isEmpty {
            relationshipsHTML = generateRelationshipsTree(relationships)
        }

        let conceptDisplay = htmlEscape(data.concept.pt ?? data.concept.conceptId)
        let parentDisplay = parentProp.map { htmlEscape($0.value.displayString) } ?? ""

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    margin: 20px;
                    background: white;
                    font-size: 13px;
                }
                .diagram-container {
                    padding: 20px;
                    overflow-x: auto;
                }
                .concept-box {
                    border: 2px solid #333;
                    border-radius: 4px;
                    padding: 8px 12px;
                    background: white;
                    display: inline-block;
                    margin: 10px 0;
                }
                .parent-section {
                    text-align: center;
                    margin-bottom: 30px;
                }
                .is-a-arrow {
                    text-align: center;
                    color: #666;
                    margin: 5px 0;
                    font-size: 12px;
                }
                .relationships-section {
                    margin-left: 40px;
                    margin-top: 10px;
                }
                .relationship-group {
                    margin: 15px 0;
                    padding-left: 20px;
                    border-left: 3px solid #ddd;
                }
                .relationship-row {
                    margin: 8px 0;
                    display: flex;
                    align-items: center;
                }
                .relationship-label {
                    background: #FFFFCC;
                    border-radius: 12px;
                    padding: 4px 10px;
                    margin-right: 8px;
                    font-weight: 500;
                    font-size: 12px;
                    white-space: nowrap;
                }
                .relationship-value {
                    background: #e6f2ff;
                    border: 1px solid #b3d9ff;
                    border-radius: 3px;
                    padding: 4px 10px;
                    font-size: 12px;
                }
                .attributes-section {
                    margin-top: 30px;
                    padding: 15px;
                    background: #f9f9f9;
                    border-radius: 4px;
                    border-left: 4px solid #cd853f;
                }
                .attributes-title {
                    font-weight: bold;
                    margin-bottom: 10px;
                    font-size: 13px;
                }
                .attribute-row {
                    margin-bottom: 5px;
                    font-size: 12px;
                }
                .attribute-key {
                    background: #cd853f;
                    color: white;
                    padding: 2px 8px;
                    border-radius: 3px;
                    font-weight: 500;
                    display: inline-block;
                    min-width: 100px;
                }
                .attribute-value {
                    color: #000;
                    margin-left: 10px;
                    background: white;
                    padding: 2px 8px;
                    border-radius: 3px;
                }
            </style>
        </head>
        <body>
            <div class="diagram-container">
                <!-- Concept at top -->
                <div class="parent-section">
                    <div class="concept-box">\(conceptDisplay)</div>
                    \(parentDisplay.isEmpty ? "" : """
                    <div class="is-a-arrow">↓ Is a</div>
                    <div class="concept-box">\(parentDisplay)</div>
                    """)
                </div>

                <!-- Relationships -->
                \(relationshipsHTML)
            </div>

            <!-- Attributes at bottom -->
            \(attributes.isEmpty ? "" : """
            <div class="attributes-section">
                <div class="attributes-title">Metadata</div>
                \(attributesHTML)
            </div>
            """)
        </body>
        </html>
        """
    }

    /// Generates HTML for relationships tree structure.
    private static func generateRelationshipsTree(_ relationships: [ConceptProperty]) -> String {
        guard !relationships.isEmpty else { return "" }

        let rows = relationships.map { prop -> String in
            let label = htmlEscape(prop.display ?? prop.code)
            let value = htmlEscape(prop.value.displayString)
            return """
            <div class="relationship-row">
                <span class="relationship-label">\(label)</span>
                <span class="relationship-value">\(value)</span>
            </div>
            """
        }.joined()

        return """
        <div class="relationships-section">
            <div class="relationship-group">
                \(rows)
            </div>
        </div>
        """
    }

    // MARK: - Helper Methods

    /// Generates the complete HTML wrapper for a SNOMED diagram.
    private static func generateFullDiagramHTML(diagramSVG: String, attributesHTML: String, hasAttributes: Bool, conceptId: String, conceptTerm: String?) -> String {
        // Escape concept info for JavaScript
        let jsConceptId = conceptId.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        let jsConceptTerm = (conceptTerm ?? "").replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    margin: 20px;
                    background: white;
                    font-size: 12px;
                }
                .controls {
                    margin: 10px 20px;
                    display: flex;
                    gap: 10px;
                    align-items: center;
                }
                .controls button {
                    padding: 6px 12px;
                    background: #007aff;
                    color: white;
                    border: none;
                    border-radius: 4px;
                    cursor: pointer;
                    font-size: 12px;
                }
                .controls button:hover {
                    background: #0051d5;
                }
                .controls .zoom-label {
                    font-size: 12px;
                    color: #666;
                    min-width: 60px;
                }
                .diagram-container {
                    margin: 20px;
                    overflow: auto;
                    border: 1px solid #ddd;
                    background: #fafafa;
                    display: flex;
                    justify-content: flex-start;
                    align-items: flex-start;
                    min-height: 400px;
                }
                .diagram-wrapper {
                    transition: transform 0.2s ease;
                    transform-origin: top left;
                }
                .attributes-section {
                    margin-top: 10px;
                    padding: 15px;
                    background: #f9f9f9;
                    border-radius: 4px;
                    border-left: 4px solid #cd853f;
                }
                .attribute-row {
                    margin-bottom: 5px;
                    font-size: 12px;
                }
                .attribute-key {
                    background: #cd853f;
                    color: white;
                    padding: 2px 8px;
                    border-radius: 3px;
                    font-weight: 500;
                    display: inline-block;
                    min-width: 100px;
                }
                .attribute-value {
                    color: #000;
                    margin-left: 10px;
                    background: white;
                    padding: 2px 8px;
                    border-radius: 3px;
                }
            </style>
        </head>
        <body>
            <div class="controls">
                <button onclick="zoomIn()">Zoom In (+)</button>
                <button onclick="zoomOut()">Zoom Out (-)</button>
                <button onclick="resetZoom()">Reset (100%)</button>
                <span class="zoom-label" id="zoomLevel">100%</span>
                <button onclick="downloadSVG()">Download SVG</button>
                <button onclick="downloadPNG()">Download PNG</button>
            </div>
            <div class="diagram-container" id="container">
                <div class="diagram-wrapper" id="diagram">
                    \(diagramSVG)
                </div>
            </div>

            \(hasAttributes ? """
            <div class="attributes-section">
                \(attributesHTML)
            </div>
            """ : "")

            <script>
                // Concept info for filename generation
                const conceptId = '\(jsConceptId)';
                const conceptTerm = '\(jsConceptTerm)';

                let currentZoom = 1.0;
                const diagram = document.getElementById('diagram');
                const zoomLabel = document.getElementById('zoomLevel');

                function updateZoom() {
                    diagram.style.transform = `scale(${currentZoom})`;
                    zoomLabel.textContent = Math.round(currentZoom * 100) + '%';
                }

                function zoomIn() {
                    currentZoom = Math.min(currentZoom + 0.2, 3.0);
                    updateZoom();
                }

                function zoomOut() {
                    currentZoom = Math.max(currentZoom - 0.2, 0.5);
                    updateZoom();
                }

                function resetZoom() {
                    currentZoom = 1.0;
                    updateZoom();
                }

                function downloadSVG() {
                    const svg = diagram.querySelector('svg');
                    const serializer = new XMLSerializer();
                    const svgString = serializer.serializeToString(svg);

                    // Send to native code for download
                    window.webkit.messageHandlers.downloadHandler.postMessage({
                        type: 'svg',
                        data: svgString,
                        conceptId: conceptId,
                        conceptTerm: conceptTerm
                    });
                }

                function downloadPNG() {
                    const svg = diagram.querySelector('svg');
                    const canvas = document.createElement('canvas');
                    const ctx = canvas.getContext('2d');
                    const svgData = new XMLSerializer().serializeToString(svg);
                    const img = new Image();
                    const svgBlob = new Blob([svgData], { type: 'image/svg+xml;charset=utf-8' });
                    const url = URL.createObjectURL(svgBlob);

                    img.onload = function() {
                        canvas.width = img.width * 2;
                        canvas.height = img.height * 2;
                        ctx.scale(2, 2);
                        ctx.fillStyle = 'white';
                        ctx.fillRect(0, 0, canvas.width, canvas.height);
                        ctx.drawImage(img, 0, 0);

                        // Convert to base64 and send to native code
                        canvas.toBlob(function(blob) {
                            const reader = new FileReader();
                            reader.onloadend = function() {
                                const base64data = reader.result.split(',')[1];
                                window.webkit.messageHandlers.downloadHandler.postMessage({
                                    type: 'png',
                                    data: base64data,
                                    conceptId: conceptId,
                                    conceptTerm: conceptTerm
                                });
                            };
                            reader.readAsDataURL(blob);
                            URL.revokeObjectURL(url);
                        });
                    };
                    img.src = url;
                }

                // Keyboard shortcuts
                document.addEventListener('keydown', function(e) {
                    if (e.key === '+' || e.key === '=') {
                        zoomIn();
                        e.preventDefault();
                    } else if (e.key === '-' || e.key === '_') {
                        zoomOut();
                        e.preventDefault();
                    } else if (e.key === '0') {
                        resetZoom();
                        e.preventDefault();
                    }
                });
            </script>
        </body>
        </html>
        """
    }

    /// Wraps text into lines that fit within maxWidth (in pixels, ~5.5px per char).
    private static func wrapText(_ text: String, maxChars: Int) -> [String] {
        guard text.count > maxChars else { return [text] }

        var lines: [String] = []
        var currentLine = ""
        let words = text.split(separator: " ", omittingEmptySubsequences: false)

        for word in words {
            let testLine = currentLine.isEmpty ? String(word) : currentLine + " " + word
            if testLine.count <= maxChars {
                currentLine = testLine
            } else {
                if !currentLine.isEmpty {
                    lines.append(currentLine)
                }
                // If single word is too long, break it
                if word.count > maxChars {
                    var remaining = String(word)
                    while remaining.count > maxChars {
                        let index = remaining.index(remaining.startIndex, offsetBy: maxChars)
                        lines.append(String(remaining[..<index]))
                        remaining = String(remaining[index...])
                    }
                    currentLine = remaining
                } else {
                    currentLine = String(word)
                }
            }
        }
        if !currentLine.isEmpty {
            lines.append(currentLine)
        }

        return lines
    }

    /// Generates SVG text with tspan elements for multi-line display (ID + wrapped term).
    private static func generateConceptText(id: String, term: String, x: Int, y: Int, maxWidth: Int) -> (svg: String, lines: Int) {
        let maxChars = maxWidth / 5  // Approximate chars that fit
        let termLines = wrapText(term, maxChars: maxChars)
        let totalLines = 1 + termLines.count  // ID line + term lines

        var tspans: [String] = []
        // First line: concept ID in gray
        tspans.append("<tspan x=\"\(x)\" dy=\"0\" fill=\"#666\" font-size=\"9\">\(htmlEscape(id))</tspan>")
        // Following lines: term (wrapped)
        for (index, line) in termLines.enumerated() {
            let dy = index == 0 ? "11" : "11"  // Line spacing
            tspans.append("<tspan x=\"\(x)\" dy=\"\(dy)\" font-size=\"10\">\(htmlEscape(line))</tspan>")
        }

        let svg = """
        <text x="\(x)" y="\(y)" font-family="-apple-system, BlinkMacSystemFont, sans-serif">
            \(tspans.joined(separator: "\n    "))
        </text>
        """

        return (svg, totalLines)
    }

    /// Escapes HTML special characters to prevent XSS.
    private static func htmlEscape(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
