# Installing Codeagogo on macOS

Codeagogo is a macOS menu bar utility for working with clinical terminology codes. It provides global hotkeys to look up, search, and annotate SNOMED CT, LOINC, ICD-10, and other code systems from any application.

> [!WARNING]
> Because this app is not distributed via the Mac App Store, macOS will show a security warning the first time you open it. This is expected.

---

## Install via Homebrew (recommended)

```bash
brew tap aehrc/codeagogo https://github.com/aehrc/codeagogo
brew install --cask codeagogo
```

This installs Codeagogo to `/Applications` and handles updates via `brew upgrade --cask codeagogo`.

Skip to [Accessibility permission](#accessibility-permission-required) below.

---

## Manual installation

### 1. Download
Download the latest `Codeagogo-macOS.zip` from the [Releases page](https://github.com/aehrc/codeagogo/releases/latest).

---

### 2. Unzip and install
1. Double-click the downloaded zip file to unzip it.
2. **Important**: Drag **Codeagogo.app** into your **Applications** folder.
   - Do NOT run the app from Downloads - it will not work correctly.
   - Accessibility permissions are tied to the app’s location.

---

### 3. Open the app (first run)

> **Why am I seeing a warning?**
> macOS shows a "Codeagogo Not Opened" warning because the app is not yet signed with an Apple Developer ID certificate. This is a standard macOS Gatekeeper check — it does **not** mean the app is harmful. We're currently working with our organisation (CSIRO) to obtain an Apple Developer ID so this warning goes away in a future release. We're sorry for the inconvenience.
>
> If you installed via **Homebrew**, this step is handled automatically — you can skip ahead to [Accessibility permission](#accessibility-permission-required).

When you first try to open the app, macOS will display a warning saying **"Codeagogo Not Opened — Apple could not verify Codeagogo is free of malware"**. Click **Done** (not "Move to Bin"), then follow one of these steps:

#### Option A: Right-click open (recommended)
1. In the **Applications** folder, right-click **Codeagogo.app**
2. Choose **Open**
3. Click **Open** again when prompted

#### Option B: Open via System Settings
1. Attempt to open the app normally (double-click) — the warning will appear
2. Open **System Settings → Privacy & Security**
3. Scroll down to the security section
4. Click **Open Anyway** next to Codeagogo
5. Confirm **Open**

#### Option C: Remove quarantine via Terminal
If neither option above works, run this in Terminal:
```bash
xattr -cr /Applications/Codeagogo.app
```
Then open the app normally.

You only need to do this once. After the first successful open, macOS will remember your choice.

---

## Accessibility permission (required)

Codeagogo needs Accessibility permission so it can read the currently selected text when you press the hotkey.

1. Open **System Settings → Privacy & Security → Accessibility**
2. Enable **Codeagogo**
3. Quit and reopen the app if it was already running

This is the same permission required by tools such as Raycast and Alfred.

---

## Using Codeagogo

### Default Hotkeys

| Hotkey | Action |
|--------|--------|
| `Control+Option+L` | **Lookup** — Show concept details for selected code |
| `Control+Option+S` | **Search** — Open search panel to find and insert concepts |
| `Control+Option+R` | **Replace** — Annotate selected codes with `ID \| term \|` format |
| `Control+Option+E` | **ECL Format** — Toggle ECL between pretty-printed and minified |
| `Control+Option+H` | **Shrimp** — Open selected concept in Shrimp browser |

### Basic Lookup

1. Select a concept code (e.g., `411116001` for SNOMED CT, or `8480-6` for LOINC)
2. Press `Control+Option+L`
3. A popup appears near your cursor showing the concept details

### Changing Hotkeys

1. Open **Settings** (click the menu bar icon or press `Cmd+,`)
2. Click **Record** next to any hotkey
3. Press your desired key combination (must include at least one modifier)
4. The hotkey updates immediately

---

## Troubleshooting

### "App is damaged and can't be opened"

This error occurs because the app is not signed with an Apple Developer certificate. macOS quarantines downloaded apps and blocks unsigned ones.

**Fix**: Remove the quarantine attribute using Terminal:

```bash
xattr -cr "/Applications/Codeagogo.app"
```

Then open the app normally. You only need to do this once.

### Nothing happens when I press the hotkey
- Ensure **Codeagogo** is running
- Check Accessibility permission is enabled
- Try quitting and reopening the app

### Always shows "Not a valid concept code"

This usually means the app cannot capture your selection. Common causes:

1. **App not in /Applications**: The app must be run from `/Applications`, not from Downloads or other locations. Accessibility permissions are tied to the app's location.
   - Move the app to `/Applications`
   - Remove old entries from Accessibility permissions
   - Re-add the app from its new location

2. **Accessibility permission not granted**: Check System Settings → Privacy & Security → Accessibility

3. **Stale permission**: If you moved the app, you need to re-grant Accessibility permission from the new location.

### Code not found
- For SNOMED CT: Ensure you have selected the numeric concept ID itself
- For other code systems: Ensure the code system is enabled in Settings → Additional Code Systems
- Some applications may require you to click once more to ensure the text selection is active

### Network errors
- Ensure you are connected to the internet
- Some corporate networks may block access to external services

---

## Uninstalling

To remove Codeagogo:
1. Quit the app
2. Drag **Codeagogo.app** from Applications to the Trash
3. (Optional) Remove it from Accessibility permissions in System Settings

---

## Support

For issues, questions, or feedback, please contact the project maintainers or raise an issue in the GitHub repository.
