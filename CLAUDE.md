# CLAUDE.md

This file provides context for Claude (or other AI assistants) when working on this codebase.

## Development Rules

### Always Do

1. **Update CHANGELOG.md** — Add entries under `[Unreleased]` for any user-facing changes
2. **Add or update tests** — New functionality needs tests; bug fixes need regression tests
3. **Run tests before committing** — `xcodebuild test -scheme "Codeagogo" -testPlan "Codeagogo-Unit" -destination "platform=macOS"`
4. **Add docstrings** — Document all new public types, methods, and non-trivial private methods
5. **Update documentation** — Keep README.md, ARCHITECTURE.md, and other docs in sync with code changes
6. **Follow existing patterns** — Match the code style and architecture of surrounding code
7. **Use structured logging** — Log via `AppLog` (debug, info, warning, error levels)

### Never Do

1. **Don't add external dependencies** — Only system frameworks (exception: ViewInspector in test target)
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

Conventional commit format: `<type>: <short summary>`. Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`.

### When to Ask for Clarification

Ask the user before:
- Adding new UI elements or changing existing layouts
- Modifying the FHIR API query structure
- Changing hotkey behavior or defaults
- Removing any existing functionality
- Making architectural changes

## Build & Test

```bash
# Build
xcodebuild build -scheme "Codeagogo" -destination "platform=macOS"

# Unit tests (Tier 1 — headless, <30s, CI default)
xcodebuild test -scheme "Codeagogo" -testPlan "Codeagogo-Unit" -destination "platform=macOS"

# Integration tests (Tier 2 — requires network)
xcodebuild test -scheme "Codeagogo" -testPlan "Codeagogo-Integration" -destination "platform=macOS"

# UI tests (Tier 3 — requires GUI session)
xcodebuild test -scheme "Codeagogo" -testPlan "Codeagogo-UI" -destination "platform=macOS"

# Specific test class
xcodebuild test -scheme "Codeagogo" -destination "platform=macOS" \
  -only-testing:"CodeagogoTests/ConceptCacheTests"
```

## Architecture Notes

**Carbon for Global Hotkeys** — macOS has no modern API for system-wide hotkeys. We use the legacy Carbon `RegisterEventHotKey` API. Always use `HotKeySettings.carbonModifiers(from:)` for modifier conversion.

**Multi-Edition Batch Lookup** — `batchLookup()` does a fast default-edition lookup first, then parallel per-edition fallback for namespaced SCTIDs only. `SCTIDValidator.isCoreSCTID()` skips the fallback for International-only codes (3rd-last digit `0`). Edition list cached 30 minutes.

**Shared OntoserverClient** — `AppDelegate` reuses a single instance so the concept cache persists across replace invocations, enabling the add/remove toggle.

**Selection Capture** — Requires Accessibility permission. Snapshots clipboard → clears → simulates Cmd+C → reads → restores original.

**ECL via ecl-core + JavaScriptCore** — ECL parsing, formatting, and validation use the `@aehrc/ecl-core` TypeScript library bundled as `ecl-core-bundle.js` and evaluated in-process via `JSContext` (JavaScriptCore). `ECLBridge.swift` wraps the JS calls. The bundle is auto-regenerated from npm on build (scheme pre-action) when source changes. To update ecl-core manually: `cd scripts && npm update @aehrc/ecl-core`, then rebuild.

**ECL Workbench via ecl-editor + WKWebView** — The ECL Workbench uses `ecl-editor.standalone.js` (~922KB), a standalone build of the `@aehrc/ecl-editor` npm package, loaded as a bundled app resource into a `WKWebView`. `ECLEditorView.swift` hosts the web view and communicates with the Monaco-based editor via `WKScriptMessageHandler` (Swift-to-JS postMessage bridge). Monaco itself is loaded from CDN (jsdelivr). The editor provides syntax highlighting, FHIR-powered autocomplete, inline diagnostics, formatting, and hover info.

**Known test limitation** — Creating `LookupViewModel`, `SearchViewModel`, `VisualizationViewModel`, or `EvaluateViewModel` in new test files triggers a malloc crash (Swift concurrency back-deploy bug). Existing files work; new files must test data models directly.

**Update Checker** — `UpdateChecker.swift` queries the GitHub Releases API on launch and every 24 hours. Publishes `updateAvailable` via Combine. AppDelegate observes it to show an orange dot badge on the menu bar icon and update the menu item. SettingsView shows a banner. Manual check via menu item.

**Launch at Login** — Uses `SMAppService.mainApp.register()/unregister()` (macOS 13+). Welcome screen offers opt-in (checked by default). Settings toggle reflects current state via `SMAppService.mainApp.status`.

**Custom Menu Bar Icon** — Ontoserver-style cloud with network dots, stored as a template image in `Assets.xcassets/MenuBarIcon.imageset`. macOS handles light/dark mode automatically.

**Diagram Preferred Terms** — `lookupPreferredTerm(conceptId:system:)` on `OntoserverClient` does a `$lookup` without a `version` parameter, so the server returns the default edition PT (e.g., SCTAU). `DiagramRenderer.resolvedTerm(for:data:)` checks `displayNameMap` before falling back to normalForm terms. `resolvedExpressionTerm(for:data:)` handles composite units (numerator/denominator → "mg/mL").

**Homebrew Tap** — `Casks/codeagogo.rb` is a Homebrew cask formula pointing to the GitHub Release .zip. The release workflow auto-updates the version and SHA256 after publishing each release.

## Gotchas

1. **Accessibility Permission** — The built app needs permission, not Xcode. Re-add in System Settings if capture fails.
2. **Single Instance** — `enforceSingleInstance()` terminates if another instance is running. Kill existing instances before debugging.
3. **Test Environment** — Tests may fail with "Early unexpected exit" if another instance is running: `pkill -9 "Codeagogo"`
4. **Carbon Modifiers** — NSEvent and Carbon use different modifier flag formats. Always use `HotKeySettings.carbonModifiers(from:)`.
5. **Main Actor Isolation** — `LookupViewModel` and `HotKeySettings` are `@MainActor`. Use `await` from non-isolated contexts.

## Releases

When updating version numbers, grep for the old version across the entire project:

```bash
grep -r 'CURRENT_VERSION' --include='*.swift' --include='*.plist' --include='*.json' --include='*.md' --include='*.yml' .
```

Known locations: `CHANGELOG.md`, `Codeagogo.xcodeproj` (`MARKETING_VERSION`), `release_notes.md`, `Casks/codeagogo.rb`.
