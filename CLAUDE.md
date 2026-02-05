# CLAUDE.md

This file provides context for Claude (or other AI assistants) when working on this codebase.

## Development Rules

When making changes to this codebase, follow these rules:

### Always Do

1. **Update CHANGELOG.md** — Add entries under `[Unreleased]` for any user-facing changes
2. **Add or update tests** — New functionality needs tests; bug fixes need regression tests
3. **Run tests before committing** — Ensure all 63+ tests pass: `xcodebuild test -scheme "Codeagogo" -destination "platform=macOS"`
4. **Add docstrings** — Document all new public types, methods, and non-trivial private methods
5. **Update documentation** — Keep README.md, ARCHITECTURE.md, and other docs in sync with code changes
6. **Follow existing patterns** — Match the code style and architecture of surrounding code
7. **Use structured logging** — Log via `AppLog` (debug, info, warning, error levels)

### Never Do

1. **Don't add external dependencies** — This is a lightweight app using only system frameworks
2. **Don't modify Xcode project files manually** — Let Xcode manage `project.pbxproj`
3. **Don't commit build artifacts** — `build/` and `dist/` are gitignored
4. **Don't store sensitive data** — No hardcoded credentials, no persistent user data
5. **Don't break backward compatibility** — Existing UserDefaults keys must remain stable

### Code Quality

- **No force unwraps** — Use `guard`, `if let`, or nil-coalescing instead of `!`
- **No force try** — Handle errors properly, don't use `try!`
- **Prefer async/await** — Use Swift concurrency over completion handlers
- **Keep functions focused** — Single responsibility, under 40 lines when possible
- **Accessibility** — Add `.accessibilityLabel()` to interactive UI elements

### Commit Messages

Follow conventional commit format:
```
<type>: <short summary>

<optional body>
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

Example:
```
feat: add support for Belgian SNOMED edition

Added edition ID mapping for the Belgian national extension.
Updated CHANGELOG.md with the new feature.
```

### When to Ask for Clarification

Ask the user before:
- Adding new UI elements or changing existing layouts
- Modifying the FHIR API query structure
- Changing hotkey behavior or defaults
- Removing any existing functionality
- Making architectural changes

### PR Checklist

Before submitting changes:
- [ ] All tests pass
- [ ] CHANGELOG.md updated (if user-facing change)
- [ ] Documentation updated (README, ARCHITECTURE, etc. if applicable)
- [ ] New code has docstrings
- [ ] No compiler warnings
- [ ] Tested manually (if UI changes)

## Project Overview

Codeagogo is a macOS menu bar utility for working with clinical terminology codes. It provides four global hotkeys:

| Hotkey | Action |
|--------|--------|
| `Control+Option+L` | **Lookup** — Display concept details for selected code |
| `Control+Option+S` | **Search** — Open search panel to find and insert concepts |
| `Control+Option+R` | **Replace** — Annotate codes with `ID \| term \|` format |
| `Control+Option+E` | **ECL Format** — Toggle ECL between pretty-printed and minified |
| `Control+Option+H` | **Shrimp** — Open selected concept in Shrimp browser |

Supports SNOMED CT, LOINC, ICD-10, RxNorm, and other configurable code systems.

## Tech Stack

- **Language:** Swift 5.9+
- **UI Framework:** SwiftUI (popover, settings, search panel) + AppKit (menu bar, pasteboard)
- **Minimum OS:** macOS 13 (Ventura)
- **Architecture:** MVVM with dependency injection
- **Concurrency:** Swift async/await, actors for thread safety
- **External API:** FHIR R4 terminology server (Ontoserver)
- **ECL Parser:** Recursive descent parser for Expression Constraint Language 2.x

## Key Files

| File | Purpose |
|------|---------|
| `AppDelegate.swift` | Menu bar setup, 4 hotkeys, popover/search panel management |
| `LookupViewModel.swift` | Coordinates lookups, extracts concept IDs, SCTID validation |
| `SearchViewModel.swift` | Coordinates search, debouncing, format selection |
| `OntoserverClient.swift` | FHIR API client with caching, batch lookup, retry logic |
| `SystemSelectionReader.swift` | Captures/pastes text via Cmd+C/V, selects via AX API |
| `GlobalHotKey.swift` | Carbon-based global hotkey registration (supports multiple) |
| `PopoverView.swift` | Lookup results UI (SwiftUI) |
| `SearchPanelView.swift` | Search and insert UI (SwiftUI) |
| `SettingsView.swift` | Preferences UI with hotkey recorder (SwiftUI) |
| `ECLParser.swift` | ECL 2.x parser (with ECLLexer, ECLAST, ECLFormatter) |
| `SCTIDValidator.swift` | Verhoeff check digit validation for SNOMED CT IDs |
| `HotKeySettings.swift` | Hotkey config (+ Search, Replace, ECLFormat, Shrimp variants) |
| `ShrimpURLBuilder.swift` | Constructs Shrimp browser URLs for concepts |
| `CodeSystemSettings.swift` | Multi-code-system configuration |
| `ReplaceSettings.swift` | Replace hotkey settings (term format, inactive prefix) |

## Build & Test Commands

```bash
# Build
xcodebuild build -scheme "Codeagogo" -destination "platform=macOS"

