import SwiftUI
import AppKit

public enum AlcoveTheme {
    // True OLED Deep Glass Palette
    public static let notchHardwareBlack = Color.black
    public static let panelBackground = Color(nsColor: NSColor(calibratedRed: 0.04, green: 0.04, blue: 0.05, alpha: 0.94))
    public static let cardBackground = Color.white.opacity(0.06)
    public static let cardHoverBackground = Color.white.opacity(0.11)
    public static let cardSelectedBackground = Color.white.opacity(0.16)
    
    // Specular Rim Lighting & Bevels
    public static let specularRim = LinearGradient(
        colors: [
            Color.white.opacity(0.24),
            Color.white.opacity(0.08),
            Color.white.opacity(0.02),
            Color.white.opacity(0.06)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    public static let cardBorder = LinearGradient(
        colors: [
            Color.white.opacity(0.14),
            Color.white.opacity(0.04)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    public static let neonAIGlow = LinearGradient(
        colors: [
            Color(nsColor: .systemPurple),
            Color(nsColor: .systemIndigo),
            Color(nsColor: .systemCyan)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    // Typography Colors
    public static let textPrimary = Color.white
    public static let textSecondary = Color.white.opacity(0.72)
    public static let textTertiary = Color.white.opacity(0.45)
    public static let textQuaternary = Color.white.opacity(0.22)
    
    // Accents
    public static let accentBlue = Color(nsColor: .systemBlue)
    public static let accentTeal = Color(nsColor: .systemTeal)
    public static let accentGreen = Color(nsColor: .systemGreen)
    public static let accentPurple = Color(nsColor: .systemPurple)
    public static let accentPink = Color(nsColor: .systemPink)
    public static let accentOrange = Color(nsColor: .systemOrange)
}

public enum AlcoveMetrics {
    public static let cornerRadiusExpanded: CGFloat = 28.0
    public static let cornerRadiusHover: CGFloat = 16.0
    public static let cornerRadiusCollapsed: CGFloat = 11.0
    public static let cardCornerRadius: CGFloat = 16.0
    public static let pillCornerRadius: CGFloat = 12.0
}

public struct VisualEffectBlur: NSViewRepresentable {
    public var material: NSVisualEffectView.Material = .hudWindow
    public var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    public var state: NSVisualEffectView.State = .active
    
    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }
    
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = true
        return view
    }
    
    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}
