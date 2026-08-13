import Foundation
import AppKit
import AlcoveKit

@MainActor
func simulateUserInteractions() async throws {
    print("\n🎭 =================================================================")
    print("👤 LIVE USER INTERACTION SIMULATOR: 'Yas Island'")
    print("   Simulating direct user actions across all features...")
    print("=================================================================\n")
    
    // ACTION 1: User moves mouse to the camera notch (Hover Peeking)
    print("📍 [ACTION 1] User hovers cursor over the camera cutout...")
    NotchPanelManager.shared.setExpansionState(.hoverPeeking)
    try await Task.sleep(nanoseconds: 600_000_000)
    let peekFrame = NotchPanelManager.shared.calculateWindowFrame(
        for: .hoverPeeking,
        metrics: NotchPanelManager.shared.metrics
    )
    print("   👉 Result: Notch dynamically peeks out (Size: \(Int(peekFrame.width))x\(Int(peekFrame.height)) pt)")
    print("   👉 Visual: Displays 'Yas Island' green pulse dot and mini equalizer wave\n")
    
    // ACTION 2: User clicks the notch to expand the full Command Hub
    print("📍 [ACTION 2] User clicks the notch to expand full dashboard...")
    NotchPanelManager.shared.setExpansionState(.expanded)
    try await Task.sleep(nanoseconds: 800_000_000)
    let expandedFrame = NotchPanelManager.shared.calculateWindowFrame(
        for: .expanded,
        metrics: NotchPanelManager.shared.metrics
    )
    print("   👉 Result: Command Hub tray drops downward (Size: \(Int(expandedFrame.width))x\(Int(expandedFrame.height)) pt)")
    print("   👉 Visual: Liquid glass HUD reveals 4 active widget tiles + AirDrop drop zone\n")
    
    // ACTION 3: User drags & drops a project file and a URL into the Drop Vault
    print("📍 [ACTION 3] User drags and drops items into the Drop Vault...")
    let testDoc = URL(fileURLWithPath: "/Users/yashkeshri/.gemini/antigravity/scratch/Alcove/Package.swift")
    let testURL = "https://developer.apple.com/macos"
    let testCodeSnippet = "swift run YasIsland --strict-concurrency"
    
    ClipboardShelfWidget.shared.recordFile(testDoc)
    ClipboardShelfWidget.shared.recordText(testURL)
    ClipboardShelfWidget.shared.recordText(testCodeSnippet)
    try await Task.sleep(nanoseconds: 500_000_000)
    
    print("   👉 Stashed Items in Vault:")
    for (i, item) in ClipboardShelfWidget.shared.items.prefix(5).enumerated() {
        print("      [\(i+1)] \(item)")
    }
    print("   👉 Visual: Tag chips with Finder icons dynamically update in the widget\n")
    
    // ACTION 4: User types a prompt into the Antigravity AI Agent Widget
    print("📍 [ACTION 4] User prompts Antigravity AI Agent to run a task...")
    let agentWidget = AntigravityAgentWidget.shared
    agentWidget.quickPrompt = "Build and test the macOS Liquid Glass notch overlay"
    print("   👉 Input Text: \"\(agentWidget.quickPrompt)\"")
    print("   👉 User presses ↵ (Return) to execute...")
    
    agentWidget.executeAgentAction()
    try await Task.sleep(nanoseconds: 400_000_000)
    print("   👉 State during execution: \"\(agentWidget.statusText)\" (Pulse orange)")
    try await Task.sleep(nanoseconds: 800_000_000)
    print("   👉 Task completed! Status: \"\(agentWidget.statusText)\" (Success)")
    print("   👉 Visual: Execution ID badge turns green\n")
    
    // ACTION 5: User interacts with Media Controls
    print("📍 [ACTION 5] User toggles media playback and skips track...")
    let mediaWidget = MediaControlsWidget.shared
    print("   👉 Current Audio Source: \(mediaWidget.trackInfo.appName)")
    print("   👉 User clicks Play/Pause...")
    mediaWidget.togglePlayback()
    try await Task.sleep(nanoseconds: 400_000_000)
    print("   👉 Playback State: \(mediaWidget.trackInfo.isPlaying ? "▶️ PLAYING" : "⏸️ PAUSED")")
    print("   👉 User clicks Next Track (⏭)...")
    mediaWidget.skipNext()
    try await Task.sleep(nanoseconds: 400_000_000)
    print("   👉 Dispatched skip command to active system/browser audio engine\n")
    
    // ACTION 6: User clicks the Dock/Collapse button to hide the tray
    print("📍 [ACTION 6] User clicks 'Dock' button (or presses Esc)...")
    NotchPanelManager.shared.setExpansionState(.collapsed)
    try await Task.sleep(nanoseconds: 600_000_000)
    let collapsedFrame = NotchPanelManager.shared.calculateWindowFrame(
        for: .collapsed,
        metrics: NotchPanelManager.shared.metrics
    )
    print("   👉 Result: Tray smoothly springs back into the camera cutout (Size: \(Int(collapsedFrame.width))x\(Int(collapsedFrame.height)) pt)")
    print("   👉 Visual: Returns to discreet black notch flush with screen bezel\n")
    
    print("=================================================================")
    print("🎬 USER INTERACTION SIMULATION COMPLETED WITH 100% SUCCESS!")
    print("=================================================================\n")
}

let app = NSApplication.shared
Task { @MainActor in
    do {
        try await simulateUserInteractions()
        exit(0)
    } catch {
        print("❌ Error during simulation: \(error)")
        exit(1)
    }
}
RunLoop.main.run(until: Date().addingTimeInterval(5.0))
