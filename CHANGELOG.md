# Changelog

All notable changes to SNOMED Lookup are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- **Replace hotkey** (Control+Option+R): Looks up selected concept ID and replaces it with `ID | term |` format
- Configurable term format for replace: FSN (default) or PT
- Settings UI for replace hotkey key, modifiers, and term format

### Technical
- Added ReplaceHotKeySettings singleton for replace hotkey configuration
- Added ReplaceSettings singleton for replace term format preference
- Added replaceSelection() action in AppDelegate
- Extended SettingsView with Replace Hotkey section
- Added unit tests for replace hotkey settings and term format
- Added UI tests for replace hotkey settings controls

## [0.6.0] - 2026-01

### Added
- **Concept Search and Insert feature**: New global hotkey (Control+Option+S) opens a floating search panel
- Typeahead search using FHIR ValueSet/$expand API to find concepts by term
- Edition selector: filter by specific SNOMED CT edition or search across all editions
- Insert format selector: choose between ID, PT, FSN, ID|PT, or ID|FSN formats
- Text insertion via simulated Cmd+V paste into any application
- Search panel shows Preferred Term, FSN (if different), concept ID, and edition name
- Settings for configuring the search hotkey and default insert format
- Menu bar item "Search Concepts..." for accessing the search panel

### Changed
- GlobalHotKey now supports multiple hotkeys via an `id` parameter
- Settings window height increased to accommodate new options
- SNOMEDEdition now conforms to Identifiable and Hashable for SwiftUI compatibility

### Fixed
- Search results now deduplicated by concept code (prevents duplicate entries from multiple edition versions)
- Unknown edition IDs now fall back to CodeSystem title from server instead of showing raw ID

### Testing
- Added UI test automation target (`SNOMED LookupUITests`) with XCUITest coverage
- Settings window UI tests (~20 tests): hotkey pickers, modifier toggles, format picker, FHIR URL, save button, logging, diagnostics
- Search panel UI tests (~8 tests): panel open/close, search field, cancel, insert disabled state, edition picker
- Menu bar UI tests (~3 tests): app launch, status item, menu items
- SearchViewModel mock-based unit tests (~10 tests): search triggering, results, auto-selection, clear state, error handling, format output
- Added `ConceptSearching` protocol for dependency injection in SearchViewModel tests
- Added accessibility identifiers to SettingsView, SearchPanelView, and PopoverView for reliable XCUITest targeting
- Added `--ui-testing` launch argument guard to skip single-instance check during UI tests

### Technical
- Added SearchResult model for ValueSet/$expand results
- Added InsertFormat enum for concept formatting options
- Added SearchSettings and SearchHotKeySettings singletons
- Added SearchViewModel for coordinating search operations with debouncing
- Added SearchPanelView (SwiftUI) and SearchPanelController (NSWindow management)
- Extended OntoserverClient with searchConcepts() method and POST request support
- Added sendCmdV() to SystemSelectionReader for paste simulation
- Added comprehensive unit tests for search functionality

## [0.5.0] - 2026-01

### Changed
- Popover now takes focus when opened, allowing immediate dismissal with Escape key
- Focus is restored to the previously active application when the popover closes

## [0.4.0] - 2026-01

### Added
- GitHub Actions release workflow for creating versioned releases
- GitHub Actions CI/CD workflow for automated builds and tests
- Downloadable build artifacts from CI (macOS app bundle)
- Comprehensive unit and integration test suite (63 tests)
- LRU cache with configurable size limit (100 entries)
- Retry logic with exponential backoff for transient network failures
- Dependency injection protocols for improved testability
- Accessibility labels for VoiceOver support
- `OntoserverError` enum for structured error handling
- Architecture documentation (ARCHITECTURE.md)
- Contributing guidelines (CONTRIBUTING.md)
- This changelog

### Changed
- Consolidated duplicate modifier conversion code into `HotKeySettings.carbonModifiers`
- Improved memory management in GlobalHotKey with proper event handler cleanup
- Enhanced README with comprehensive documentation
- Replaced force unwraps with proper error handling in OntoserverClient

### Removed
- Unused `ContentView.swift` placeholder
- Unused `SnowstormClient.swift` (superseded by OntoserverClient)
- Unnecessary imports (AppKit from app entry point, Combine from SettingsView)

### Fixed
- GlobalHotKey memory leak from unregistered Carbon event handlers
- Potential crashes from force unwraps in URL construction

## [1.3.0] - 2024-12

### Added
- Configurable FHIR endpoint in Settings
- Ability to use custom FHIR terminology servers
- Invalid URL fallback to default endpoint

### Changed
- Improved error messages for network failures

## [1.2.0] - 2024-11

### Added
- Copy buttons for ID & FSN and ID & PT combinations
- Pipe-separated format for combined copy operations

### Changed
- Updated button layout in popover

## [1.1.0] - 2024-10

### Added
- Debug logging toggle in Settings
- Diagnostic log export to clipboard
- Help menu with diagnostic copy shortcut (Cmd+Shift+D)
- Support for multiple Xcode workspaces

### Changed
- Switched from SNOMED Lookup Service to CSIRO Ontoserver for improved reliability
- Improved logging with categorical loggers (network, selection, ui, general)

### Fixed
- Selection capture issues in multi-workspace environments

## [1.0.0] - 2024-09

### Added
- Initial release
- Global hotkey activation (Control+Option+L)
- SNOMED CT concept lookup via FHIR terminology server
- Popover display near cursor with concept details:
  - Concept ID
  - Fully Specified Name (FSN)
  - Preferred Term (PT)
  - Active/inactive status
  - Edition and version information
- Copy buttons for individual fields
- Configurable hotkey (key and modifiers)
- In-memory caching with 6-hour TTL
- Multi-edition fallback search
- Menu bar integration
- Settings window
- macOS app icon
- Installation guide
- Privacy policy
- README documentation

### Technical
- SwiftUI-based user interface
- Carbon framework for global hotkey registration
- App Sandbox with network client entitlement
- Accessibility permission for selection capture
- macOS 13+ (Ventura) minimum requirement
