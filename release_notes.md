
### Added
- **Concept visualization panel**: New "Visualize" button in lookup popover opens a floating panel showing concept properties and relationships
  - SNOMED CT concepts display relationship diagrams following SNOMED CT Diagramming specification
  - LOINC and other code systems display property lists with colored boxes
  - WebView-based rendering with HTML/SVG
  - Lazy loading: properties fetched only when visualization is requested via `property=*` parameter
  - Panel positioned to right of popover (or left if insufficient space)
  - **Meaningful export filenames**: SVG/PNG downloads use sanitized concept terms (e.g., `51451002-arthrotomy-of-glenohumeral-joint.svg`)
- **Shrimp browser integration** (Control+Option+H): New hotkey and "Open in Shrimp" button to view concepts in the Shrimp terminology browser
- Shrimp URL builder supports SNOMED CT, LOINC, ICD-10, RxNorm, and other code systems with correct version and ValueSet parameters

### Fixed
- **Concept ID extraction now includes IDs starting with 1**: Fixed regex pattern that incorrectly excluded valid SNOMED CT concept IDs starting with 1 (e.g., 10971007, 17756004, 179419004). These concepts now display correctly in visualizations with proper definition status.

### Technical
- Added SNOMEDExpressionParser.swift: Complete parser for SNOMED CT compositional grammar
  - Parses normalForm/normalFormTerse properties following SNOMED CT expression syntax
  - Supports definition status (=== for defined, <<< for primitive)
  - Parses focus concepts, refinements, attribute groups, and attributes
  - Handles concept references with pipe-delimited terms
  - Supports concrete values and nested expressions
- Added VisualizationModels.swift: ConceptProperty, PropertyValue enum, VisualizationData wrapper
- Updated DiagramRenderer.swift: SVG generation following SNOMED CT Diagramming Specification
  - Parses normal form using SNOMEDExpressionParser
  - Prioritizes normalForm (with human-readable terms) over normalFormTerse (IDs only)
  - Preprocesses normal form to remove line breaks and normalize whitespace before parsing
  - Renders focus concept, definition status symbol (≡ or ○), and parent concept
  - Draws attribute groups with filled circles, ungrouped attributes with open circles
  - Renders attributes as tan rounded rectangles, values as blue rectangles
  - Generates connecting lines with proper junction points
  - Falls back to text display if parsing fails
- Added VisualizationViewModel.swift: Async property loading and state management
- Added VisualizationPanelView.swift: SwiftUI view with WebView rendering
- Added VisualizationPanelController.swift: Panel window lifecycle (follows SearchPanelController pattern)
- Extended OntoserverClient with `lookupWithProperties(conceptId:system:version:)` method
- Extended FHIRParameters.Part with `valueInteger` field for integer property values
- Extended LookupViewModel with `onVisualize` callback and `openVisualization()` method
- Extended PopoverView with "Visualize" button
- Extended AppDelegate with VisualizationPanelController instance and callback wiring
- Extended CursorAnchorWindow with public `nsWindow` accessor for positioning
- Added ShrimpURLBuilder.swift for constructing Shrimp browser URLs from concept lookup results
- Added ShrimpHotKeySettings.swift for configuring the Shrimp hotkey (default: Control+Option+H)
- Extended LookupViewModel with `openInShrimp()` and `lookupAndOpenInShrimp(from:)` methods
- Extended SettingsView with Shrimp Browser Hotkey configuration section
- Extended PopoverView with "Open in Shrimp" button
- Shrimp URLs include dynamic FHIR endpoint, concept ID, version/module information, and code system-specific ValueSet URIs
- **User-Agent header**: All FHIR requests now include `User-Agent: Codeagogo/{version} (macOS)` for server log identification
- **Filename sanitization**: VisualizationPanelView.swift includes `sanitizeFilename()` function that removes semantic tags, sanitizes special characters, and truncates to ~40 chars
- DiagramRenderer.swift passes concept ID and term through JavaScript postMessage for download operations
- Fixed regex pattern in VisualizationViewModel.swift and DiagramRenderer.swift from `\b([2-9]\d{5,17})\b` to `\b(\d{6,18})\b` to match all valid SNOMED CT concept IDs

