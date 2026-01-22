# Installing SNOMED Lookup on macOS

SNOMED Lookup is a small macOS utility that lets you look up SNOMED CT concept IDs from anywhere in macOS using a global hotkey.

Because this is an internal tool and is not distributed via the Mac App Store, macOS will show a security warning the first time you open it. This is expected.

---

## Step-by-step installation

### 1. Download
Download the latest `SNOMED-Lookup-macOS.zip` from the project’s **Releases** page.

---

### 2. Unzip and install
1. Double-click the downloaded zip file to unzip it.
2. **Important**: Drag **SNOMED Lookup.app** into your **Applications** folder.
   - Do NOT run the app from Downloads - it will not work correctly.
   - Accessibility permissions are tied to the app's location.

---

### 3. Open the app (first run)
When you first try to open the app, macOS may display a warning saying the app could not be verified.

#### Option A: Right-click open (recommended)
1. In the **Applications** folder, right-click **SNOMED Lookup.app**
2. Choose **Open**
3. Click **Open** again when prompted

#### Option B: Open via System Settings
1. Attempt to open the app normally (double-click)
2. Open **System Settings → Privacy & Security**
3. Scroll down to the security section
4. Click **Open Anyway** next to SNOMED Lookup
5. Confirm **Open**

You only need to do this once.

---

## Accessibility permission (required)

SNOMED Lookup needs Accessibility permission so it can read the currently selected text when you press the hotkey.

1. Open **System Settings → Privacy & Security → Accessibility**
2. Enable **SNOMED Lookup**
3. Quit and reopen the app if it was already running

This is the same permission required by tools such as Raycast and Alfred.

---

## Using SNOMED Lookup

1. Select a SNOMED CT concept ID (for example `411116001`) in any application
2. Press the configured global hotkey
3. A small popup will appear near your cursor showing the concept details

### Changing the hotkey
- Open the app’s **Settings** window
- Adjust the key and modifier combination as desired

---

## Troubleshooting

### "App is damaged and can't be opened"

This error occurs because the app is not signed with an Apple Developer certificate. macOS quarantines downloaded apps and blocks unsigned ones.

**Fix**: Remove the quarantine attribute using Terminal:

```bash
xattr -cr "/Applications/SNOMED Lookup.app"
```

Then open the app normally. You only need to do this once.

### Nothing happens when I press the hotkey
- Ensure **SNOMED Lookup** is running
- Check Accessibility permission is enabled
- Try quitting and reopening the app

### Always shows "Not a SNOMED CT concept ID"

This usually means the app cannot capture your selection. Common causes:

1. **App not in /Applications**: The app must be run from `/Applications`, not from Downloads or other locations. Accessibility permissions are tied to the app's location.
   - Move the app to `/Applications`
   - Remove old entries from Accessibility permissions
   - Re-add the app from its new location

2. **Accessibility permission not granted**: Check System Settings → Privacy & Security → Accessibility

3. **Stale permission**: If you moved the app, you need to re-grant Accessibility permission from the new location.

### "Not a SNOMED CT concept ID" message
- Ensure you have selected the numeric concept ID itself
- Some applications may require you to click once more to ensure the text selection is active

### Network errors
- Ensure you are connected to the internet
- Some corporate networks may block access to external services

---

## Uninstalling

To remove SNOMED Lookup:
1. Quit the app
2. Drag **SNOMED Lookup.app** from Applications to the Trash
3. (Optional) Remove it from Accessibility permissions in System Settings

---

## Support

For issues, questions, or feedback, please contact the project maintainers or raise an issue in the GitHub repository.
