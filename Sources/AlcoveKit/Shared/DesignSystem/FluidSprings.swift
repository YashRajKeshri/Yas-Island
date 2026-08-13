import SwiftUI

public enum AlcoveSprings {
    // Apple Dynamic Island fluid morphing spring curve
    public static let notchMorph = Animation.spring(
        response: 0.30,
        dampingFraction: 0.82,
        blendDuration: 0.0
    )
    
    public static let contentReveal = Animation.easeInOut(duration: 0.18)
    
    public static let interactiveFluid = Animation.spring(
        response: 0.28,
        dampingFraction: 0.84,
        blendDuration: 0.0
    )
    
    public static let snappyMorph = Animation.spring(
        response: 0.20,
        dampingFraction: 0.78,
        blendDuration: 0.0
    )
    
    public static let pillBreathe = Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: true)
}
