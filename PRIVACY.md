# Privacy Policy – Codeagogo (macOS)

_Last updated: 2026-01-13_

Codeagogo is a lightweight macOS utility intended for internal use by clinicians, terminologists, and developers. The application is designed to minimise data access and avoid persistent storage.

---

## What information the app accesses

### Selected text (on demand only)
When the user presses the configured global hotkey, the app:
- Issues a standard **Copy** action to the front-most application
- Reads the resulting clipboard text to extract a SNOMED CT concept ID
- Immediately restores the clipboard to its previous contents

The app does **not** monitor selections continuously and does **not** read the clipboard unless explicitly triggered by the user.

### Network access
When a valid SNOMED CT concept ID is detected, the app makes outbound HTTPS requests to retrieve concept details from:

- **SNOMED Concept Lookup Service**
  - https://lookup.snomedtools.org/
  - Backed by Snowstorm

Only the concept ID is transmitted as part of these requests.

---

## What information is NOT collected

Codeagogo does **not**:

- Collect or transmit personal information
- Store clipboard contents
- Persist user data to disk
- Collect usage analytics or telemetry
- Track user behaviour
- Access files, folders, or other system resources
- Use background monitoring or keylogging

---

## Permissions

### Accessibility
The app requires **Accessibility** permission to:
- Issue a standard keyboard copy command (`Cmd+C`) in the active application

This permission is required for many macOS productivity tools (for example Raycast, Alfred, and BetterTouchTool) and is only used when the user explicitly triggers a lookup.

### Network access
The app requires outbound network access to:
- Resolve DNS
- Make HTTPS requests to the SNOMED Concept Lookup Service

No inbound network connections are used.

---

## Data retention

- No data is persisted to disk
- Concept lookups may be cached in memory for the duration of the app session to improve performance
- All cached data is discarded when the app exits

---

## Third-party services

The app relies on the SNOMED Concept Lookup Service operated by SNOMED International.  
Use of this service is subject to SNOMED International’s terms and policies.

---

## Changes

This privacy policy may be updated if the app’s functionality changes. Any material changes will be documented in the repository.

---

## Contact

For questions or concerns about this app or its privacy characteristics, contact the project maintainers via the GitHub repository.
