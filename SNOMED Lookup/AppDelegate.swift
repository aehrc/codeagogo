import Cocoa
import SwiftUI
import Combine
import Carbon.HIToolbox

/// The main application delegate for SNOMED Lookup.
///
/// `AppDelegate` is responsible for:
/// - Setting up the menu bar status item
/// - Managing the popover lifecycle
/// - Registering and handling the global hotkey
/// - Coordinating lookup operations
///
/// ## Application Lifecycle
///
/// On launch, the delegate:
/// 1. Enforces single-instance behavior (terminates if already running)
/// 2. Creates the menu bar status item with icon
/// 3. Configures the popover with the SwiftUI view
/// 4. Registers the global hotkey from user settings
///
/// ## Hotkey Handling
///
/// The global hotkey (default: Control+Option+L) triggers a lookup operation
/// that reads the current selection and displays results in a popover
/// anchored near the cursor.
///
/// Hotkey settings are observed via Combine, so changes in the Settings
/// window take effect immediately without restarting.
///
/// ## Menu Bar
///
/// The status item displays a magnifying glass icon. Right-clicking shows
/// a menu with "Lookup Selection" and "Quit" options.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The menu bar status item displaying the app icon.
    private var statusItem: NSStatusItem!

    /// The popover that displays lookup results.
    private var popover = NSPopover()

    /// The view model that coordinates lookups and holds results.
    private let model = LookupViewModel()

    /// Shared settings for the lookup hotkey configuration.
    private let hotKeySettings = HotKeySettings.shared

    /// Shared settings for the search hotkey configuration.
    private let searchHotKeySettings = SearchHotKeySettings.shared

    /// Shared settings for the replace hotkey configuration.
    private let replaceHotKeySettings = ReplaceHotKeySettings.shared

    /// Shared settings for the replace term format.
    private let replaceSettings = ReplaceSettings.shared

    /// The currently registered global hotkey handler for lookup.
    private var hotKey: GlobalHotKey?

    /// The currently registered global hotkey handler for search.
    private var searchHotKey: GlobalHotKey?

    /// The currently registered global hotkey handler for replace.
    private var replaceHotKey: GlobalHotKey?

    /// The search panel controller for the concept search feature.
    private let searchPanel = SearchPanelController()

    /// Active Combine subscriptions for settings observation.
    private var cancellables = Set<AnyCancellable>()

    /// Invisible window used to anchor the popover near the cursor.
    private let cursorAnchor = CursorAnchorWindow()

    /// The app that was active before showing the popover, for restoring focus.
    private var previousApp: NSRunningApplication?

    /// Called when the application finishes launching.
    ///
    /// Sets up the menu bar, popover, and global hotkey.
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            enforceSingleInstance()
        }

        setupMenuBar()
        setupPopover()
        setupHotKey()
        setupSearchHotKey()
        setupReplaceHotKey()
    }

    /// Handles reopen events (e.g., clicking the Dock icon).
    ///
    /// For menu bar apps, this prevents the default "reopen windows" behavior.
    /// Returns `true` to indicate the event was handled (do nothing).
    ///
    /// - Parameters:
    ///   - sender: The application instance
    ///   - flag: Whether there are visible windows
    /// - Returns: Always `true` to suppress default behavior
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return true
    }

    /// Ensures only one instance of the app is running.
    ///
    /// If another instance is found, activates that instance and terminates
    /// this one. This prevents confusion from multiple menu bar icons.
    private func enforceSingleInstance() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }

        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if let other = running.first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            // macOS 14+: ignoreIgnoringOtherApps is deprecated, so avoid it
            if #available(macOS 14.0, *) {
                other.activate(options: [.activateAllWindows])
            } else {
                other.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            }
            NSApp.terminate(nil)
        }
    }

    /// Sets up the menu bar status item with icon and context menu.
    ///
    /// Creates a status item with a magnifying glass icon and a menu
    /// containing "Lookup Selection" and "Quit" options.
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "SNOMED Lookup")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Lookup Selection", action: #selector(lookupSelection), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "Search Concepts...", action: #selector(showSearchPanel), keyEquivalent: "s"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    /// Configures the popover with the SwiftUI content view.
    ///
    /// Sets the popover behavior to semi-transient (closes when clicking
    /// outside) and embeds the PopoverView with the shared view model.
    private func setupPopover() {
        popover.behavior = .semitransient
        popover.contentSize = NSSize(width: 520, height: 220)
        popover.contentViewController = NSHostingController(
            rootView: PopoverView().environmentObject(model)
        )

        // Close the cursor anchor window and restore focus when the popover closes
        NotificationCenter.default.addObserver(
            forName: NSPopover.didCloseNotification,
            object: popover,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [self] in
                self.cursorAnchor.close()

                // Restore focus to the previously active app
                if let previousApp = self.previousApp {
                    previousApp.activate()
                    self.previousApp = nil
                }
            }
        }
    }

    /// Registers the global hotkey and sets up observation for settings changes.
    ///
    /// The hotkey is initially registered with the current settings values.
    /// A Combine subscription updates the hotkey whenever settings change,
    /// allowing live updates without app restart.
    private func setupHotKey() {
        // Initial registration with current settings (using thread-safe accessors)
        hotKey = GlobalHotKey(
            keyCode: HotKeySettings.currentKeyCode,
            modifiers: HotKeySettings.currentModifiers
        ) { [weak self] in
            self?.lookupSelection()
        }
        hotKey?.start()

        // Update hotkey live when settings change
        Publishers.CombineLatest(hotKeySettings.$keyCode, hotKeySettings.$modifiersRaw)
            .dropFirst()  // Skip initial value emission
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newKeyCode, newModifiersRaw in
                guard let self else { return }
                self.hotKeySettings.save()
                // Convert raw modifiers to NSEvent.ModifierFlags
                var mods: NSEvent.ModifierFlags = []
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.control])) != 0 { mods.insert(.control) }
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.option])) != 0 { mods.insert(.option) }
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.command])) != 0 { mods.insert(.command) }
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.shift])) != 0 { mods.insert(.shift) }
                self.hotKey?.update(keyCode: newKeyCode, modifiers: mods)
            }
            .store(in: &cancellables)
    }

    /// Registers the search hotkey and sets up observation for settings changes.
    ///
    /// The search hotkey opens a floating panel for searching and inserting
    /// SNOMED CT concepts. Settings changes take effect immediately.
    private func setupSearchHotKey() {
        // Initial registration with current settings (using thread-safe accessors)
        searchHotKey = GlobalHotKey(
            keyCode: SearchHotKeySettings.currentKeyCode,
            modifiers: SearchHotKeySettings.currentModifiers,
            id: 2  // Use id=2 to distinguish from lookup hotkey (id=1)
        ) { [weak self] in
            self?.showSearchPanel()
        }
        searchHotKey?.start()

        // Update hotkey live when settings change
        Publishers.CombineLatest(searchHotKeySettings.$keyCode, searchHotKeySettings.$modifiersRaw)
            .dropFirst()  // Skip initial value emission
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newKeyCode, newModifiersRaw in
                guard let self else { return }
                self.searchHotKeySettings.save()
                // Convert raw modifiers to NSEvent.ModifierFlags
                var mods: NSEvent.ModifierFlags = []
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.control])) != 0 { mods.insert(.control) }
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.option])) != 0 { mods.insert(.option) }
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.command])) != 0 { mods.insert(.command) }
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.shift])) != 0 { mods.insert(.shift) }
                self.searchHotKey?.update(keyCode: newKeyCode, modifiers: mods)
            }
            .store(in: &cancellables)
    }

    /// Registers the replace hotkey and sets up observation for settings changes.
    ///
    /// The replace hotkey looks up the selected concept ID and replaces it with
    /// the ID plus term in pipe-delimited format. Settings changes take effect
    /// immediately.
    private func setupReplaceHotKey() {
        // Initial registration with current settings (using thread-safe accessors)
        replaceHotKey = GlobalHotKey(
            keyCode: ReplaceHotKeySettings.currentKeyCode,
            modifiers: ReplaceHotKeySettings.currentModifiers,
            id: 3  // Use id=3 to distinguish from lookup (id=1) and search (id=2)
        ) { [weak self] in
            self?.replaceSelection()
        }
        replaceHotKey?.start()

        // Update hotkey live when settings change
        Publishers.CombineLatest(replaceHotKeySettings.$keyCode, replaceHotKeySettings.$modifiersRaw)
            .dropFirst()  // Skip initial value emission
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newKeyCode, newModifiersRaw in
                guard let self else { return }
                self.replaceHotKeySettings.save()
                // Convert raw modifiers to NSEvent.ModifierFlags
                var mods: NSEvent.ModifierFlags = []
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.control])) != 0 { mods.insert(.control) }
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.option])) != 0 { mods.insert(.option) }
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.command])) != 0 { mods.insert(.command) }
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.shift])) != 0 { mods.insert(.shift) }
                self.replaceHotKey?.update(keyCode: newKeyCode, modifiers: mods)
            }
            .store(in: &cancellables)
    }

    /// Toggles pipe-delimited terms for all SNOMED CT concept IDs in the selection.
    ///
    /// This method implements smart toggle behavior:
    /// - **Add mode**: If any code lacks a term or has the wrong term, adds/updates terms for all
    /// - **Remove mode**: If ALL codes already have correct terms, removes all terms
    ///
    /// This allows pressing the hotkey repeatedly to toggle between formats:
    /// 1. `385804009` → `385804009 | Diabetic care |` (add)
    /// 2. `385804009 | Diabetic care |` → `385804009` (remove, since already correct)
    /// 3. `385804009` → `385804009 | Diabetic care |` (add again)
    ///
    /// Mixed selections work too:
    /// - `385804009 | Wrong term | and 73211009` → updates both to correct terms
    ///
    /// If no valid concept IDs are found, a system beep is played.
    @objc private func replaceSelection() {
        Task { @MainActor in
            do {
                // 1. Read selection
                let text = try SystemSelectionReader().readSelectionByCopying()

                // 2. Extract all concept IDs with their positions and existing terms
                let matches = model.extractAllConceptIds(from: text)

                guard !matches.isEmpty else {
                    NSSound.beep()
                    AppLog.warning(AppLog.ui, "Replace failed: no valid concept IDs in selection")
                    return
                }

                // 3. Look up all concepts in parallel
                let client = OntoserverClient()
                let lookupResults = await withTaskGroup(
                    of: (String, ConceptResult?).self,
                    returning: [String: ConceptResult].self
                ) { group in
                    let uniqueIds = Set(matches.map { $0.conceptId })

                    for conceptId in uniqueIds {
                        group.addTask {
                            do {
                                let result = try await client.lookup(conceptId: conceptId)
                                return (conceptId, result)
                            } catch {
                                AppLog.warning(AppLog.ui, "Lookup failed for \(conceptId): \(error)")
                                return (conceptId, nil)
                            }
                        }
                    }

                    var results: [String: ConceptResult] = [:]
                    for await (conceptId, result) in group {
                        if let result {
                            results[conceptId] = result
                        }
                    }
                    return results
                }

                // 4. Capture term format setting and define helper
                let termFormat = replaceSettings.termFormat
                func expectedTerm(for conceptId: String) -> String? {
                    guard let lookupResult = lookupResults[conceptId] else { return nil }
                    switch termFormat {
                    case .fsn:
                        return lookupResult.fsn ?? lookupResult.pt
                    case .pt:
                        return lookupResult.pt ?? lookupResult.fsn
                    }
                }

                // 5. Check if ALL matches already have correct terms (toggle to remove mode)
                let allCorrect = matches.allSatisfy { match in
                    guard let expected = expectedTerm(for: match.conceptId),
                          let existing = match.existingTerm else {
                        return false
                    }
                    return existing == expected
                }

                // 6. Build replacement string
                var result = text
                for match in matches.reversed() {
                    let conceptId = match.conceptId
                    let replacement: String

                    if allCorrect {
                        // Remove mode: strip the pipe-delimited term
                        replacement = conceptId
                    } else {
                        // Add/update mode
                        if let term = expectedTerm(for: conceptId) {
                            replacement = "\(conceptId) | \(term) |"
                        } else {
                            // Lookup failed - keep as-is (just the code, or code with existing term)
                            replacement = String(text[match.range])
                        }
                    }

                    result.replaceSubrange(match.range, with: replacement)
                }

                // 7. Put on clipboard
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(result, forType: .string)

                // 8. Small delay to ensure clipboard is ready
                try await Task.sleep(nanoseconds: 50_000_000)  // 50ms

                // 9. Send Cmd+V to replace selection
                if !SystemSelectionReader().sendCmdV() {
                    throw LookupError.accessibilityPermissionLikelyMissing
                }

                let action = allCorrect ? "Removed terms from" : "Added/updated terms for"
                AppLog.info(AppLog.ui, "\(action) \(matches.count) concept IDs")

            } catch {
                NSSound.beep()
                AppLog.error(AppLog.ui, "Replace failed: \(error)")
            }
        }
    }

    /// Shows the SNOMED CT search panel near the cursor.
    @objc private func showSearchPanel() {
        let mouse = NSEvent.mouseLocation
        searchPanel.show(at: mouse)
    }

    /// Toggles the popover visibility when clicking the menu bar icon.
    ///
    /// - Parameter sender: The sender of the action (unused)
    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    /// Performs a SNOMED CT concept lookup from the current selection.
    ///
    /// This is the main action triggered by:
    /// - The global hotkey
    /// - The "Lookup Selection" menu item
    ///
    /// Captures the mouse position before the async operation, performs
    /// the lookup, then shows the popover near the cursor if not already shown.
    @objc private func lookupSelection() {
        let mouse = NSEvent.mouseLocation

        // Capture the currently active app before we take focus
        previousApp = NSWorkspace.shared.frontmostApplication

        Task { @MainActor in
            await model.lookupFromSystemSelection()

            if !popover.isShown {
                cursorAnchor.showPopover(popover, at: mouse, preferredEdge: .maxY)

                // Activate our app and make the popover key so Escape works
                NSApp.activate(ignoringOtherApps: true)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }

    /// Terminates the application.
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
