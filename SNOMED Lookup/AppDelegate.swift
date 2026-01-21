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
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// The menu bar status item displaying the app icon.
    private var statusItem: NSStatusItem!

    /// The popover that displays lookup results.
    private var popover = NSPopover()

    /// The view model that coordinates lookups and holds results.
    private let model = LookupViewModel()

    /// Shared settings for the global hotkey configuration.
    private let hotKeySettings = HotKeySettings.shared

    /// The currently registered global hotkey handler.
    private var hotKey: GlobalHotKey?

    /// Active Combine subscriptions for settings observation.
    private var cancellables = Set<AnyCancellable>()

    /// Invisible window used to anchor the popover near the cursor.
    private let cursorAnchor = CursorAnchorWindow()

    /// Called when the application finishes launching.
    ///
    /// Sets up the menu bar, popover, and global hotkey.
    func applicationDidFinishLaunching(_ notification: Notification) {
        enforceSingleInstance()

        setupMenuBar()
        setupPopover()
        setupHotKey()
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

        // Close the cursor anchor window when the popover closes
        NotificationCenter.default.addObserver(
            forName: NSPopover.didCloseNotification,
            object: popover,
            queue: .main
        ) { [weak self] _ in
            self?.cursorAnchor.close()
        }
    }

    /// Registers the global hotkey and sets up observation for settings changes.
    ///
    /// The hotkey is initially registered with the current settings values.
    /// A Combine subscription updates the hotkey whenever settings change,
    /// allowing live updates without app restart.
    private func setupHotKey() {
        // Initial registration with current settings
        hotKey = GlobalHotKey(
            keyCode: hotKeySettings.keyCode,
            modifiers: hotKeySettings.modifiers
        ) { [weak self] in
            self?.lookupSelection()
        }
        hotKey?.start()

        // Update hotkey live when settings change
        Publishers.CombineLatest(hotKeySettings.$keyCode, hotKeySettings.$modifiersRaw)
            .dropFirst()  // Skip initial value emission
            .sink { [weak self] _, _ in
                guard let self else { return }
                self.hotKeySettings.save()
                self.hotKey?.update(
                    keyCode: self.hotKeySettings.keyCode,
                    modifiers: self.hotKeySettings.modifiers
                )
            }
            .store(in: &cancellables)
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

        Task { @MainActor in
            await model.lookupFromSystemSelection()

            if !popover.isShown {
                cursorAnchor.showPopover(popover, at: mouse, preferredEdge: .maxY)
            }
        }
    }

    /// Terminates the application.
    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
