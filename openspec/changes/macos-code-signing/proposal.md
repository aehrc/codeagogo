## Why

Unsigned macOS apps trigger Gatekeeper warnings ("this app can't be opened because it is from an unidentified developer"), which is a significant barrier to adoption — especially for a tool that requires Accessibility permissions. Developer ID signing plus Apple notarization removes this friction entirely.

## What Changes

- Update `package-zip.sh` (or replace with a new `release.sh`) to include Developer ID code signing, notarization via `notarytool`, and stapling
- Add a `.dmg` packaging step (drag-to-Applications disk image) as the primary distribution format
- Document the signing prerequisites and release process
- Add entitlements file if not already present (Accessibility, Hardened Runtime)

## Capabilities

### New Capabilities
- `macos-code-signing`: Build script that signs the app with a Developer ID certificate, submits to Apple for notarization, waits for approval, and staples the notarization ticket to the binary. Produces a signed, notarized `.dmg` ready for distribution.

### Modified Capabilities
<!-- None -->

## Impact

- **package-zip.sh**: Replaced or extended with signing/notarization steps
- **Codeagogo.entitlements**: May need updates for Hardened Runtime compatibility
- **New files**: `release.sh` (or equivalent), release documentation
- **No code changes** — this is build/packaging only
- **No new dependencies** (uses Xcode command-line tools)

## Prerequisites

- Apple Developer Program team seat (via CSIRO Publications)
- Developer ID Application certificate installed in keychain
- App-specific password or API key for `notarytool`
- Team ID for notarization submission

## Open Questions

1. **Certificate access**: Will we use a shared team certificate or an individual one? Affects CI/CD setup.
2. **DMG vs ZIP**: DMG with drag-to-Applications is more polished; ZIP is simpler. Recommend DMG.
3. **Entitlements**: Need to verify Hardened Runtime compatibility with Accessibility APIs and Carbon hotkeys.
