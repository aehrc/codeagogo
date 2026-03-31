# Contributing to Codeagogo

Thank you for your interest in contributing to Codeagogo! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Code Style](#code-style)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Reporting Issues](#reporting-issues)

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). Please be respectful and constructive in all interactions.

## Getting Started

### Prerequisites

- macOS 13+ (Ventura or later)
- Xcode 15+ with Swift 5.9+
- Git
- Basic familiarity with SwiftUI and macOS development

### Understanding the Project

Before contributing, familiarize yourself with:

1. **[README.md](README.md)** — Project overview and features
2. **[ARCHITECTURE.md](ARCHITECTURE.md)** — Technical design and component responsibilities
3. **[PRIVACY.md](PRIVACY.md)** — Privacy considerations and constraints

## Development Setup

### 1. Fork and Clone

```bash
# Fork the repository on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/codeagogo.git
cd "codeagogo/Codeagogo"
```

### 2. Open in Xcode

```bash
open "Codeagogo.xcodeproj"
```

### 3. Configure Signing

- Open the project settings
- Select the "Codeagogo" target
- Under "Signing & Capabilities", select your development team

### 4. ECL Bundle (optional)

The ECL functionality uses `@aehrc/ecl-core` bundled as JavaScript. The committed `ecl-core-bundle.js` works out of the box. To update ecl-core after a new release:

```bash
cd scripts
npm install
node bundle-ecl-core.mjs
```

The scheme pre-build action runs this automatically if Node.js is installed.

### 5. Grant Permissions

When running the app:
- Grant Accessibility permission when prompted
- If selection capture fails, re-add the app in System Settings → Privacy & Security → Accessibility

### 6. Verify Setup

```bash
# Build the project
xcodebuild build -scheme "Codeagogo" -destination "platform=macOS"

# Run all tests
xcodebuild test -scheme "Codeagogo" -destination "platform=macOS"
```

## Making Changes

### Branch Naming

Use descriptive branch names:

- `feature/` — New features (e.g., `feature/batch-lookup`)
- `fix/` — Bug fixes (e.g., `fix/cache-expiration`)
- `docs/` — Documentation changes (e.g., `docs/api-reference`)
- `refactor/` — Code refactoring (e.g., `refactor/extract-fhir-parser`)
- `test/` — Test additions or improvements (e.g., `test/edge-cases`)

### Commit Messages

Write clear, descriptive commit messages:

```
<type>: <short summary>

<optional longer description>

<optional footer>
```

**Types:**
- `feat` — New feature
- `fix` — Bug fix
- `docs` — Documentation
- `refactor` — Code refactoring
- `test` — Test changes
- `chore` — Build, CI, or tooling changes

**Examples:**
```
feat: add batch concept lookup support

Allows users to look up multiple concept IDs at once by selecting
a comma-separated list. Results are displayed in a scrollable list.

Closes #42
```

```
fix: correct cache TTL calculation

The cache was using creation time instead of last access time for
TTL checks, causing premature cache misses.
```

## Code Style

### Swift Conventions

Follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/):

- Use clear, descriptive names
- Prefer clarity over brevity
- Use camelCase for functions and properties
- Use PascalCase for types and protocols

### Documentation

Add documentation comments for:

- All public types, methods, and properties
- Complex private implementations
- Non-obvious logic

```swift
/// Looks up a SNOMED CT concept by its identifier.
///
/// This method first checks the cache, then queries the FHIR server
/// if the concept is not cached or has expired.
///
/// - Parameter conceptId: The SNOMED CT concept identifier (6-18 digits)
/// - Returns: The concept result containing FSN, PT, and status
/// - Throws: `OntoserverError.conceptNotFound` if the concept doesn't exist
///           in any available edition
func lookup(conceptId: String) async throws -> ConceptResult
```

### Code Organization

Use MARK comments to organize code:

```swift
// MARK: - Properties

// MARK: - Initialization

// MARK: - Public Methods

// MARK: - Private Methods

// MARK: - Helper Types
```

### SwiftUI Best Practices

- Extract reusable views into separate types
- Use `@StateObject` for owned objects, `@ObservedObject` for passed objects
- Add accessibility labels and hints to interactive elements
- Keep views focused on a single responsibility

### Error Handling

- Use typed errors with `LocalizedError` conformance
- Provide descriptive error messages
- Handle errors gracefully in the UI

```swift
enum MyError: LocalizedError {
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case .invalidInput(let details):
            return "Invalid input: \(details)"
        }
    }
}
```

## Testing

### Test Tiers

Tests are organized into three tiers using Xcode Test Plans:

| Tier | Test Plan | Scope | When to Run |
|------|-----------|-------|-------------|
| 1 — Unit | `Codeagogo-Unit` | Pure logic tests, no network or GUI | Every commit, CI |
| 2 — Integration | `Codeagogo-Integration` | Real network calls to Ontoserver | Nightly / on-demand |
| 3 — UI | `Codeagogo-UI` | XCUITest for Settings and MenuBar | Pre-release / manual |

