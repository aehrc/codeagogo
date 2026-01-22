# Changelog

All notable changes to SNOMED Lookup are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
