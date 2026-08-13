import AppKit
import SwiftUI
@preconcurrency import Combine

public enum NotchExpansionState: Sendable, Equatable {
    case collapsed
    case hoverPeeking
    case expanded
}

public enum NotchDisplayMode: Sendable, Equatable {
    case single
    case duo
}

@MainActor
@Observable
public final class NotchPanelManager {
    public static let shared = NotchPanelManager()
    
    public var state: NotchExpansionState = .collapsed
    public var displayMode: NotchDisplayMode = .single
    public var metrics: NotchMetrics
    public var isFullscreenActive: Bool = false
    public var isPinnedOpen: Bool = false
    
    private var panel: AlcoveNotchPanel?
    private var screenChangeObserver: AnyCancellable?
    private var collapseDebounceTask: Task<Void, Never>?
    
    private init() {
        self.metrics = NotchGeometryProvider.shared.resolveMetrics()
        setupScreenChangeObserver()
        setupFullscreenObserver()
    }
    
    public func bootstrap(with rootView: some View) {
        if let existing = self.panel {
            existing.orderOut(nil)
            existing.close()
            self.panel = nil
        }
        
        let metrics = NotchGeometryProvider.shared.resolveMetrics()
        self.metrics = metrics
        
        let canvasRect = calculateCanvasFrame(metrics: metrics)
        let panel = AlcoveNotchPanel(contentRect: canvasRect)
        
        let hostingView = NSHostingView(
            rootView: rootView
                .environment(self)
        )
        panel.contentView = hostingView
        panel.setFrame(canvasRect, display: true)
        panel.orderFrontRegardless()
        
        self.panel = panel
    }
    
    public func handleHoverChange(_ isHovering: Bool) {
        if isHovering {
            collapseDebounceTask?.cancel()
            collapseDebounceTask = nil
            
            if state != .expanded {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
                    state = .expanded
                }
            }
        } else {
            guard !isPinnedOpen else { return }
            
            collapseDebounceTask?.cancel()
            collapseDebounceTask = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                guard let self = self else { return }
                if self.state == .expanded && !self.isPinnedOpen {
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.82)) {
                        self.state = .collapsed
                    }
                }
            }
        }
    }
    
    public func setExpansionState(_ newState: NotchExpansionState, animated: Bool = true) {
        guard self.state != newState else { return }
        if animated {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
                self.state = newState
            }
        } else {
            self.state = newState
        }
    }
    
    public func toggleDuoMode() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
            self.displayMode = (self.displayMode == .single) ? .duo : .single
        }
    }
    
    public func calculateCanvasFrame(metrics: NotchMetrics) -> NSRect {
        let width: CGFloat = 440.0
        let height: CGFloat = 135.0
        let topOffset: CGFloat = metrics.hasPhysicalNotch ? 0.0 : 8.0
        
        let x = floor(metrics.centerPoint.x - (width / 2.0))
        let y = metrics.centerPoint.y - height - topOffset
        
        return NSRect(x: x, y: y, width: width, height: height)
    }
    
    public func calculateWindowFrame(for state: NotchExpansionState, metrics: NotchMetrics) -> NSRect {
        let width: CGFloat
        let height: CGFloat
        let topOffset: CGFloat = metrics.hasPhysicalNotch ? 0.0 : 8.0
        
        switch state {
        case .collapsed:
            width = metrics.hasPhysicalNotch ? metrics.notchWidth : 179.0
            height = metrics.hasPhysicalNotch ? metrics.notchHeight : 32.0
        case .hoverPeeking:
            width = metrics.hasPhysicalNotch ? (metrics.notchWidth + 60.0) : 230.0
            height = metrics.hasPhysicalNotch ? (metrics.notchHeight + 14.0) : 46.0
        case .expanded:
            width = 380.0
            height = metrics.hasPhysicalNotch ? 112.0 : 100.0
        }
        
        let x = floor(metrics.centerPoint.x - (width / 2.0))
        let y = metrics.centerPoint.y - height - topOffset
        
        return NSRect(x: x, y: y, width: width, height: height)
    }
    
    private func setupScreenChangeObserver() {
        screenChangeObserver = NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.recalculateGeometry()
                }
            }
    }
    
    private func setupFullscreenObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkFullscreenState()
            }
        }
    }
    
    private func checkFullscreenState() {
        if let screen = NSScreen.main {
            let hasMenuBarHidden = screen.frame.height == screen.visibleFrame.height
            self.isFullscreenActive = hasMenuBarHidden && !metrics.hasPhysicalNotch
        }
    }
    
    public func recalculateGeometry() {
        self.metrics = NotchGeometryProvider.shared.resolveMetrics()
        guard let panel = self.panel else { return }
        let targetFrame = calculateCanvasFrame(metrics: metrics)
        panel.setFrame(targetFrame, display: true)
    }
}
