import AppKit
import CoreGraphics
import ApplicationServices

@MainActor
@Observable
public final class PermissionManager {
    public static let shared = PermissionManager()
    
    public private(set) var isAccessibilityGranted: Bool = false
    public private(set) var isScreenRecordingGranted: Bool = false
    
    private init() {
        refreshAll()
    }
    
    public func refreshAll() {
        self.isAccessibilityGranted = checkAccessibility(promptIfNeeded: false)
        self.isScreenRecordingGranted = checkScreenRecording()
    }
    
    @discardableResult
    public func checkAccessibility(promptIfNeeded: Bool = true) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt" as CFString: promptIfNeeded] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)
        self.isAccessibilityGranted = granted
        return granted
    }
    
    public func checkScreenRecording() -> Bool {
        let granted = CGPreflightScreenCaptureAccess()
        self.isScreenRecordingGranted = granted
        return granted
    }
    
    public func requestScreenRecordingAccess() {
        CGRequestScreenCaptureAccess()
        self.isScreenRecordingGranted = CGPreflightScreenCaptureAccess()
    }
}
