import AppKit
import SwiftUI

@MainActor
public final class AlcoveNotchPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [
                .nonactivatingPanel,
                .borderless,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)))
        self.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.isReleasedWhenClosed = false
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovable = false
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = true
        self.acceptsMouseMovedEvents = true
        self.ignoresMouseEvents = false
    }
    
    public override var canBecomeKey: Bool {
        return true
    }
    
    public override var canBecomeMain: Bool {
        return false
    }
    
    public override func cancelOperation(_ sender: Any?) {
        // Pressing Escape closes the expanded panel
        NotchPanelManager.shared.setExpansionState(.collapsed)
    }
    
    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // 53 = Escape
            NotchPanelManager.shared.setExpansionState(.collapsed)
            return
        }
        super.keyDown(with: event)
    }
}
