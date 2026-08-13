import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var isBootstrapped: Bool = false

    public func applicationDidFinishLaunching(_ notification: Notification) {
        guard !isBootstrapped else { return }
        isBootstrapped = true
        
        // Run as accessory/menu bar utility without dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Setup status bar item in macOS menu bar
        setupStatusItem()
        
        // Refresh permissions
        PermissionManager.shared.refreshAll()
        
        // Bootstrap notch window panel on next runloop turn
        DispatchQueue.main.async {
            NotchPanelManager.shared.bootstrap(with: NotchContainerView())
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Yas Island")
        }
        let menu = NSMenu()
        
        let toggleItem = NSMenuItem(title: "Toggle Yas Island Notch", action: #selector(toggleNotch), keyEquivalent: "o")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        let duoItem = NSMenuItem(title: "Toggle Duo Mode (Split Island)", action: #selector(toggleDuo), keyEquivalent: "d")
        duoItem.target = self
        menu.addItem(duoItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let realignItem = NSMenuItem(title: "Recalculate Notch Alignment", action: #selector(realign), keyEquivalent: "r")
        realignItem.target = self
        menu.addItem(realignItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Yas Island", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        item.menu = menu
        self.statusItem = item
    }

    @objc private func toggleNotch() {
        let current = NotchPanelManager.shared.state
        NotchPanelManager.shared.setExpansionState(current == .expanded ? .collapsed : .expanded)
    }

    @objc private func toggleDuo() {
        NotchPanelManager.shared.toggleDuoMode()
    }

    @objc private func realign() {
        NotchPanelManager.shared.recalculateGeometry()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotchPanelManager.shared.setExpansionState(.expanded)
        return true
    }
}
