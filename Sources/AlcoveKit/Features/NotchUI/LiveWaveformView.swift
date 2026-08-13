import SwiftUI

public struct LiveWaveformView: View {
    public let isPlaying: Bool
    public let barCount: Int
    public let height: CGFloat
    public let color: Color
    
    @State private var barHeights: [CGFloat]
    @State private var timerTask: Task<Void, Never>?
    
    public init(
        isPlaying: Bool = true,
        barCount: Int = 5,
        height: CGFloat = 14,
        color: Color = AlcoveTheme.accentGreen
    ) {
        self.isPlaying = isPlaying
        self.barCount = barCount
        self.height = height
        self.color = color
        self._barHeights = State(initialValue: Array(repeating: 0.3, count: barCount))
    }
    
    public var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: gradientColors(for: index),
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(
                        width: 2.5,
                        height: max(3.0, (index < barHeights.count ? barHeights[index] : 0.3) * height)
                    )
                    .animation(
                        .easeInOut(duration: isPlaying ? Double.random(in: 0.15...0.30) : 0.6),
                        value: index < barHeights.count ? barHeights[index] : 0.3
                    )
            }
        }
        .frame(height: height, alignment: .center)
        .onAppear { startAnimation() }
        .onDisappear { stopAnimation() }
        .onChange(of: isPlaying) { _, playing in
            if playing {
                startAnimation()
            } else {
                setToIdle()
            }
        }
    }
    
    private func gradientColors(for index: Int) -> [Color] {
        if !isPlaying {
            return [Color.white.opacity(0.3), Color.white.opacity(0.5)]
        }
        switch index % 4 {
        case 0: return [AlcoveTheme.accentGreen, AlcoveTheme.accentTeal]
        case 1: return [AlcoveTheme.accentPurple, AlcoveTheme.accentPink]
        case 2: return [AlcoveTheme.accentBlue, AlcoveTheme.accentCyan]
        default: return [AlcoveTheme.accentPink, AlcoveTheme.accentOrange]
        }
    }
    
    private func startAnimation() {
        stopAnimation()
        guard isPlaying else {
            setToIdle()
            return
        }
        
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                var newHeights: [CGFloat] = []
                for _ in 0..<barCount {
                    newHeights.append(CGFloat.random(in: 0.25...1.0))
                }
                self.barHeights = newHeights
                try? await Task.sleep(nanoseconds: 140_000_000) // 140ms refresh for silky ProMotion bounce
            }
        }
    }
    
    private func stopAnimation() {
        timerTask?.cancel()
        timerTask = nil
    }
    
    private func setToIdle() {
        barHeights = [0.2, 0.4, 0.6, 0.3, 0.2].prefix(barCount).map { CGFloat($0) }
    }
}

extension AlcoveTheme {
    public static let accentCyan = Color(nsColor: .systemCyan)
}
