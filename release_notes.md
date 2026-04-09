
### Added
- **Simplify ECL** (`Shift+Control+Option+E`): One-way simplification — removes redundant parentheses and formats. Derived from the Format ECL hotkey by adding Shift.
- **Replace Inactive Concepts** (`Control+Option+I`): Select ECL containing inactive SNOMED CT concepts and replace them with active equivalents from historical associations (REPLACED BY, SAME AS, POSSIBLY EQUIVALENT TO, ALTERNATIVE) via `ConceptMap/$translate`.
- **ECL Workbench: Inactive concept quick fixes**: Cmd+. on an inactive concept now offers "Replace with..." quick fixes showing active replacements from historical associations.
- **ECL Workbench: Toggle display terms** (`Shift+Alt+T`): Smart toggle that adds display terms via FHIR lookup when bare, strips them when present.
- **Canonical ECL comparison**: `canonicalise()` and `compareExpressions()` for structural equivalence checking without FHIR calls.
- **Menu hotkey display**: All menu items now show the configured global hotkey shortcut, updating dynamically when settings change.

### Changed
- Updated `@aehrc/ecl-core` to 1.1.2 with `removeRedundantParentheses` formatter option, canonical comparison, and historical association lookups.
- Updated `@aehrc/ecl-editor` to 1.1.2 with inactive concept quick fixes, shared language registration fix, and cleaner embedded appearance.
