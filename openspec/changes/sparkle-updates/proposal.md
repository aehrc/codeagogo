## Why

Without auto-updates, users must manually check GitHub for new versions. Sparkle is the de facto standard framework for macOS app updates outside the App Store — used by Firefox, VLC, iTerm2, and hundreds of other apps. It handles checking for updates, downloading, verifying signatures, and installing — all in-app with no browser required. Auto-update should be enabled by default so users always have the latest version.

## What Changes

- Integrate the Sparkle 2.x framework via Swift Package Manager
- Host an appcast XML file (version feed) on the website or in the repo
- Sign updates with an Ed25519 key for integrity verification
- Add "Check for Updates" menu item and auto-check on launch (enabled by default)
- Add update preferences to Settings (auto-check on/off, check now button)
- Update the release process to generate appcast entries and sign update archives

## Capabilities

### New Capabilities
- `sparkle-updates`: In-app update mechanism using the Sparkle framework. Checks an appcast feed for new versions. Downloads, verifies (Ed25519 signature), and installs updates in-place. Auto-check is enabled by default. Users can check manually via menu item or disable automatic checks in Settings.

### Modified Capabilities
- `privacy-settings`: Add update check preferences (auto-check on/off, check now button) to the Settings view.

## Impact

- **AppDelegate.swift**: Initialize Sparkle updater, add "Check for Updates" menu item
- **SettingsView.swift**: Add update preferences section
- **Info.plist**: Add Sparkle configuration keys (feed URL, public key)
- **Release process**: Generate and sign appcast entries using `generate_appcast` tool
- **New dependency**: Sparkle 2.x framework (via Swift Package Manager) — MIT licence, open source
- **CHANGELOG.md**: New entry

## How Sparkle Works

1. App checks the appcast URL on a schedule (default: daily, configurable)
2. Appcast lists versions with download URLs, Ed25519 signatures, and release notes
3. If a newer version exists, Sparkle shows an update dialog with release notes
4. User clicks "Install Update" — Sparkle downloads the archive, verifies the signature, replaces the app, and relaunches
5. No browser, no manual download, no drag-to-Applications

## Prerequisites

- `macos-code-signing` change completed (signed builds required for updates)
- Appcast hosting decided (website or repo — see `website-landing-page` change)
- Ed25519 key pair generated for update signing (separate from Apple code signing)

## Notes

- This is the first external dependency in the project. Sparkle is MIT-licenced, widely used, and actively maintained. The alternative (rolling our own update checker) would be significantly more work for a worse result.
- Auto-check is enabled by default with a daily interval. Users can disable it in Settings.

## Open Questions

1. **Appcast hosting**: On the website (alongside the landing page) or committed to the repo (served via GitHub raw URL)?
2. **Appcast generation**: Automate with `generate_appcast` tool (ships with Sparkle) in the release workflow, or maintain manually? Recommend automating.
3. **Delta updates**: Sparkle supports binary diffs (smaller downloads). Worth enabling or overkill for a small app?
