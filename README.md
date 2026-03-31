<div align="center">
  <img src="icon.png" alt="Codeagogo Icon" width="128" height="128">

  # Codeagogo

  ![CI](https://github.com/aehrc/codeagogo/actions/workflows/ci.yml/badge.svg)
  ![platform](https://img.shields.io/badge/platform-macOS%2013%2B-blue)
  ![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
  ![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-red)
  ![License](https://img.shields.io/badge/license-Apache_2.0-blue)

  A macOS menu bar utility for working with clinical terminology codes. Look up SNOMED CT, LOINC, ICD-10, and other code systems from any application using global hotkeys.

  > **Looking for the Windows version?** See [Codeagogo for Windows](https://github.com/aehrc/codeagogo-win).
</div>

## Features

### Global Hotkeys

| Hotkey | Action |
|--------|--------|
| `Control+Option+L` | **Lookup** — Display concept details for selected code |
| `Control+Option+S` | **Search** — Open search panel to find and insert concepts |
| `Control+Option+R` | **Replace** — Replace selected codes with `ID \| term \|` format |
| `Control+Option+E` | **ECL Format** — Toggle ECL between pretty-printed and minified |
| `Control+Option+V` | **ECL Workbench** — Open Monaco-based ECL editor with live evaluation |
| `Control+Option+H` | **Shrimp** — Open selected concept in Shrimp browser |

All hotkeys are fully customizable via Settings using a keystroke recorder.

### Lookup (Control+Option+L)

Select any concept code and press the hotkey to see:
- **Concept ID** and **display term**
- **FSN** (Fully Specified Name) for SNOMED CT concepts
- **PT** (Preferred Term) for SNOMED CT concepts
- **Active/Inactive status** with visual highlighting for inactive concepts
- **Edition** information (for SNOMED CT)
- **Code System** (for non-SNOMED codes)

Copy buttons provide quick access to ID, terms, or pipe-delimited combinations.

### Search & Insert (Control+Option+S)

Opens a floating search panel near your cursor:
- **Typeahead search** across SNOMED CT or configured code systems
- **Edition selector** to filter by specific SNOMED CT edition
- **Insert format options**: ID only, PT, FSN, `ID|PT`, or `ID|FSN`
- Results show PT, FSN (if different), concept ID, and edition

### Replace (Control+Option+R)

Bulk-annotate concept codes with their display terms:
- Finds all concept codes in the selection
- Looks up terms via batch API (fast, ~0.5s for 60+ codes)
- Replaces each code with `ID | term |` format
- **Smart toggle**: Press again to remove all terms
- **Inactive prefix**: Optionally prefixes inactive concepts with "INACTIVE - "
- Supports mixed selections with both SNOMED CT and non-SNOMED codes
- Shows progress HUD for large selections

### ECL Format (Control+Option+E)

Format or minify Expression Constraint Language (ECL) expressions:
- **Pretty-print**: Adds indentation and line breaks for readability
- **Minify**: Compresses to single line
- **Toggle**: Automatically detects format and switches to the other
- Supports full ECL 2.x syntax including refinements and filters
- **Semantic validation**: After formatting, concepts referenced in the ECL are validated against the terminology server in the background; inactive or unknown concepts trigger a yellow warning HUD
- **Precedence warnings**: Formatting ECL with mixed AND/OR/MINUS operators shows a warning HUD alerting to potential precedence issues

### ECL Workbench (Control+Option+V)

A full-featured ECL editing and evaluation environment powered by a Monaco editor (via WKWebView and the `@aehrc/ecl-editor` web component):
- **Monaco editor** with ECL syntax highlighting, bracket matching, and minimap
- **FHIR-powered autocomplete**: Concept and description suggestions from the terminology server as you type
- **Inline diagnostics**: Parse errors and warnings displayed directly in the editor gutter
- **Formatting** (Shift+Alt+F): Format ECL in the editor with one keystroke
- **Display term toggle** (Shift+Alt+T): Toggle display terms on concept references inline
- **Hover info**: Hover over a concept ID to see its display term and metadata
- **Live evaluation**: Results appear below the editor automatically (1-second debounce) or on demand with Cmd+Enter
- **Resizable split**: Drag handle between editor and results pane for flexible layout
- **Launch with or without selection**: Select ECL and press the hotkey to load it, or press with no selection to draft ECL from scratch
- **Panel stays visible** when switching between applications (floating utility window)
- **Semantic validation warnings**: Concepts referenced in the ECL are validated against the terminology server; inactive or unknown concepts display a yellow warning banner in the results panel
- **Configurable limit**: Default 50 results, adjustable in Settings

### ECL Reference Panel

Access built-in ECL documentation via the **ECL Reference...** menu item:
- **50 knowledge articles** sourced from ecl-core, covering operators, refinements, filters, patterns, grammar, and history
- **Expandable articles** with Markdown content, code blocks, tables, and ECL examples
- **Search and filter** to find articles by keyword
- **Link to ECL specification** for the full standard
- **Stays visible** when switching between applications (floating utility window)

### Shrimp Browser (Control+Option+H)

Open concepts in the Shrimp terminology browser:
- Select any concept code and press the hotkey to open in your default browser
- Works with SNOMED CT, LOINC, and other code systems
- Includes full version and edition context
- Also available as "Open in Shrimp" button in the lookup popover
- Uses the configured FHIR terminology server URL

### Concept Visualization

Visualize concept definitions and relationships:
- **SNOMED CT**: Relationship diagrams following SNOMED CT Diagramming Specification
  - Shows focus concepts (parents), definition status (defined ≡ or primitive ○)
  - Displays attribute groups with role relationships
  - Renders attributes and values with proper connecting lines
  - Multiple parents connected with vertical junction lines
- **LOINC & Others**: Property lists with colored key-value boxes
- **Interactive**: Zoom in/out, pan, reset view
- **Export**: Download as SVG or PNG with meaningful filenames (e.g., `73211009-diabetes-mellitus.svg`)
- **Lazy loading**: Properties fetched only when visualization is requested
- Access via "Visualize" button in the lookup popover

### Multi-Code-System Support

In addition to SNOMED CT, Codeagogo supports:
- **LOINC** — Laboratory and clinical observations
- **ICD-10** — Disease classification
- **RxNorm** — Medications
- **Other code systems** — Configurable in Settings

The app automatically detects SNOMED CT codes using Verhoeff check digit validation and falls back to searching configured code systems for other codes.

### User Experience

- **Menu Bar App** — Runs quietly, always accessible, with a custom Ontoserver-style cloud icon
- **Launch at login** — Opt-in on first launch (welcome screen), configurable in Settings
- **Update notifications** — Checks for new releases automatically; orange dot badge on menu bar icon when an update is available
- **Cursor-Anchored UI** — Popover and search panel appear near your cursor
- **Inserted text stays selected** — After replace/ECL format, text remains selected for easy undo
- **Inactive concept highlighting** — Orange warning icon and label for inactive concepts
- **Progress feedback** — HUD shows progress when processing many concepts

### Performance & Reliability

- **Batch lookup** — Replace hotkey uses `ValueSet/$expand` for 15x faster bulk lookups
- **In-Memory Caching** — 6-hour TTL reduces API calls
- **LRU Eviction** — Cache limited to 100 entries
- **Retry Logic** — Exponential backoff for transient failures
- **Thread-Safe** — Actor-based concurrency

## Requirements

| Requirement | Details |
|-------------|---------|
| **macOS** | 13.0 (Ventura) or later |
| **Internet** | Required for terminology server queries |
| **Permissions** | Accessibility (to read/write text selections) |

## Installation

### Homebrew (recommended)

```bash
brew tap aehrc/codeagogo https://github.com/aehrc/codeagogo
brew install --cask codeagogo
```

To update: `brew upgrade --cask codeagogo`

### Manual

1. Download from [Releases](../../releases)
2. Move `Codeagogo.app` to `/Applications`
3. Right-click and select **Open** (first launch only)
4. Grant **Accessibility** permission when prompted

For detailed instructions, see **[INSTALL.md](INSTALL.md)**.

## Configuration

Access Settings via the menu bar icon or `Cmd+,`.

### Hotkeys

Each hotkey (Lookup, Search, Replace, ECL Format, ECL Workbench, Shrimp) can be customized:
1. Click **Record**
2. Press your desired key combination (must include at least one modifier)
3. The hotkey updates immediately

### Code Systems

Configure additional code systems beyond SNOMED CT:
1. Open Settings → **Additional Code Systems**
2. Click **Add** to fetch available systems from the server
3. Enable/disable systems as needed

### Replace Settings

- **Term format**: Choose FSN or PT for the `| term |` suffix
- **Inactive prefix**: Toggle "INACTIVE - " prefix for inactive concepts

### FHIR Endpoint

- **Default**: `https://tx.ontoserver.csiro.au/fhir`
- Configure a custom FHIR R4 terminology server if needed

## Keyboard Shortcuts Reference

| Shortcut | Action |
|----------|--------|
| `Control+Option+L` | Lookup selected concept (configurable) |
| `Control+Option+S` | Open search panel (configurable) |
| `Control+Option+R` | Replace with terms (configurable) |
| `Control+Option+E` | Toggle ECL format (configurable) |
| `Control+Option+V` | Open ECL Workbench (configurable) |
| `Control+Option+H` | Open in Shrimp browser (configurable) |
| `Cmd+,` | Open Settings |
| `Cmd+Shift+D` | Copy diagnostics to clipboard |
| `Escape` | Close popover or search panel |
| Menu: **ECL Reference...** | Open ECL reference documentation panel |

## Development

### Prerequisites

- **Xcode 15+** with Swift 5.9+
- **macOS 13+** SDK

### Building

```bash
git clone https://github.com/aehrc/codeagogo.git
cd codeagogo/Codeagogo
open Codeagogo.xcodeproj

# Or build from command line
xcodebuild build -scheme "Codeagogo" -destination "platform=macOS"
```

### Testing

Tests are organized into three tiers using Xcode Test Plans:

| Tier | Test Plan | Scope | When to Run |
|------|-----------|-------|-------------|
| 1 — Unit | `Codeagogo-Unit` | Pure logic, no network or GUI | Every commit |
| 2 — Integration | `Codeagogo-Integration` | Real network calls to Ontoserver | Nightly / on-demand |
| 3 — UI | `Codeagogo-UI` | XCUITest for Settings and MenuBar | Pre-release / manual |

```bash
# Run unit tests (recommended default)
xcodebuild test -scheme "Codeagogo" -testPlan "Codeagogo-Unit" \
  -destination "platform=macOS"

# Run integration tests (requires network)
xcodebuild test -scheme "Codeagogo" -testPlan "Codeagogo-Integration" \
  -destination "platform=macOS"

# Run specific test class
xcodebuild test -scheme "Codeagogo" -destination "platform=macOS" \
  -only-testing:"CodeagogoTests/ConceptCacheTests"
```

507+ unit tests cover FHIR parsing, concept extraction, SCTID validation, ECL parsing/formatting, diagram rendering, settings, caching, and view data models.

### Project Structure

```
Codeagogo/
├── Codeagogo.xcodeproj/
├── Codeagogo/                  # Main app source
│   ├── CodeagogoApp.swift      # App entry point
│   ├── AppDelegate.swift       # Menu bar, hotkeys, popover
│   ├── LookupViewModel.swift   # Lookup coordination
│   ├── SearchViewModel.swift   # Search coordination
│   ├── OntoserverClient.swift  # FHIR client
│   ├── PopoverView.swift       # Lookup results UI
│   ├── SearchPanelView.swift   # Search panel UI
│   ├── SettingsView.swift      # Settings UI
│   ├── ECLBridge.swift          # ECL operations via ecl-core (JavaScriptCore)
│   ├── ECLEditorView.swift      # ECL Workbench (WKWebView + Monaco editor)
│   ├── EvaluateViewModel.swift  # ECL evaluation coordination
│   ├── ECLReferencePanelView.swift    # ECL reference documentation UI
│   ├── ECLReferencePanelController.swift  # ECL reference panel window management
│   └── ...
├── CodeagogoTests/             # Unit & integration tests
│   └── ViewTests/              # View data model tests
└── CodeagogoUITests/           # UI tests (Tier 3)
```

## Architecture

See **[ARCHITECTURE.md](ARCHITECTURE.md)** for detailed technical documentation.

## Privacy

- **Selection Access**: Only reads text when a hotkey is pressed
- **Clipboard Restore**: Original clipboard contents are restored after reading
- **No Persistence**: No user data stored to disk
- **No Telemetry**: No analytics or tracking
- **Network**: HTTPS only to configured FHIR server

See **[PRIVACY.md](PRIVACY.md)** for complete details.

## Contributing

See **[CONTRIBUTING.md](CONTRIBUTING.md)** for guidelines.

## License

Licensed under the [Apache License, Version 2.0](LICENSE).

Copyright 2026 Commonwealth Scientific and Industrial Research Organisation (CSIRO).

## Acknowledgements

- **CSIRO Ontoserver** — FHIR terminology services
- **SNOMED International** — SNOMED CT terminology standard
