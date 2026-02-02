# Codeagogo Architecture

This document describes the technical architecture of Codeagogo, a macOS menu bar application for working with clinical terminology codes.

## Table of Contents

- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Component Details](#component-details)
- [Data Flow](#data-flow)
- [Concurrency Model](#concurrency-model)
- [Caching Strategy](#caching-strategy)
- [Error Handling](#error-handling)
- [Security Considerations](#security-considerations)
- [Dependencies](#dependencies)
- [Design Decisions](#design-decisions)

## Overview

Codeagogo is a macOS utility that provides global hotkeys for working with clinical terminology codes (SNOMED CT, LOINC, ICD-10, etc.) from any application.

### Key Capabilities

| Hotkey | Feature | Description |
|--------|---------|-------------|
| `Control+Option+L` | **Lookup** | Display concept details for selected code |
| `Control+Option+S` | **Search** | Find concepts by term and insert into document |
| `Control+Option+R` | **Replace** | Annotate codes with `ID \| term \|` format |
| `Control+Option+E` | **ECL Format** | Pretty-print or minify ECL expressions |

### Key Characteristics

- **Menu Bar Application** — Runs as a background process with menu bar presence
- **Four Global Hotkeys** — Lookup, Search, Replace, and ECL Format
- **Multi-Code-System** — SNOMED CT, LOINC, ICD-10, RxNorm, and configurable systems
- **FHIR Integration** — Queries FHIR R4 terminology servers
- **Batch Operations** — Fast bulk lookups via `ValueSet/$expand`
- **ECL 2.x Parser** — Full Expression Constraint Language support
- **SwiftUI Interface** — Modern declarative UI framework
- **Actor-Based Concurrency** — Thread-safe operations using Swift actors

## System Architecture

```mermaid
flowchart TB
    subgraph App["Codeagogo Application"]
        subgraph Presentation["Presentation Layer"]
            MenuBar["Menu Bar<br/>Status Item"]
            Popover["Popover View<br/>(SwiftUI)"]
            SearchPanel["Search Panel<br/>(SwiftUI)"]
            Settings["Settings View<br/>(SwiftUI)"]
            ProgressHUD["Progress HUD"]
        end

        subgraph Application["Application Layer"]
            AppDelegate["App Delegate"]
            LookupVM["Lookup ViewModel<br/>(@MainActor)"]
            SearchVM["Search ViewModel<br/>(@MainActor)"]
            HotKeySettings["HotKey Settings<br/>(4 Singletons)"]
            CodeSystemSettings["Code System Settings"]
        end

        subgraph Service["Service Layer"]
            GlobalHotKey["Global HotKeys<br/>(Carbon, 4 keys)"]
            SelectionReader["Selection Reader<br/>(AppKit + AX API)"]
            ECLParser["ECL Parser<br/>(Lexer + AST)"]
            SCTIDValidator["SCTID Validator<br/>(Verhoeff)"]
            subgraph OntoClient["Ontoserver Client"]
                FHIRParser["FHIR Parser"]
                BatchLookup["Batch Lookup<br/>(ValueSet/$expand)"]
                Cache["Cache<br/>(Actor)"]
            end
        end
    end

    Server[("FHIR Terminology Server<br/>(Ontoserver)<br/>via HTTPS")]

    MenuBar --> AppDelegate
    Popover --> LookupVM
    SearchPanel --> SearchVM
    AppDelegate --> LookupVM
    AppDelegate --> SearchVM
    AppDelegate --> GlobalHotKey
    LookupVM --> SelectionReader
    LookupVM --> OntoClient
    SearchVM --> OntoClient
    AppDelegate --> ECLParser
    LookupVM --> SCTIDValidator
    OntoClient --> Server
```

## Component Details

### Presentation Layer

#### `CodeagogoApp.swift`
- **Role**: Application entry point (`@main`)
- **Responsibilities**:
  - Define the SwiftUI App structure
  - Configure the Settings scene
  - Add Help menu commands for diagnostics

#### `AppDelegate.swift`
- **Role**: NSApplication delegate
- **Responsibilities**:
  - Set up the menu bar status item
  - Manage the popover and search panel lifecycle
  - Register and handle four global hotkeys (Lookup, Search, Replace, ECL Format)
  - Coordinate lookup, replace, and ECL format operations
  - React to hotkey setting changes via Combine

#### `PopoverView.swift`
- **Role**: Lookup result display UI
- **Responsibilities**:
  - Display concept lookup results (adapts for SNOMED CT vs other systems)
  - Show inactive concept highlighting (orange warning)
  - Provide copy-to-clipboard buttons
  - Show loading and error states

#### `SearchPanelView.swift`
- **Role**: Search and insert UI
- **Responsibilities**:
  - Typeahead search interface
  - Code system and edition selection
  - Insert format selection (ID, PT, FSN, ID|PT, ID|FSN)
  - Display search results with PT, FSN, ID, and edition

#### `SearchPanelController.swift`
- **Role**: NSWindow management for search panel
- **Responsibilities**:
  - Create floating panel window
  - Position panel near cursor
  - Handle panel show/hide

#### `SettingsView.swift`
- **Role**: Application preferences UI
- **Responsibilities**:
  - Configure four hotkeys via keystroke recorder
  - Configure FHIR endpoint URL
  - Configure additional code systems
  - Configure replace settings (term format, inactive prefix)
  - Toggle debug logging
  - Provide diagnostic export functionality

#### `HotKeyRecorderView.swift`
- **Role**: Keystroke recorder control
- **Responsibilities**:
  - Display current hotkey with modifier symbols (⌃⌥⇧⌘)
  - Enter recording mode on button click
  - Capture keystroke and update settings

#### `ProgressHUD.swift`
- **Role**: Progress feedback UI
- **Responsibilities**:
  - Display progress message near cursor
  - Show/hide during batch operations

### Application Layer

#### `LookupViewModel.swift`
- **Role**: MVVM view model for lookups
- **Responsibilities**:
  - Coordinate between UI and services
  - Manage loading/error states
  - Extract concept IDs from selected text (with SCTID validation)
  - Extract existing `| term |` patterns for toggle behavior
  - Trigger lookups and publish results
- **Annotations**: `@MainActor` for UI safety
- **Protocols**: Accepts `SelectionReading` and `ConceptLookupClient` for testability

#### `SearchViewModel.swift`
- **Role**: MVVM view model for search
- **Responsibilities**:
  - Manage search state and results
  - Debounce search queries
  - Format selected concept for insertion
  - Handle code system and edition selection

#### `HotKeySettings.swift` (and variants)
- **Role**: Hotkey configuration singletons
- **Files**: `HotKeySettings`, `SearchHotKeySettings`, `ReplaceHotKeySettings`, `ECLFormatHotKeySettings`
- **Responsibilities**:
  - Store key code and modifiers for each hotkey
  - Persist settings to UserDefaults
  - Convert between NSEvent.ModifierFlags and Carbon modifiers
  - Provide human-readable hotkey description via `KeyCodeFormatter`

#### `CodeSystemSettings.swift`
- **Role**: Multi-code-system configuration
- **Responsibilities**:
  - Store enabled code systems (LOINC, ICD-10, etc.)
  - Persist to UserDefaults
  - Provide list of systems for lookup fallback

#### `ReplaceSettings.swift`
- **Role**: Replace hotkey configuration
- **Responsibilities**:
  - Store term format preference (FSN vs PT)
  - Store inactive prefix option
  - Persist to UserDefaults

#### `FHIROptions.swift`
- **Role**: FHIR endpoint configuration singleton
- **Responsibilities**:
  - Store custom FHIR server URL
  - Validate URL format
  - Fall back to default endpoint for invalid URLs
  - Persist settings to UserDefaults

### Service Layer

#### `GlobalHotKey.swift`
- **Role**: System-wide hotkey registration
- **Responsibilities**:
  - Register Carbon event handlers (supports multiple hotkeys via `id` parameter)
  - Listen for hotkey events
  - Invoke callback on hotkey press
  - Support live hotkey updates without app restart
  - Clean up handlers on deallocation
- **Framework**: Carbon (legacy but required for global hotkeys)

#### `SystemSelectionReader.swift`
- **Role**: System text selection capture and manipulation
- **Responsibilities**:
  - Snapshot current pasteboard contents
  - Simulate Cmd+C to copy selection
  - Read copied text from pasteboard
  - Restore original pasteboard contents
  - Paste text via simulated Cmd+V
  - Select inserted text via Accessibility API or keyboard fallback
- **Requirement**: Accessibility permission

#### `SCTIDValidator.swift`
- **Role**: SNOMED CT ID validation
- **Responsibilities**:
  - Validate SNOMED CT IDs using Verhoeff check digit algorithm
  - Distinguish SNOMED CT codes from other numeric codes

#### `ECLParser.swift` (and related)
- **Role**: Expression Constraint Language parser
- **Files**: `ECLLexer.swift`, `ECLToken.swift`, `ECLAST.swift`, `ECLParser.swift`, `ECLFormatter.swift`
- **Responsibilities**:
  - Tokenize ECL expressions (lexer)
  - Parse ECL 2.x grammar into AST (recursive descent parser)
  - Pretty-print AST with indentation (formatter)
  - Minify ECL to single line (minifier)
  - Toggle between pretty and minified formats

#### `OntoserverClient.swift`
- **Role**: FHIR terminology server client
- **Responsibilities**:
  - Query FHIR `CodeSystem/$lookup` endpoint
  - Batch lookup via `ValueSet/$expand` (15x faster for bulk operations)
  - Search concepts via `ValueSet/$expand` with filter
  - Fetch available SNOMED CT editions
  - Fetch available non-SNOMED code systems
  - Lookup in configured code systems (parallel search)
  - Parse FHIR Parameters responses
  - Manage in-memory cache
  - Handle multi-edition fallback
  - Implement retry with exponential backoff

#### `ConceptCache` (Actor)
- **Role**: Thread-safe result cache
- **Responsibilities**:
  - Store lookup results with timestamps
  - Implement TTL-based expiration (6 hours)
  - Implement LRU eviction at capacity (100 entries)
  - Track access patterns for LRU

### Data Models

#### `ConceptResult`
```swift
struct ConceptResult {
    let conceptId: String      // Code identifier
    let branch: String         // Edition name (for SNOMED CT) or system name
    let fsn: String?           // Fully Specified Name (SNOMED CT only)
    let pt: String?            // Preferred Term / Display
    let active: Bool?          // Active/inactive status
    let effectiveTime: String? // Version date
    let moduleId: String?      // Module identifier
    let system: String?        // Code system URI (for non-SNOMED)

    var isSNOMEDCT: Bool       // Computed: true if system is SNOMED CT
    var systemName: String     // Computed: human-readable system name
}
```

#### `SearchResult`
```swift
struct SearchResult {
    let code: String           // Concept code
    let display: String        // Display term (PT)
    let fsn: String?           // FSN if different from display
    let editionId: String?     // Edition identifier
    let editionTitle: String?  // Human-readable edition name
}
```

#### `BatchLookupResult`
```swift
struct BatchLookupResult {
    let ptByCode: [String: String]     // Code → Preferred Term
    let fsnByCode: [String: String]    // Code → Fully Specified Name
    let activeByCode: [String: Bool]   // Code → Active status
}
```

#### `SNOMEDEdition`
```swift
struct SNOMEDEdition {
    let system: String   // "http://snomed.info/sct" or "http://snomed.info/xsct"
    let version: String  // Edition URI (e.g., "http://snomed.info/sct/32506021000036107")
    let title: String    // Human-readable name
}
```

#### `ConceptMatch`
```swift
struct ConceptMatch {
    let conceptId: String      // Extracted code
    let range: Range<String.Index>  // Position in source text
    let existingTerm: String?  // Existing `| term |` if present
    let isSCTID: Bool          // True if valid SNOMED CT ID (Verhoeff check)
}
```

#### `OntoserverError`
```swift
enum OntoserverError: LocalizedError {
    case invalidURL(String)           // URL construction failed
    case conceptNotFound(String)      // Concept not in any edition/system
    case noEditionsFound              // No SNOMED editions available
}
```

## Data Flow

### Lookup Flow

```mermaid
flowchart TD
    A[User selects text<br/>in any app] --> B[User presses hotkey]
    B --> C[GlobalHotKey<br/>triggers callback]
    C --> D[Selection Reader<br/>captures text]
    D --> E[Extract Concept ID]
    E --> F[LookupViewModel]
    F --> G{Cache<br/>Check}
    G -->|Cache Hit| H[Update UI]
    G -->|Cache Miss| I[Ontoserver Client]
    I --> J[Query International<br/>Edition]
    J --> K{Found?}
    K -->|Yes| L[Cache Result]
    L --> H
    K -->|No| M[Parallel Search<br/>All Editions]
    M --> N[Return First Match]
    N --> L
```

### FHIR API Flow

```mermaid
flowchart TD
    subgraph OntoserverClient
        A[1. Check Cache] --> B{Hit?}
        B -->|Yes| C[Return cached result]
        B -->|No| D[2. Query International Edition]

        D --> E["GET /CodeSystem/$lookup<br/>?system=http://snomed.info/sct<br/>&version=.../900000000000207008<br/>&code={conceptId}"]
        E --> F{Found?}
        F -->|Yes| G[Cache and return]
        F -->|No| H[3. Fetch All Editions]

        H --> I["GET /CodeSystem<br/>?url=http://snomed.info/sct,xsct"]
        I --> J[Parse available editions]
        J --> K[4. Parallel Lookup]

        K --> L["TaskGroup {<br/>  for edition in editions {<br/>    lookup(conceptId, edition)<br/>  }<br/>}"]
        L --> M[Return first successful result]
        M --> N[5. Cache Result and Return]
    end
```

## Concurrency Model

### Swift Concurrency

The application uses Swift's modern concurrency model:

| Component | Isolation | Reason |
|-----------|-----------|--------|
| `LookupViewModel` | `@MainActor` | UI state updates |
| `HotKeySettings` | `@MainActor` | UI-bound singleton |
| `ConceptCache` | `actor` | Thread-safe data access |
| `OntoserverClient` | None (uses async/await) | I/O-bound operations |

### Parallel Operations

Edition lookups use `TaskGroup` for parallel execution:

```swift
try await withThrowingTaskGroup(of: ConceptResult?.self) { group in
    for edition in editions {
        group.addTask {
            try await self.lookupInSystem(conceptId: conceptId,
                                          system: edition.system,
                                          version: edition.version)
        }
    }

    // Return first successful result
    for try await result in group {
        if let result = result {
            group.cancelAll()  // Cancel remaining lookups
            return result
        }
    }
}
```

## Caching Strategy

### Cache Properties

| Property | Value | Rationale |
|----------|-------|-----------|
| **Type** | In-memory (actor) | Thread-safe, no persistence needed |
| **TTL** | 6 hours | Balance freshness vs. API load |
| **Max Size** | 100 entries | Limit memory usage |
| **Eviction** | LRU (Least Recently Used) | Keep frequently accessed concepts |

### Cache Entry Structure

```swift
struct CacheEntry {
    let result: ConceptResult
    let createdAt: Date       // For TTL calculation
    var lastAccessedAt: Date  // For LRU tracking
}
```

### Cache Operations

- **Get**: Check TTL, update access time, return result
- **Set**: Evict LRU if at capacity, store with timestamps
- **Eviction**: Remove entry with oldest `lastAccessedAt`

## Error Handling

### Error Types

```swift
// Network/API errors
enum OntoserverError: LocalizedError {
    case invalidURL(String)
    case conceptNotFound(String)
    case noEditionsFound
}

// User input errors
enum LookupError: LocalizedError {
    case notAConceptId
    case accessibilityPermissionLikelyMissing
}
```

### Retry Strategy

For transient network failures:

| Attempt | Delay | Total Wait |
|---------|-------|------------|
| 1 | 0s | 0s |
| 2 | 0.5s | 0.5s |
| 3 | 1.0s | 1.5s |

Retryable conditions:
- URLError: timeout, connection lost, DNS failure
- HTTP 5xx server errors

Non-retryable conditions:
- HTTP 4xx client errors
- URL construction failures

## Security Considerations

### Permissions

| Permission | Purpose | Scope |
|------------|---------|-------|
| Accessibility | Read selected text via simulated Cmd+C | On-demand only |
| Network (Outgoing) | FHIR API queries | HTTPS only |

### Data Handling

- **No persistent storage** of user data
- **Clipboard restoration** after reading
- **HTTPS-only** network communication
- **No telemetry** or analytics
- **App Sandbox disabled** — Required for Accessibility API access to other processes

### Privacy

- Selected text is only read when the user explicitly triggers a lookup
- Concept IDs are sent to the FHIR server (no personal data)
- Cache is cleared on app termination

## Dependencies

### System Frameworks

| Framework | Usage |
|-----------|-------|
| SwiftUI | User interface |
| AppKit/Cocoa | Menu bar, pasteboard, windows |
| Carbon | Global hotkey registration |
| Foundation | Networking, data, utilities |
| Combine | Reactive updates for settings |
| os.log | Structured logging |

### External Services

| Service | Purpose | Endpoint |
|---------|---------|----------|
| CSIRO Ontoserver | FHIR terminology server | `https://tx.ontoserver.csiro.au/fhir` |

## Design Decisions

### Why Carbon for Hotkeys?

macOS does not provide a modern API for global keyboard shortcuts. The Carbon `RegisterEventHotKey` API remains the only supported way to register system-wide hotkeys that work in any application.

### Why Simulated Cmd+C for Selection?

macOS restricts direct access to selected text across applications. The Accessibility API allows simulating keyboard events, making Cmd+C the most reliable cross-application method for capturing selections.

### Why FHIR Instead of Direct Snowstorm API?

FHIR provides:
- Standardized response format
- Multi-edition support in a single endpoint
- Broader compatibility with terminology servers
- Better long-term maintainability

### Why Actor for Cache?

Swift actors provide:
- Compile-time thread safety guarantees
- No manual locking required
- Natural async/await integration
- Clear isolation boundaries

### Why Optional Dependency Injection?

The `LookupViewModel` accepts optional dependencies:

```swift
init(selectionReader: SelectionReading? = nil,
     client: ConceptLookupClient? = nil)
```

This allows:
- Default production implementations
- Easy mock injection for testing
- No breaking changes to existing code
