// Copyright 2026 Commonwealth Scientific and Industrial Research Organisation (CSIRO)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Cocoa
import SwiftUI
import Combine
import Carbon.HIToolbox
import ApplicationServices
import ServiceManagement

/// The main application delegate for Codeagogo.
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
    private lazy var popover = NSPopover()

    /// The view model that coordinates lookups and holds results.
    private lazy var model = LookupViewModel()

    /// Shared settings for the lookup hotkey configuration.
    private lazy var hotKeySettings = HotKeySettings.shared

    /// Shared settings for the search hotkey configuration.
    private lazy var searchHotKeySettings = SearchHotKeySettings.shared

    /// Shared settings for the replace hotkey configuration.
    private lazy var replaceHotKeySettings = ReplaceHotKeySettings.shared

    /// Shared settings for the replace term format.
    private lazy var replaceSettings = ReplaceSettings.shared

    /// Shared settings for the ECL format hotkey configuration.
    private lazy var eclFormatHotKeySettings = ECLFormatHotKeySettings.shared

    /// Shared settings for the Shrimp browser hotkey configuration.
    private lazy var shrimpHotKeySettings = ShrimpHotKeySettings.shared

    /// The currently registered global hotkey handler for lookup.
    private var hotKey: GlobalHotKey?

    /// The currently registered global hotkey handler for search.
    private var searchHotKey: GlobalHotKey?

    /// The currently registered global hotkey handler for replace.
    private var replaceHotKey: GlobalHotKey?

    /// The currently registered global hotkey handler for ECL formatting.
    private var eclFormatHotKey: GlobalHotKey?

    /// Bridge to ecl-core (TypeScript) running in JavaScriptCore for ECL operations.
    private lazy var eclBridge = ECLBridge()

    /// The currently registered global hotkey handler for ECL evaluation.
    private var evaluateHotKey: GlobalHotKey?

    /// Shared settings for the ECL evaluation hotkey configuration.
    private lazy var evaluateHotKeySettings = EvaluateHotKeySettings.shared

    /// The currently registered global hotkey handler for opening in Shrimp.
    private var shrimpHotKey: GlobalHotKey?

    /// Shared API client for replace and other operations (preserves cache across calls).
    private lazy var ontoserverClient = OntoserverClient()

    /// The search panel controller for the concept search feature.
    private lazy var searchPanel = SearchPanelController()

    /// The visualization panel controller for concept diagrams.
    private lazy var visualizationPanel = VisualizationPanelController()

    /// The evaluation panel controller for ECL evaluation results.
    private lazy var evaluatePanel: EvaluatePanelController = {
        let controller = EvaluatePanelController()
        controller.onShowDiagram = { [weak self] concept, sourcePanel in
            let result = ConceptResult(
                conceptId: concept.code,
                branch: "",
                fsn: concept.fsn,
                pt: concept.display,
                active: nil,
                effectiveTime: nil,
                moduleId: nil,
                system: "http://snomed.info/sct"
            )
            if let frame = sourcePanel?.frame {
                self?.visualizationPanel.show(for: result, beside: frame)
            } else {
                self?.visualizationPanel.show(for: result, near: NSEvent.mouseLocation)
            }
        }
        return controller
    }()

    /// The ECL reference panel controller for the operator quick reference.
    private lazy var eclReferencePanel = ECLReferencePanelController()

    /// Active Combine subscriptions for settings observation.
    private var cancellables = Set<AnyCancellable>()

    /// Invisible window used to anchor the popover near the cursor.
    private lazy var cursorAnchor = CursorAnchorWindow()

    /// The app that was active before showing the popover, for restoring focus.
    private var previousApp: NSRunningApplication?

    /// Progress HUD for showing feedback during long operations.
    private lazy var progressHUD = ProgressHUD()

    /// The update menu item, updated dynamically when an update is available.
    private var updateMenuItem: NSMenuItem?

    /// The base menu bar icon without any badge.
    private var baseMenuBarImage: NSImage?

    /// Called when the application finishes launching.
    ///
    /// Sets up the menu bar, popover, and global hotkey.
    func applicationDidFinishLaunching(_ notification: Notification) {
        let isUnitTesting = NSClassFromString("XCTestCase") != nil
            && !ProcessInfo.processInfo.arguments.contains("--ui-testing")
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--ui-testing")

        if !isUnitTesting && !isUITesting {
            enforceSingleInstance()
        }

        // Skip full app setup during unit tests to avoid Carbon hotkey
        // registration/deregistration crashes in the test host
        guard !isUnitTesting else { return }

        // Ensure anonymous install ID exists before any Ontoserver requests
        _ = InstallMetrics.shared

        checkAccessibilityPermission()
        setupMenuBar()
        setupPopover()
        setupHotKey()
        setupSearchHotKey()
        setupReplaceHotKey()
        setupECLFormatHotKey()
        setupEvaluateHotKey()
        setupShrimpHotKey()
        setupUpdateChecker()
        showWelcomeIfNeeded()
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

    /// Checks if the app has Accessibility permission and prompts if needed.
    ///
    /// Sets up the update checker with periodic checks and UI updates.
    private func setupUpdateChecker() {
        // Observe changes to updateAvailable and refresh the menu bar badge
        UpdateChecker.shared.$updateAvailable
            .receive(on: DispatchQueue.main)
            .sink { [weak self] available in
                self?.updateMenuBarBadge(updateAvailable: available)
                self?.updateMenuItemTitle(updateAvailable: available)
            }
            .store(in: &cancellables)

        UpdateChecker.shared.startPeriodicChecks()
    }

    /// Loads the custom menu bar icon from the asset catalog.
    ///
    /// The icon is an Ontoserver-style cloud with hollow network dots,
    /// stored as a template image so macOS adapts it for light/dark mode.
    private func makeMenuBarIcon() -> NSImage {
        if let icon = NSImage(named: "MenuBarIcon") {
            icon.isTemplate = true
            return icon
        }
        return NSImage(systemSymbolName: "cloud.fill", accessibilityDescription: "Codeagogo")!
    }

    /// Overlays an orange dot on the menu bar icon when an update is available.
    ///
    /// The badged image is non-template so the orange dot renders in colour.
    /// The base icon is redrawn using the menu bar's foreground colour
    /// (controlTextColor) so it adapts to light/dark mode correctly.
    private func updateMenuBarBadge(updateAvailable: Bool) {
        guard let button = statusItem?.button, let baseImage = baseMenuBarImage else { return }

        if updateAvailable {
            let size = baseImage.size
            let badged = NSImage(size: size, flipped: false) { rect in
                // Draw the base icon tinted to match the menu bar appearance
                NSColor.controlTextColor.set()
                baseImage.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)

                // Draw orange dot in the top-right corner
                let dotSize: CGFloat = 5
                let dotRect = NSRect(
                    x: rect.maxX - dotSize,
                    y: rect.maxY - dotSize,
                    width: dotSize,
                    height: dotSize
                )
                NSColor.orange.setFill()
                NSBezierPath(ovalIn: dotRect).fill()
                return true
            }
            badged.isTemplate = false
            button.image = badged
        } else {
            button.image = baseImage
        }
    }

    /// Updates the menu item title to show the available version.
    private func updateMenuItemTitle(updateAvailable: Bool) {
        if updateAvailable, let version = UpdateChecker.shared.latestVersion {
            updateMenuItem?.title = "Update Available — v\(version)"
        } else {
            updateMenuItem?.title = "Check for Updates..."
        }
    }

    /// Manually checks for updates, opening the release page if one is available.
    @objc private func checkForUpdatesManually() {
        Task {
            let available = await UpdateChecker.shared.checkForUpdates()
            if available {
                openReleasePage()
            } else {
                // Show brief "up to date" feedback
                let alert = NSAlert()
                alert.messageText = "You're up to date"
                alert.informativeText = "Codeagogo v\(UpdateChecker.shared.currentVersion) is the latest version."
                alert.alertStyle = .informational
                alert.runModal()
            }
        }
    }

    /// Opens the GitHub Releases page for the latest release.
    @objc private func openReleasePage() {
        if let url = UpdateChecker.shared.releaseURL {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(URL(string: "https://github.com/aehrc/codeagogo/releases/latest")!)
        }
    }

    /// Accessibility permission is required for:
    /// - Reading selected text via simulated Cmd+C
    /// - Setting text selection via the Accessibility API (for select-after-paste)
    ///
    /// If permission is not granted, shows the system prompt directing the user
    /// to System Settings > Privacy & Security > Accessibility.
    private func checkAccessibilityPermission() {
        // Log app bundle info to help diagnose permission issues
        let bundlePath = Bundle.main.bundlePath
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
        AppLog.info(AppLog.general, "App bundle: \(bundlePath)")
        AppLog.info(AppLog.general, "Bundle ID: \(bundleID)")

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        AppLog.info(AppLog.general, "Accessibility permission check: trusted=\(trusted)")

        if !trusted {
            AppLog.warning(AppLog.general, "Accessibility not trusted. If the app appears enabled in System Settings, try removing and re-adding this specific app bundle: \(bundlePath)")
        }
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
            let image = makeMenuBarIcon()
            button.image = image
            baseMenuBarImage = image
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Lookup Selection", action: #selector(lookupSelection), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "Search Concepts...", action: #selector(showSearchPanel), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Replace Selection", action: #selector(replaceSelection), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Format ECL", action: #selector(formatECLSelection), keyEquivalent: "e"))
        menu.addItem(NSMenuItem(title: "Evaluate ECL...", action: #selector(evaluateECLSelection), keyEquivalent: "v"))
        menu.addItem(NSMenuItem(title: "ECL Reference...", action: #selector(showECLReference), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open in Shrimp", action: #selector(openInShrimpFromSelection), keyEquivalent: "b"))
        menu.addItem(NSMenuItem.separator())

        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdatesManually), keyEquivalent: "")
        updateItem.isHidden = false
        updateMenuItem = updateItem
        menu.addItem(updateItem)

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

        // Wire visualization callback
        model.onVisualize = { [weak self] result in
            guard let self = self else { return }
            // Get popover location (or fall back to mouse location)
            let point: NSPoint
            if let anchorWindow = self.cursorAnchor.nsWindow {
                point = anchorWindow.frame.origin
            } else {
                point = NSEvent.mouseLocation
            }
            self.visualizationPanel.show(for: result, near: point)
        }

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

    /// Registers the ECL format hotkey and sets up observation for settings changes.
    ///
    /// The ECL format hotkey pretty-prints selected ECL expressions for improved
    /// readability. Settings changes take effect immediately.
    private func setupECLFormatHotKey() {
        // Initial registration with current settings (using thread-safe accessors)
        eclFormatHotKey = GlobalHotKey(
            keyCode: ECLFormatHotKeySettings.currentKeyCode,
            modifiers: ECLFormatHotKeySettings.currentModifiers,
            id: 4  // Use id=4 to distinguish from other hotkeys
        ) { [weak self] in
            self?.formatECLSelection()
        }
        eclFormatHotKey?.start()

        // Update hotkey live when settings change
        Publishers.CombineLatest(eclFormatHotKeySettings.$keyCode, eclFormatHotKeySettings.$modifiersRaw)
            .dropFirst()  // Skip initial value emission
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newKeyCode, newModifiersRaw in
                guard let self else { return }
                self.eclFormatHotKeySettings.save()
                // Convert raw modifiers to NSEvent.ModifierFlags
                var mods: NSEvent.ModifierFlags = []
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.control])) != 0 { mods.insert(.control) }
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.option])) != 0 { mods.insert(.option) }
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.command])) != 0 { mods.insert(.command) }
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.shift])) != 0 { mods.insert(.shift) }
                self.eclFormatHotKey?.update(keyCode: newKeyCode, modifiers: mods)
            }
            .store(in: &cancellables)
    }

    /// Registers the ECL evaluation hotkey and sets up observation for settings changes.
    ///
    /// The evaluate hotkey reads the current selection, evaluates it as an ECL
    /// expression via the terminology server, and shows a panel with matching concepts.
    /// Uses id=6 to distinguish from other hotkeys.
    private func setupEvaluateHotKey() {
        evaluateHotKey = GlobalHotKey(
            keyCode: EvaluateHotKeySettings.currentKeyCode,
            modifiers: EvaluateHotKeySettings.currentModifiers,
            id: 6
        ) { [weak self] in
            self?.evaluateECLSelection()
        }
        evaluateHotKey?.start()

        Publishers.CombineLatest(evaluateHotKeySettings.$keyCode, evaluateHotKeySettings.$modifiersRaw)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newKeyCode, newModifiersRaw in
                guard let self else { return }
                self.evaluateHotKeySettings.save()
                var mods: NSEvent.ModifierFlags = []
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.control])) != 0 { mods.insert(.control) }
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.option])) != 0 { mods.insert(.option) }
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.command])) != 0 { mods.insert(.command) }
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.shift])) != 0 { mods.insert(.shift) }
                self.evaluateHotKey?.update(keyCode: newKeyCode, modifiers: mods)
            }
            .store(in: &cancellables)
    }

    /// Registers the Shrimp browser hotkey and sets up observation for settings changes.
    ///
    /// The Shrimp hotkey opens the selected concept in the Shrimp terminology browser.
    /// Uses id=5 to distinguish from other hotkeys.
    private func setupShrimpHotKey() {
        // Initial registration with current settings (using thread-safe accessors)
        shrimpHotKey = GlobalHotKey(
            keyCode: ShrimpHotKeySettings.currentKeyCode,
            modifiers: ShrimpHotKeySettings.currentModifiers,
            id: 5  // Use id=5 to distinguish from other hotkeys
        ) { [weak self] in
            self?.openInShrimpFromSelection()
        }
        shrimpHotKey?.start()

        // Update hotkey live when settings change
        Publishers.CombineLatest(shrimpHotKeySettings.$keyCode, shrimpHotKeySettings.$modifiersRaw)
            .dropFirst()  // Skip initial value emission
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newKeyCode, newModifiersRaw in
                guard let self else { return }
                self.shrimpHotKeySettings.save()
                // Convert raw modifiers to NSEvent.ModifierFlags
                var mods: NSEvent.ModifierFlags = []
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.control])) != 0 { mods.insert(.control) }
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.option])) != 0 { mods.insert(.option) }
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.command])) != 0 { mods.insert(.command) }
                if (newModifiersRaw & HotKeySettings.carbonModifiers(from: [.shift])) != 0 { mods.insert(.shift) }
                self.shrimpHotKey?.update(keyCode: newKeyCode, modifiers: mods)
            }
            .store(in: &cancellables)
    }

    // MARK: - Semantic Concept Validation

    /// Validates SNOMED CT concepts referenced in an ECL expression in the background.
    ///
    /// Extracts concept IDs from the expression using `ECLBridge`, then batch-looks
    /// them up via `OntoserverClient` to check for inactive or unknown concepts.
    /// If any problems are found, shows a transient warning HUD near the cursor.
    ///
    /// This method is fire-and-forget: it does not block the caller and silently
    /// handles any errors (network failures, etc.) without surfacing them.
    ///
    /// - Parameter text: The ECL expression text to validate
    private func validateConceptsInBackground(_ text: String) {
        let concepts = eclBridge.extractConceptIds(text)
        guard !concepts.isEmpty else { return }

        let conceptIds = concepts.map(\.id)
        AppLog.debug(AppLog.ui, "Validating \(conceptIds.count) concept(s) in background")

        Task { @MainActor in
            do {
                let batchResult = try await ontoserverClient.batchLookup(conceptIds: conceptIds)
                let warnings = Self.buildConceptWarnings(
                    conceptIds: conceptIds,
                    batchResult: batchResult
                )
                guard !warnings.isEmpty else { return }

                let message = warnings.count == 1
                    ? warnings[0]
                    : "\(warnings.count) concept warnings:\n" + warnings.joined(separator: "\n")

                AppLog.warning(AppLog.ui, "ECL concept validation: \(message)")
                progressHUD.showWarning(message: message, duration: 6)
            } catch {
                AppLog.debug(AppLog.ui, "Background concept validation failed: \(error)")
            }
        }
    }

    /// Validates SNOMED CT concepts referenced in an ECL expression and returns warning strings.
    ///
    /// Extracts concept IDs from the expression using the provided `ECLBridge`, then
    /// batch-looks them up via the provided `OntoserverClient` to check for inactive or
    /// unknown concepts.
    ///
    /// - Parameters:
    ///   - text: The ECL expression text to validate
    ///   - eclBridge: The ECL bridge to use for concept extraction
    ///   - client: The terminology server client to use for lookups
    /// - Returns: Array of warning strings (empty if no problems found)
    static func validateConcepts(
        in text: String,
        using eclBridge: ECLBridge,
        client: OntoserverClient
    ) async -> [String] {
        let concepts = eclBridge.extractConceptIds(text)
        guard !concepts.isEmpty else { return [] }

        let conceptIds = concepts.map(\.id)
        AppLog.debug(AppLog.ui, "Validating \(conceptIds.count) concept(s) for warnings")

        do {
            let batchResult = try await client.batchLookup(conceptIds: conceptIds)
            return buildConceptWarnings(conceptIds: conceptIds, batchResult: batchResult)
        } catch {
            AppLog.debug(AppLog.ui, "Concept validation failed: \(error)")
            return []
        }
    }

    /// Builds warning strings from batch lookup results by checking for inactive or unknown concepts.
    ///
    /// - Parameters:
    ///   - conceptIds: The concept IDs that were looked up
    ///   - batchResult: The batch lookup result from the terminology server
    /// - Returns: Array of warning strings for inactive or unknown concepts
    static func buildConceptWarnings(
        conceptIds: [String],
        batchResult: OntoserverClient.BatchLookupResult
    ) -> [String] {
        var warnings: [String] = []

        for conceptId in conceptIds {
            let pt = batchResult.pt(for: conceptId)
            let active = batchResult.isActive(for: conceptId)

            if pt == nil {
                // Concept not found on the server
                warnings.append("\(conceptId) is unknown")
            } else if active == false {
                // Concept exists but is inactive
                let name = pt ?? conceptId
                warnings.append("\(conceptId) |\(name)| is inactive")
            }
        }

        return warnings
    }

    /// Toggles the selected ECL expression between pretty-printed and minified formats.
    ///
    /// This method reads the current selection, attempts to parse it as an ECL
    /// expression, and if successful, replaces it with a toggled format:
    /// - If the selection is pretty-printed → replaces with minified
    /// - If the selection is minified or irregular → replaces with pretty-printed
    ///
    /// If the selection is not valid ECL, a system beep is played.
    /// If the expression has ambiguous operator precedence (e.g. mixed AND/OR without
    /// parentheses), the format still proceeds but a warning is shown in the HUD afterward.
    @objc private func formatECLSelection() {
        Task { @MainActor in
            do {
                let reader = SystemSelectionReader()

                // 1. Read selection
                let text = try reader.readSelectionByCopying()

                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    NSSound.beep()
                    AppLog.warning(AppLog.ui, "ECL format failed: empty selection")
                    return
                }

                // 2. Parse first to check for errors
                let parseResult = eclBridge.parseECL(text)
                if !parseResult.errors.isEmpty {
                    let error = parseResult.errors[0]
                    let location = error.column > 0 ? "Col \(error.column): " : ""
                    progressHUD.showError(message: "\(location)\(error.message)")
                    NSSound.beep()
                    AppLog.warning(AppLog.ui, "ECL format failed: \(error.message) (line \(error.line), col \(error.column))")
                    return
                }

                // 3. Capture any ambiguous-precedence warnings before formatting
                let precedenceWarnings = parseResult.warnings
                if !precedenceWarnings.isEmpty {
                    AppLog.info(AppLog.ui, "ECL parse warnings: \(precedenceWarnings)")
                }

                // 4. Toggle ECL format (pretty ↔ minified)
                guard let toggled = eclBridge.toggleECLFormat(text) else {
                    NSSound.beep()
                    AppLog.warning(AppLog.ui, "ECL format failed: could not format")
                    return
                }

                // 5. Put toggled text on clipboard
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(toggled, forType: .string)

                // 6. Small delay to ensure clipboard is ready
                try await Task.sleep(nanoseconds: 50_000_000)  // 50ms

                // 7. Paste and select the inserted text (use UTF-16 count for CFRange compatibility)
                if !reader.pasteAndSelect(textLength: toggled.utf16.count) {
                    throw LookupError.accessibilityPermissionLikelyMissing
                }

                let action = toggled.contains("\n") ? "Pretty-printed" : "Minified"
                AppLog.info(AppLog.ui, "\(action) ECL expression")

                // 8. Show ambiguous-precedence warning after format completes
                //    Displayed after paste so the HUD is not immediately replaced.
                if !precedenceWarnings.isEmpty {
                    progressHUD.showError(
                        message: "Mixed AND/OR \u{2014} consider adding parentheses",
                        duration: 4
                    )
                }

                // 9. Fire-and-forget: validate referenced concepts in the background
                //    Shows a warning HUD if any concepts are inactive or unknown.
                validateConceptsInBackground(text)

            } catch {
                NSSound.beep()
                AppLog.error(AppLog.ui, "ECL format failed: \(error)")
            }
        }
    }

    /// Opens the selected concept in the Shrimp terminology browser.
    ///
    /// This method reads the current selection, extracts a concept code,
    /// performs a lookup to get concept details, and opens the result in
    /// Evaluates the selected ECL expression and shows matching concepts in a panel.
    ///
    /// Reads the current selection, validates it as ECL using the bridge,
    /// then opens the evaluation panel which queries the terminology server
    /// for matching concepts.
    @objc private func evaluateECLSelection() {
        Task { @MainActor in
            do {
                let mouse = NSEvent.mouseLocation
                let reader = SystemSelectionReader()

                // Try to read selection — if empty, open the workbench with no expression
                var text = ""
                do {
                    text = try reader.readSelectionByCopying()
                } catch {
                    // No selection available — open empty editor
                    AppLog.debug(AppLog.ui, "No selection for ECL evaluate, opening empty editor")
                }

                let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                evaluatePanel.show(expression: trimmedText, at: mouse)
                AppLog.info(AppLog.ui, "ECL workbench opened\(trimmedText.isEmpty ? " (empty)" : "")")

            } catch {
                NSSound.beep()
                AppLog.error(AppLog.ui, "ECL evaluate failed: \(error)")
            }
        }
    }

    /// Shows the ECL operator quick reference panel.
    ///
    /// Displays a floating panel listing all ECL operators grouped by category
    /// with their symbols, names, and descriptions. The panel is positioned
    /// near the mouse cursor.
    @objc private func showECLReference() {
        eclReferencePanel.show(at: NSEvent.mouseLocation)
    }

    /// Opens the selected concept in the Shrimp terminology browser.
    ///
    /// This method reads the current selection, extracts a concept code,
    /// performs a lookup to get concept details, and opens the result in
    /// the Shrimp browser using the user's default web browser.
    ///
    /// If the selection doesn't contain a valid code or the lookup fails,
    /// a system beep is played.
    @objc private func openInShrimpFromSelection() {
        AppLog.debug(AppLog.ui, "openInShrimpFromSelection called")
        Task { @MainActor in
            do {
                let reader = SystemSelectionReader()

                // 1. Read selection
                let text = try reader.readSelectionByCopying()
                AppLog.debug(AppLog.ui, "Shrimp: read selection (\(text.count) chars): \(text)")

                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    NSSound.beep()
                    AppLog.warning(AppLog.ui, "Open in Shrimp failed: empty selection")
                    return
                }

                // 2. Look up and open in Shrimp
                AppLog.debug(AppLog.ui, "Shrimp: calling lookupAndOpenInShrimp")
                try await model.lookupAndOpenInShrimp(from: text)

                AppLog.info(AppLog.ui, "Opened concept in Shrimp from selection")

            } catch LookupError.notAConceptId {
                NSSound.beep()
                AppLog.warning(AppLog.ui, "Open in Shrimp failed: not a valid concept ID")
            } catch {
                NSSound.beep()
                AppLog.error(AppLog.ui, "Open in Shrimp failed: \(error)")
            }
        }
    }

    /// Toggles pipe-delimited terms for all concept IDs in the selection.
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
    /// For non-SNOMED codes (codes that fail Verhoeff validation), individual lookups
    /// are performed against configured code systems (LOINC, ICD-10, etc.).
    ///
    /// If no valid concept IDs are found, a system beep is played.
    ///
    /// ## Performance
    ///
    /// Uses `ValueSet/$expand` batch lookup for SNOMED CT codes to fetch all concept
    /// terms in a single API request (~0.5s for 62 codes).
    @objc private func replaceSelection() {
        Task { @MainActor in
            do {
                let reader = SystemSelectionReader()

                // 1. Read selection
                let text = try reader.readSelectionByCopying()

                // 2. Extract all concept IDs with their positions and existing terms
                let matches = model.extractAllConceptIds(from: text)

                guard !matches.isEmpty else {
                    NSSound.beep()
                    AppLog.warning(AppLog.ui, "Replace failed: no valid concept IDs in selection")
                    return
                }

                // 3. Separate SCTID and non-SCTID codes
                let sctidMatches = matches.filter { $0.isSCTID }
                let nonSctidMatches = matches.filter { !$0.isSCTID }

                let client = ontoserverClient
                let totalUniqueIds = Set(matches.map { $0.conceptId }).count

                // Show progress HUD for operations with multiple concepts
                let showProgress = totalUniqueIds > 3
                if showProgress {
                    progressHUD.show(message: "Looking up \(totalUniqueIds) concepts...")
                }

                // 4. Look up SNOMED CT codes using batch lookup
                var termsByCode: [String: String] = [:]
                var fsnByCode: [String: String] = [:]
                var activeByCode: [String: Bool] = [:]

                if !sctidMatches.isEmpty {
                    let sctidCodes = Array(Set(sctidMatches.map { $0.conceptId }))
                    let batchResult = try await client.batchLookup(conceptIds: sctidCodes)
                    termsByCode.merge(batchResult.ptByCode) { _, new in new }
                    fsnByCode.merge(batchResult.fsnByCode) { _, new in new }
                    activeByCode.merge(batchResult.activeByCode) { _, new in new }
                }

                // 5. Look up non-SNOMED codes individually through configured systems
                if !nonSctidMatches.isEmpty {
                    let nonSctidCodes = Array(Set(nonSctidMatches.map { $0.conceptId }))
                    let systems = CodeSystemSettings.shared.enabledSystems.map { $0.uri }

                    for code in nonSctidCodes {
                        if let result = try await client.lookupInConfiguredSystems(code: code, systems: systems) {
                            if let pt = result.pt {
                                termsByCode[code] = pt
                            }
                            // Non-SNOMED systems typically don't have FSN
                        }
                    }
                }

                // Hide progress HUD
                if showProgress {
                    progressHUD.hide()
                }

                let foundCount = termsByCode.count
                let notFoundCount = totalUniqueIds - foundCount
                if notFoundCount > 0 {
                    AppLog.warning(AppLog.ui, "Replace: \(notFoundCount) of \(totalUniqueIds) concepts not found")
                }

                // 6. Capture term format setting and define helper
                let termFormat = replaceSettings.termFormat
                let prefixInactive = replaceSettings.prefixInactive

                func expectedTerm(for match: LookupViewModel.ConceptMatch) -> String? {
                    var term: String?
                    if match.isSCTID {
                        // For SNOMED, respect FSN/PT preference
                        switch termFormat {
                        case .fsn:
                            term = fsnByCode[match.conceptId] ?? termsByCode[match.conceptId]
                        case .pt:
                            term = termsByCode[match.conceptId] ?? fsnByCode[match.conceptId]
                        }
                    } else {
                        // For non-SNOMED, just use the display term (no FSN/PT distinction)
                        term = termsByCode[match.conceptId]
                    }

                    // Add INACTIVE prefix if the concept is inactive and setting is enabled
                    if let term = term,
                       prefixInactive,
                       let isActive = activeByCode[match.conceptId],
                       !isActive {
                        return "INACTIVE - \(term)"
                    }

                    return term
                }

                // 7. Check if ALL matches already have correct terms (toggle to remove mode)
                let allCorrect = matches.allSatisfy { match in
                    guard let expected = expectedTerm(for: match),
                          let existing = match.existingTerm else {
                        return false
                    }
                    return existing == expected
                }

                // 8. Build replacement string
                var result = text
                for match in matches.reversed() {
                    let conceptId = match.conceptId
                    let replacement: String

                    if allCorrect {
                        // Remove mode: strip the pipe-delimited term
                        replacement = conceptId
                    } else {
                        // Add/update mode
                        if let term = expectedTerm(for: match) {
                            replacement = "\(conceptId) | \(term) |"
                        } else {
                            // Lookup failed - keep as-is (just the code, or code with existing term)
                            replacement = String(text[match.range])
                        }
                    }

                    result.replaceSubrange(match.range, with: replacement)
                }

                // 9. Put on clipboard
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(result, forType: .string)

                // 10. Small delay to ensure clipboard is ready
                try await Task.sleep(nanoseconds: 50_000_000)  // 50ms

                // 11. Paste and select the inserted text (use UTF-16 count for CFRange compatibility)
                if !reader.pasteAndSelect(textLength: result.utf16.count) {
                    throw LookupError.accessibilityPermissionLikelyMissing
                }

                let action = allCorrect ? "Removed terms from" : "Added/updated terms for"
                if notFoundCount > 0 {
                    AppLog.info(AppLog.ui, "\(action) \(matches.count) concept IDs (\(foundCount)/\(totalUniqueIds) found)")
                } else {
                    AppLog.info(AppLog.ui, "\(action) \(matches.count) concept IDs")
                }

            } catch {
                progressHUD.hide()
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

    /// Shows the welcome screen on first launch or upgrade.
    ///
    /// Checks `WelcomeSettings.hasShown` and presents the welcome window
    /// if the user has not previously seen it. The welcome screen runs
    /// after all hotkeys are registered, so the app is fully functional
    /// even if the user dismisses immediately.
    private func showWelcomeIfNeeded() {
        guard !WelcomeSettings.shared.hasShown else { return }
        WelcomeWindowController.show()
    }

    /// Terminates the application.
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
