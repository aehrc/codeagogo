# Privacy Policy – Codeagogo (macOS)

_Last updated: 2026-03-16_

Codeagogo is a lightweight macOS utility for clinicians, terminologists, and developers. The application is designed to minimise data access and avoid persistent storage.

---

## What information the app accesses

### Selected text (on demand only)
When the user presses the configured global hotkey, the app:
- Issues a standard **Copy** action to the front-most application
- Reads the resulting clipboard text to extract a SNOMED CT concept ID
- Immediately restores the clipboard to its previous contents

The app does **not** monitor selections continuously and does **not** read the clipboard unless explicitly triggered by the user.

### Network access
When a valid concept code is detected, the app makes outbound HTTPS requests to retrieve concept details from the configured FHIR terminology server:

- **Default**: CSIRO Ontoserver — `https://tx.ontoserver.csiro.au/fhir`
- A custom FHIR R4 terminology server can be configured in Settings

Only the concept code (and code system URI, if applicable) is transmitted as part of these requests.

### Anonymous install identifier
On first launch, the app generates a random UUID (e.g. `a3f8b2c1-4d5e-6f7a-8b9c-0d1e2f3a4b5c`) and stores it locally in application preferences. This identifier:

- Is included in the User-Agent header of all terminology server requests
- Contains **no personal information** — it is a random string with no link to your identity, device, or location
- Enables the terminology server operator to count unique installations and understand usage patterns from standard server logs
- Can be **reset at any time** from Settings → Privacy → "Reset Anonymous ID"
- Is **never combined** with personal data such as name, email, or IP address

### Mailing list
The welcome screen includes a link to the [Codeagogo mailing list](https://lists.csiro.au/mailman3/lists/codeagogo.lists.csiro.au/) hosted by CSIRO. If you choose to subscribe:

- You are directed to an **external CSIRO Mailman page** — the app itself does not collect your name or email
- Subscription is entirely **opt-in** with double confirmation via email
- You can unsubscribe at any time directly from the Mailman page
- The mailing list is managed by CSIRO IM&T, not by this application

---

## What information is NOT collected

Codeagogo does **not**:

- Collect or transmit personal information (name, email, IP address, etc.)
- Store clipboard contents
- Collect identifiable usage analytics or telemetry
- Track user behaviour beyond anonymous installation counting
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

- The anonymous install identifier is persisted locally in application preferences and can be reset at any time
- Concept lookups may be cached in memory for the duration of the app session to improve performance
- All cached data is discarded when the app exits

---

## Third-party services

The app uses CSIRO Ontoserver (`tx.ontoserver.csiro.au`) as its default FHIR terminology server. Users may configure a different FHIR R4 server in Settings. Use of any third-party terminology server is subject to that server operator’s terms and policies.

---

## Changes

This privacy policy may be updated if the app’s functionality changes. Any material changes will be documented in the repository.

---

## Contact

For questions or concerns about this app or its privacy characteristics, contact the project maintainers via the GitHub repository.