### Running Tests

```bash
# Run unit tests (default for development)
xcodebuild test -scheme "Codeagogo" -testPlan "Codeagogo-Unit" \
  -destination "platform=macOS"

# Run integration tests (requires network access to Ontoserver)
xcodebuild test -scheme "Codeagogo" -testPlan "Codeagogo-Integration" \
  -destination "platform=macOS"

# Run UI tests (requires GUI session)
xcodebuild test -scheme "Codeagogo" -testPlan "Codeagogo-UI" \
  -destination "platform=macOS"

# Run specific test class
xcodebuild test -scheme "Codeagogo" -destination "platform=macOS" \
  -only-testing:"CodeagogoTests/ConceptCacheTests"

# Run with code coverage
xcodebuild test -scheme "Codeagogo" -testPlan "Codeagogo-Unit" \
  -destination "platform=macOS" -enableCodeCoverage YES
```

### Writing Tests

- Add tests for new functionality
- Update tests when modifying existing behavior
- Use descriptive test method names following `test<Unit>_<scenario>_<expected>` convention
- Place view data model tests in `CodeagogoTests/ViewTests/`

```swift
func testLookupReturnsConceptFromCache() async {
    // Arrange
    let cache = TestableConceptCache()
    await cache.set("123456", result: mockConcept)

    // Act
    let result = await cache.get("123456", ttl: 3600)

    // Assert
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.conceptId, "123456")
}
```

### Test Areas

| Area | Tests | What's Covered |
|------|-------|----------------|
| Concept extraction | `ConceptIdExtractionTests` | Regex extraction, SCTID validation |
| Caching | `ConceptCacheTests` | TTL, LRU eviction, thread safety |
| FHIR client | `OntoserverClientTests` | Response parsing, errors, retry, multi-system |
| ECL | `ECLFormatterTests` | Lexer, parser, formatter, minifier |
| Diagram rendering | `DiagramRendererUnitTests` | SVG generation, normal form, text wrap |
| Lookup | `LookupViewModelTests` | ID extraction, lookup coordination |
| Visualization | `VisualizationViewModelTests`, `VisualizationModelsTests` | Property loading, data models |
| Settings | `HotKeySettingsTests`, `FHIROptionsTests` | Hotkey config, FHIR endpoint config |
| Views | `ViewTests/` (4 files) | Data models driving view display logic |
| Settings UI | `SettingsViewTests` | SwiftUI view inspection via ViewInspector |

### Dependencies

- **ViewInspector** (MIT, test target only) — Used for headless SwiftUI view testing of `SettingsView`

### Code Coverage

Target meaningful coverage of:
- Core business logic (FHIR parsing, concept extraction, ECL)
- Error handling paths
- Edge cases and boundary conditions
- Data models that drive view display

Current coverage: ~54% overall, with key modules at 75–90%.

### Known Limitation

Due to a Swift concurrency back-deploy runtime issue, creating `LookupViewModel`, `SearchViewModel`, or `VisualizationViewModel` in new test source files triggers a `malloc` crash. Existing test files are unaffected. New view tests should test data models (e.g., `ConceptResult`, `SearchResult`, `VisualizationData`) directly rather than instantiating these view models.

## Submitting Changes

### Before Submitting

1. **Ensure all unit tests pass**
   ```bash
   xcodebuild test -scheme "Codeagogo" -testPlan "Codeagogo-Unit" \
     -destination "platform=macOS"
   ```

2. **Verify no compiler warnings**
   ```bash
   xcodebuild build -scheme "Codeagogo" -destination "platform=macOS" 2>&1 | grep warning
   ```

3. **Update documentation** if needed
   - README.md for user-facing changes
   - ARCHITECTURE.md for design changes
   - CHANGELOG.md for all notable changes

4. **Add or update tests** for your changes

### Pull Request Process

1. **Create a pull request** from your feature branch to `main`

2. **Fill out the PR template** with:
   - Description of changes
   - Related issue numbers
   - Testing performed
   - Screenshots (for UI changes)

3. **Address review feedback** promptly

4. **Squash commits** if requested, keeping a clean history

### PR Title Format

Use the same format as commit messages:
```
feat: add batch concept lookup support
fix: correct cache TTL calculation
docs: update API documentation
```

## Reporting Issues

### Bug Reports

Include:
- macOS version
- App version
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs (use Cmd+Shift+D to copy diagnostics)

### Feature Requests

Include:
- Use case description
- Proposed solution
- Alternative approaches considered
- Impact on existing functionality

### Security Issues

For security vulnerabilities, please follow the process described in [SECURITY.md](SECURITY.md).

### License Headers

All Swift source files must include the Apache 2.0 license header. Run `./scripts/license-header.sh --check` to verify, or `./scripts/license-header.sh --apply` to add missing headers automatically.

## Questions?

If you have questions about contributing, feel free to:
- Open a discussion on GitHub
- Review existing issues and pull requests
- Check the documentation

Thank you for contributing to Codeagogo!
