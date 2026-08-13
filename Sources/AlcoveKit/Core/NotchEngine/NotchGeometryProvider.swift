import AppKit
import Foundation

public struct NotchMetrics: Sendable, Equatable {
    public let screenFrame: CGRect
    public let hasPhysicalNotch: Bool
    public let notchWidth: CGFloat
    public let notchHeight: CGFloat
    public let topInset: CGFloat
    public let centerPoint: CGPoint
    
    public static let standardNotchWidth: CGFloat = 208.0
    public static let standardNotchHeight: CGFloat = 32.0
    
    public init(
        screenFrame: CGRect,
        hasPhysicalNotch: Bool,
        notchWidth: CGFloat,
        notchHeight: CGFloat,
        topInset: CGFloat,
        centerPoint: CGPoint
    ) {
        self.screenFrame = screenFrame
        self.hasPhysicalNotch = hasPhysicalNotch
        self.notchWidth = notchWidth
        self.notchHeight = notchHeight
        self.topInset = topInset
        self.centerPoint = centerPoint
    }
}

@MainActor
public final class NotchGeometryProvider: Sendable {
    public static let shared = NotchGeometryProvider()
    
    private init() {}
    
    public func resolveMetrics(for screen: NSScreen? = nil) -> NotchMetrics {
        let targetScreen = screen ?? NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        let frame = targetScreen.frame
        let safeArea = targetScreen.safeAreaInsets
        let topInset = safeArea.top
        let hasNotch = topInset > 0
        
        var notchWidth: CGFloat = 180.0
        var notchHeight: CGFloat = NotchMetrics.standardNotchHeight
        
        if hasNotch {
            notchHeight = topInset
            if let left = targetScreen.auxiliaryTopLeftArea, let right = targetScreen.auxiliaryTopRightArea {
                let physicalWidth = frame.width - (left.width + right.width)
                if physicalWidth > 80 && physicalWidth < 400 {
                    notchWidth = physicalWidth
                } else {
                    notchWidth = NotchMetrics.standardNotchWidth
                }
            } else {
                notchWidth = NotchMetrics.standardNotchWidth
            }
        }
        
        let centerX = frame.midX
        let topY = frame.maxY
        
        return NotchMetrics(
            screenFrame: frame,
            hasPhysicalNotch: hasNotch,
            notchWidth: notchWidth,
            notchHeight: notchHeight,
            topInset: topInset,
            centerPoint: CGPoint(x: centerX, y: topY)
        )
    }
}
