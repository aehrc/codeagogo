import Cocoa
import SwiftUI
import Combine
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover = NSPopover()

    private let model = LookupViewModel()
    private let hotKeySettings = HotKeySettings.shared

    private var hotKey: GlobalHotKey?
    private var cancellables = Set<AnyCancellable>()

    private let cursorAnchor = CursorAnchorWindow()

    func applicationDidFinishLaunching(_ notification: Notification) {
        enforceSingleInstance()

        setupMenuBar()
        setupPopover()
        setupHotKey()
    }

    /// For menu bar apps: if the user clicks the Dock icon, don't try to "reopen" windows.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // You could optionally show the popover here, but returning true is the "do nothing" behaviour.
        // For example:
        // if let button = statusItem?.button { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
        return true
    }

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
        // Note: if you set a menu, clicking opens menu not popover. We'll rely on hotkey + menu item.
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 520, height: 220)
        popover.contentViewController = NSHostingController(
            rootView: PopoverView().environmentObject(model)
        )

        NotificationCenter.default.addObserver(
            forName: NSPopover.didCloseNotification,
            object: popover,
            queue: .main
        ) { [weak self] _ in
            self?.cursorAnchor.close()
        }
    }

    private func setupHotKey() {
        // initial register
        hotKey = GlobalHotKey(
            keyCode: hotKeySettings.keyCode,
            modifiers: hotKeySettings.modifiers
        ) { [weak self] in
            self?.lookupSelection()
        }
        hotKey?.start()

        // update live when settings change
        Publishers.CombineLatest(hotKeySettings.$keyCode, hotKeySettings.$modifiersRaw)
            .dropFirst()
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

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    @objc private func lookupSelection() {
        let mouse = NSEvent.mouseLocation

        Task { @MainActor in
            await model.lookupFromSystemSelection()

            if !popover.isShown {
                cursorAnchor.showPopover(popover, at: mouse, preferredEdge: .maxY)
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
