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

Please be respectful and constructive in all interactions. We aim to maintain a welcoming and inclusive environment for all contributors.

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

### 4. Grant Permissions

When running the app:
- Grant Accessibility permission when prompted
- If selection capture fails, re-add the app in System Settings → Privacy & Security → Accessibility

### 5. Verify Setup

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

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme "Codeagogo" -destination "platform=macOS"

# Run specific test class
xcodebuild test -scheme "Codeagogo" -destination "platform=macOS" \
  -only-testing:"CodeagogoTests/ConceptCacheTests"

# Run with verbose output
xcodebuild test -scheme "Codeagogo" -destination "platform=macOS" \
  2>&1 | grep -E "(Test Case|passed|failed)"
```

### Writing Tests

- Add tests for new functionality
- Update tests when modifying existing behavior
- Use descriptive test method names

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

### Test Categories

| Category | Purpose |
|----------|---------|
| Unit Tests | Test individual functions and types in isolation |
| Integration Tests | Test component interactions with mock dependencies |

### Code Coverage

Aim for meaningful coverage of:
- Core business logic
- Error handling paths
- Edge cases
- UI state transitions

## Submitting Changes

### Before Submitting

1. **Ensure all tests pass**
   ```bash
   xcodebuild test -scheme "Codeagogo" -destination "platform=macOS"
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

For security vulnerabilities, please contact the maintainers directly rather than opening a public issue.

## Questions?

If you have questions about contributing, feel free to:
- Open a discussion on GitHub
- Review existing issues and pull requests
- Check the documentation

Thank you for contributing to Codeagogo!
