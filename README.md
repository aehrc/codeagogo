# SNOMED Lookup (macOS)

A lightweight macOS utility that lets you look up **SNOMED CT concept IDs from anywhere in macOS**.

Select a SNOMED CT concept ID in any application, press a global hotkey, and a popover appears showing the concept’s details retrieved from the SNOMED Concept Lookup Service.

This is intended as a **developer / terminology power tool** for internal use.

---

## Features

- Global hotkey (works system-wide)
- Reads the current text selection
- Looks up SNOMED CT concepts via the SNOMED Concept Lookup Service (Snowstorm)
- Displays:
  - Concept ID
  - Preferred Term (PT)
  - Fully Specified Name (FSN)
  - Active status
  - Module and effective time
- Popover appears near the mouse cursor
- Configurable hotkey
- In-memory caching to avoid repeated network calls

---

## Requirements

- macOS 13+ (Ventura or newer recommended)
- Internet access
- Accessibility permission (required to read selected text)

---

## Installation (recommended)

1. Download the latest `SNOMED-Lookup-macOS.zip` from the **Releases** page.
2. Unzip the archive.
3. Drag **SNOMED Lookup.app** into `/Applications`.
4. Launch the app.

### First run permissions

On first use, macOS will prompt you to grant **Accessibility** permission.

If you are not prompted automatically:

1. Open **System Settings → Privacy & Security → Accessibility**
2. Enable **SNOMED Lookup**
3. Quit and relaunch the app

This permission is required so the app can issue a standard **Copy** action to read the current selection.  
This is the same permission required by tools like Raycast, Alfred, and BetterTouchTool.

---

## Usage

1. Select a SNOMED CT concept ID (for example `411116001`) in any app.
2. Press the configured hotkey (default shown in Settings).
3. A popover will appear near the cursor showing the concept details.

### Settings
Open the app’s **Settings** window to:
- Change the global hotkey
- Adjust modifier keys

---

## Data sources

Concept data is retrieved from:

- **SNOMED Concept Lookup Service**
  - https://lookup.snomedtools.org/
  - Backed by Snowstorm
  - Searches across editions and branches

No user data is stored or transmitted beyond the selected concept ID.

---

## Privacy

- The app only reads the current text selection when the hotkey is pressed.
- Clipboard contents are restored immediately after reading.
- No data is persisted to disk.
- No telemetry or analytics are collected.

See [PRIVACY.md](PRIVACY.md) for details.

---

## Development

### Build requirements
- Xcode 15+
- SwiftUI
- App Sandbox enabled with **Outgoing Connections (Client)**

### Running locally
When running from Xcode, ensure that the **built app** (not Xcode itself) has Accessibility permission.  
If selection capture fails, re-add the app in **System Settings → Accessibility**.

---

## Distribution notes (internal)

For internal distribution, the recommended approach is:
- Build a Release configuration
- Package the `.app` into a zip
- Publish via GitHub Releases

Notarisation is recommended but not strictly required for internal use.

---

## License

Copyright © CSIRO / AEHRC  
Internal use only unless otherwise approved.
