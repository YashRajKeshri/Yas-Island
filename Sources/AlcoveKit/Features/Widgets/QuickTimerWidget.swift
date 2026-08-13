import SwiftUI
import AppKit

@MainActor
@Observable
public final class QuickTimerWidget {
    public static let shared = QuickTimerWidget()
    
    public var totalSeconds: Int = 25 * 60 // 25 min default
    public var remainingSeconds: Int = 25 * 60
    public var isRunning: Bool = false
    
    private var timerTask: Task<Void, Never>?
    
    private init() {}
    
    public var progress: Double {
        guard totalSeconds > 0 else { return 0.0 }
        return 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
    }
    
    public var formattedRemainingTime: String {
        let mins = remainingSeconds / 60
        let secs = remainingSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    public func setPreset(minutes: Int) {
        pause()
        self.totalSeconds = minutes * 60
        self.remainingSeconds = minutes * 60
    }
    
    public func toggle() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }
    
    public func start() {
        guard remainingSeconds > 0 else { return }
        isRunning = true
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            while self?.isRunning == true && (self?.remainingSeconds ?? 0) > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self = self, self.isRunning else { break }
                self.remainingSeconds -= 1
                if self.remainingSeconds <= 0 {
                    self.isRunning = false
                    self.playChime()
                }
            }
        }
    }
    
    public func pause() {
        isRunning = false
        timerTask?.cancel()
        timerTask = nil
    }
    
    public func reset() {
        pause()
        remainingSeconds = totalSeconds
    }
    
    private func playChime() {
        NSSound(named: "Glass")?.play()
    }
}

public struct QuickTimerView: View {
    @State private var timerModel = QuickTimerWidget.shared
    
    public var body: some View {
        HStack(spacing: 14) {
            // Circular Timer Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: timerModel.progress)
                    .stroke(
                        LinearGradient(
                            colors: [AlcoveTheme.accentOrange, AlcoveTheme.accentPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: timerModel.progress)
                
                VStack(spacing: 0) {
                    Text(timerModel.formattedRemainingTime)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white)
                    
                    Text(timerModel.isRunning ? "Running" : "Paused")
                        .font(.system(size: 7.5, weight: .medium))
                        .foregroundStyle(timerModel.isRunning ? AlcoveTheme.accentOrange : Color.white.opacity(0.40))
                }
            }
            .frame(width: 54, height: 54)
            
            VStack(alignment: .leading, spacing: 4) {
                // Preset Buttons
                HStack(spacing: 4) {
                    ForEach([1, 5, 15, 25], id: \.self) { mins in
                        Button {
                            timerModel.setPreset(minutes: mins)
                        } label: {
                            Text("\(mins)m")
                                .font(.system(size: 9, weight: timerModel.totalSeconds == mins * 60 ? .bold : .medium, design: .rounded))
                                .foregroundStyle(timerModel.totalSeconds == mins * 60 ? .white : Color.white.opacity(0.50))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(
                                    Capsule().fill(timerModel.totalSeconds == mins * 60 ? AlcoveTheme.accentOrange.opacity(0.35) : Color.white.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Controls
                HStack(spacing: 8) {
                    Button {
                        timerModel.toggle()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: timerModel.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 8))
                            Text(timerModel.isRunning ? "Pause" : "Start")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(timerModel.isRunning ? Color.orange : AlcoveTheme.accentOrange))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        timerModel.reset()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 8))
                            Text("Reset")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(Color.white.opacity(0.60))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