# Run tests
xcodebuild test -scheme "Codeagogo" -destination "platform=macOS"

# Run specific test class
xcodebuild test -scheme "Codeagogo" -destination "platform=macOS" \
  -only-testing:"CodeagogoTests/ConceptCacheTests"

# Package for distribution
./package-zip.sh
```

## Architecture Patterns

### Dependency Injection

`LookupViewModel` accepts optional protocol-based dependencies for testability:

```swift
protocol SelectionReading {
    func readSelectionByCopying() throws -> String
}

protocol ConceptLookupClient {
    func lookup(conceptId: String) async throws -> ConceptResult
}

init(selectionReader: SelectionReading? = nil,
     client: ConceptLookupClient? = nil)
```

### Actor-Based Caching

`ConceptCache` is a Swift actor providing thread-safe LRU caching with TTL:
- 6-hour TTL for cache entries
- 100 entry maximum with LRU eviction
- All access is automatically serialized

### Carbon for Global Hotkeys

macOS has no modern API for system-wide hotkeys. We use the legacy Carbon `RegisterEventHotKey` API. Key points:
- Must call `UnregisterEventHotKey` and `RemoveEventHandler` on cleanup
- Modifier flags must be converted from `NSEvent.ModifierFlags` to Carbon format
- Use `HotKeySettings.carbonModifiers(from:)` for conversion

### Selection Capture

Reading selected text requires Accessibility permission. The process:
1. Snapshot current clipboard
2. Clear clipboard
3. Simulate Cmd+C via CoreGraphics events
4. Read clipboard after brief delay
5. Restore original clipboard

## Code Conventions

- **MARK comments** organize code sections: `// MARK: - Properties`
- **@MainActor** on view models and UI-bound singletons
- **Docstrings** on all public types and methods
- **LocalizedError** conformance for user-facing errors
- **Structured logging** via `AppLog` (uses os.log)

## Testing

100+ tests covering:
- `ConceptIdExtractionTests` — Regex extraction, SCTID validation
- `ConceptCacheTests` — Cache operations, TTL, LRU
- `EditionNameParsingTests` — Edition URI parsing
- `OntoserverClientTests` — FHIR parsing, errors, multi-code-system
- `IntegrationTests` — End-to-end lookups
- `SCTIDValidatorTests` — Verhoeff check digit validation
- `CodeSystemSettingsTests` — Code system configuration
- `ECLFormatterTests` — ECL lexer, parser, formatter, minifier
- `KeyCodeFormatterTests` — Hotkey display formatting
- `SearchViewModelTests` — Search coordination
- `ReplaceHotKeyTests` — Replace settings

Tests use a `TestableConceptCache` subclass that exposes internal state.

## Common Tasks

### Adding a New SNOMED Edition

Edit `getEditionName(for:)` in `OntoserverClient.swift`:

```swift
private func getEditionName(for editionId: String) -> String {
    let editionNames: [String: String] = [
        "900000000000207008": "International",
        "32506021000036107": "Australian",
        // Add new edition here
    ]
    return editionNames[editionId] ?? editionId
}
```

### Modifying Hotkeys

Five hotkeys are configurable via Settings using a keystroke recorder:
- **Lookup**: `HotKeySettings.swift` (default: Control+Option+L)
- **Search**: `SearchHotKeySettings.swift` (default: Control+Option+S)
- **Replace**: `ReplaceHotKeySettings.swift` (default: Control+Option+R)
- **ECL Format**: `ECLFormatHotKeySettings.swift` (default: Control+Option+E)
- **Shrimp**: `ShrimpHotKeySettings.swift` (default: Control+Option+H)

Each stores `keyCode` (virtual key code) and `modifiersRaw` (Carbon modifier mask).

### Changing Cache Behavior

Edit constants in `OntoserverClient.swift`:

```swift
private enum NetworkConstants {
    static let cacheTTL: TimeInterval = 6 * 60 * 60  // 6 hours
    static let maxRetries = 2
    static let baseRetryDelay: TimeInterval = 0.5
}
```

Cache size is in `ConceptCache`:
```swift
private let maxSize = 100
```

## Gotchas

1. **Accessibility Permission** — The built app needs Accessibility permission, not Xcode. If selection capture fails, re-add in System Settings.

2. **Single Instance** — `enforceSingleInstance()` terminates if another instance is running. This can interfere with debugging if a release build is running.

3. **Test Environment** — Tests may fail with "Early unexpected exit" if another instance is running. Kill existing instances first: `pkill -9 "Codeagogo"`

4. **Carbon Modifiers** — NSEvent and Carbon use different modifier flag formats. Always use `HotKeySettings.carbonModifiers(from:)`.

5. **Main Actor Isolation** — `LookupViewModel` and `HotKeySettings` are `@MainActor`. Use `await` when calling from non-isolated contexts.

## Documentation

- `README.md` — User-facing documentation
- `ARCHITECTURE.md` — Technical architecture with diagrams
- `CONTRIBUTING.md` — Contribution guidelines
- `CHANGELOG.md` — Version history
- `INSTALL.md` — Installation instructions
- `PRIVACY.md` — Privacy policy
