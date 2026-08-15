import SwiftUI
import AppKit

public enum DuoRightPaneTab: Int, CaseIterable, Identifiable {
    case timer = 0
    case status = 1
    case vault = 2
    
    public var id: Int { rawValue }
    
    public var title: String {
        switch self {
        case .timer: return "Timer"
        case .status: return "Status"
        case .vault: return "Vault"
        }
    }
    
    public var icon: String {
        switch self {
        case .timer: return "timer"
        case .status: return "battery.100.bolt"
        case .vault: return "tray.fill"
        }
    }
}

public struct ExpandedDashboardView: View {
    @Environment(NotchPanelManager.self) private var manager
    @State private var mediaModel = MediaControlsWidget.shared
    @State private var audioManager = AudioOutputManager.shared
    @State private var timerModel = QuickTimerWidget.shared
    @State private var statusModel = SystemStatusWidget.shared
    @State private var duoTab: DuoRightPaneTab = .timer
    
    public init() {}
    
    public var body: some View {
        Group {
            if manager.displayMode == .duo || timerModel.isRunning {
                // ENHANCED SPLIT SCREEN (DUO) MODE
                HStack(spacing: 12) {
                    // LEFT PANE: Compact Media Player
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            ArtworkThumbnail(
                                data: mediaModel.trackInfo.artworkData,
                                isPlaying: mediaModel.trackInfo.isPlaying,
                                size: 32
                            )
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(mediaModel.trackInfo.title.isEmpty ? "Not Playing" : mediaModel.trackInfo.title)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.white)
                                    .lineLimit(1)
                                
                                Text(mediaModel.trackInfo.artist.isEmpty ? "Unknown" : mediaModel.trackInfo.artist)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.55))
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                            if mediaModel.trackInfo.isPlaying {
                                LiveWaveformView(isPlaying: true, barCount: 3, height: 9)
                            }
                        }
                        
                        // Mini Interactive Scrubber
                        InteractiveScrubberBar(mediaModel: mediaModel, height: 2.5, isMini: true)
                        
                        // Controls Row
                        HStack(spacing: 12) {
                            Button { mediaModel.skipPrevious() } label: {
                                Image(systemName: "backward.fill").font(.system(size: 10)).foregroundStyle(Color.white.opacity(0.85))
                            }.buttonStyle(.plain)
                            
                            Button { mediaModel.togglePlayback() } label: {
                                Image(systemName: mediaModel.trackInfo.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }.buttonStyle(.plain)
                            
                            Button { mediaModel.skipNext() } label: {
                                Image(systemName: "forward.fill").font(.system(size: 10)).foregroundStyle(Color.white.opacity(0.85))
                            }.buttonStyle(.plain)
                            
                            Spacer()
                            
                            // Audio Output
                            Menu {
                                Text("AUDIO OUTPUT")
                                Divider()
                                ForEach(audioManager.devices) { dev in
                                    Button { audioManager.selectOutputDevice(dev) } label: {
                                        HStack {
                                            Image(systemName: dev.icon)
                                            Text(dev.name)
                                            if dev.isDefault { Image(systemName: "checkmark") }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: audioManager.currentDevice?.icon ?? "airpodspro")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.white.opacity(0.60))
                            }
                            .menuStyle(.borderlessButton)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // VERTICAL SEPARATOR
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1)
                        .padding(.vertical, 2)
                    
                    // RIGHT PANE: Live Activity Pane (Timer / System Status / Drop Vault)
                    VStack(alignment: .leading, spacing: 4) {
                        // Micro Tab Switcher
                        HStack(spacing: 4) {
                            ForEach(DuoRightPaneTab.allCases) { tab in
                                Button {
                                    withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                                        duoTab = tab
                                    }
                                } label: {
                                    HStack(spacing: 2.5) {
                                        Image(systemName: tab.icon)
                                            .font(.system(size: 7.5))
                                        Text(tab.title)
                                            .font(.system(size: 8, weight: duoTab == tab ? .bold : .medium, design: .rounded))
                                    }
                                    .foregroundStyle(duoTab == tab ? Color.white : Color.white.opacity(0.40))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule().fill(duoTab == tab ? Color.white.opacity(0.14) : Color.clear)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Spacer()
                            
                            // Toggle Split / Single Mode Button
                            Button {
                                manager.toggleDuoMode()
                            } label: {
                                Image(systemName: "rectangle.split.2x1.fill")
                                    .font(.system(size: 8))
                                    .foregroundStyle(AlcoveTheme.accentTeal)
                            }
                            .buttonStyle(.plain)
                            .help("Toggle Split Screen Mode")
                        }
                        
                        // Tab Content
                        Group {
                            switch duoTab {
                            case .timer:
                                // Compact Pomodoro Ring + Controls
                                HStack(spacing: 8) {
                                    ZStack {
                                        Circle().stroke(Color.white.opacity(0.12), lineWidth: 3)
                                        Circle()
                                            .trim(from: 0, to: timerModel.progress)
                                            .stroke(
                                                LinearGradient(colors: [AlcoveTheme.accentOrange, AlcoveTheme.accentPink], startPoint: .topLeading, endPoint: .bottomTrailing),
                                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                            )
                                            .rotationEffect(.degrees(-90))
                                        Text(timerModel.formattedRemainingTime)
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundStyle(Color.white)
                                    }
                                    .frame(width: 38, height: 38)
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 3) {
                                            ForEach([5, 15, 25], id: \.self) { m in
                                                Button { timerModel.setPreset(minutes: m) } label: {
                                                    Text("\(m)m")
                                                        .font(.system(size: 7.5, weight: .medium))
                                                        .foregroundStyle(timerModel.totalSeconds == m * 60 ? .white : Color.white.opacity(0.5))
                                                        .padding(.horizontal, 4)
                                                        .padding(.vertical, 1.5)
                                                        .background(Capsule().fill(timerModel.totalSeconds == m * 60 ? AlcoveTheme.accentOrange.opacity(0.35) : Color.white.opacity(0.06)))
                                                }.buttonStyle(.plain)
                                            }
                                        }
                                        
                                        HStack(spacing: 6) {
                                            Button { timerModel.toggle() } label: {
                                                Text(timerModel.isRunning ? "Pause" : "Start")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Capsule().fill(AlcoveTheme.accentOrange))
                                            }.buttonStyle(.plain)
                                            
                                            Button { timerModel.reset() } label: {
                                                Image(systemName: "arrow.counterclockwise")
                                                    .font(.system(size: 7.5))
                                                    .foregroundStyle(Color.white.opacity(0.6))
                                            }.buttonStyle(.plain)
                                        }
                                    }
                                }
                                
                            case .status:
                                // Activity Rings & Battery
                                HStack(spacing: 6) {
                                    ActivityRingCard(
                                        title: "CPU",
                                        value: "\(Int(statusModel.telemetry.cpuUsage * 100))%",
                                        fraction: statusModel.telemetry.cpuUsage,
                                        color: AlcoveTheme.accentTeal,
                                        icon: "cpu"
                                    )
                                    ActivityRingCard(
                                        title: "BAT",
                                        value: "\(statusModel.telemetry.batteryPercent)%",
                                        fraction: Double(statusModel.telemetry.batteryPercent) / 100.0,
                                        color: AlcoveTheme.accentGreen,
                                        icon: statusModel.telemetry.isCharging ? "bolt.fill" : "battery.100"
                                    )
                                }
                                
                            case .vault:
                                DropShelfTargetView()
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 4)
                
            } else {
                // SINGLE MEDIA PLAYER VIEW
                VStack(spacing: 7) {
                    // TOP ROW: Artwork + Track Info + Split Toggle + Live Equalizer Waveform
                    HStack(alignment: .center, spacing: 10) {
                        ArtworkThumbnail(
                            data: mediaModel.trackInfo.artworkData,
                            isPlaying: mediaModel.trackInfo.isPlaying,
                            size: 34
                        )
                        
                        VStack(alignment: .leading, spacing: 1.5) {
                            Text(mediaModel.trackInfo.title.isEmpty ? "Not Playing" : mediaModel.trackInfo.title)
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white)
                                .lineLimit(1)
                            
                            Text(mediaModel.trackInfo.artist.isEmpty ? "Unknown Artist" : mediaModel.trackInfo.artist)
                                .font(.system(size: 9.5, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.55))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Split Mode Toggle Button
                        Button {
                            manager.toggleDuoMode()
                        } label: {
                            Image(systemName: "rectangle.split.2x1")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.white.opacity(0.40))
                        }
                        .buttonStyle(.plain)
                        .help("Enter Split Screen Mode")
                        
                        // Live Waveform
                        if mediaModel.trackInfo.isPlaying {
                            LiveWaveformView(isPlaying: true, barCount: 4, height: 11)
                                .padding(.trailing, 2)
                        } else {
                            Image(systemName: "waveform")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white.opacity(0.35))
                                .padding(.trailing, 2)
                        }
                    }
                    .padding(.horizontal, 4)
                    
                    // MIDDLE ROW: Elapsed Time + Interactive Scrubber + Remaining/Total Time
                    HStack(spacing: 7) {
                        Text(formatTime(mediaModel.trackInfo.elapsedTime))
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.45))
                        
                        // Interactive Progress Scrubber Bar
                        InteractiveScrubberBar(mediaModel: mediaModel, height: 3.0, isMini: false)
                        
                        Text(formattedRemainingOrDuration)
                            .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.45))
                    }
                    .padding(.horizontal, 4)
                    
                    // BOTTOM ROW: Centered Playback Controls + Audio Output Destination Icon
                    ZStack {
                        // Centered Controls: Backward, Play/Pause, Forward
                        HStack(spacing: 24) {
                            Button {
                                mediaModel.skipPrevious()
                            } label: {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.white.opacity(0.90))
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                mediaModel.togglePlayback()
                            } label: {
                                Image(systemName: mediaModel.trackInfo.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color.white)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                mediaModel.skipNext()
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.white.opacity(0.90))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Far Right: Audio Output Switcher Icon (AirPods / AirPlay Menu)
                        HStack {
                            Spacer()
                            Menu {
                                Text("AUDIO OUTPUT")
                                Divider()
                                ForEach(audioManager.devices) { dev in
                                    Button {
                                        audioManager.selectOutputDevice(dev)
                                    } label: {
                                        HStack {
                                            Image(systemName: dev.icon)
                                            Text(dev.name)
                                            if dev.isDefault {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: audioManager.currentDevice?.icon ?? "airpodspro")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(Color.white.opacity(0.65))
                            }
                            .menuStyle(.borderlessButton)
                            .padding(.trailing, 4)
                        }
                    }
                    .padding(.top, 1)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private var formattedRemainingOrDuration: String {
        if mediaModel.trackInfo.duration > 0 {
            let remaining = max(mediaModel.trackInfo.duration - mediaModel.trackInfo.elapsedTime, 0.0)
            return "-\(formatTime(remaining))"
        }
        return "0:00"
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds > 0 else { return "0:00" }
        let totalSecs = Int(seconds)
        let hours = totalSecs / 3600
        let mins = (totalSecs % 3600) / 60
        let secs = totalSecs % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, mins, secs)
        } else {
            return String(format: "%d:%02d", mins, secs)
        }
    }
}

// Interactive Playhead & Progress Scrubber Bar with Click & Drag Support
public struct InteractiveScrubberBar: View {
    @Bindable var mediaModel: MediaControlsWidget
    var height: CGFloat = 3.0
    var isMini: Bool = false
    
    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false
    @State private var dragProgress: Double? = nil
    
    private var currentProgress: Double {
        if let drag = dragProgress {
            return drag
        }
        return min(max(mediaModel.trackInfo.progress, 0.0), 1.0)
    }
    
    public var body: some View {
        GeometryReader { geo in
            let totalWidth = max(geo.size.width, 1.0)
            let activeWidth = min(max(totalWidth * currentProgress, 3.0), totalWidth)
            let isEngaged = isHovering || isDragging
            let barHeight = isEngaged ? (height + 2.5) : height
            
            ZStack(alignment: .leading) {
                // Generous Hit Area
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Track Background
                Capsule()
                    .fill(Color.white.opacity(isEngaged ? 0.28 : 0.18))
                    .frame(height: barHeight)
                
                // Active Filled Progress Track
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.95)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: activeWidth, height: barHeight)
                
                // Playhead Scrubber Knob
                if isEngaged && !isMini {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 9.0, height: 9.0)
                        .shadow(color: Color.black.opacity(0.4), radius: 2, y: 1)
                        .offset(x: min(max(activeWidth - 4.5, 0.0), totalWidth - 9.0))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let fraction = min(max(value.location.x / totalWidth, 0.0), 1.0)
                        dragProgress = fraction
                        if mediaModel.trackInfo.duration > 0 {
                            mediaModel.trackInfo.elapsedTime = mediaModel.trackInfo.duration * fraction
                        }
                    }
                    .onEnded { value in
                        let fraction = min(max(value.location.x / totalWidth, 0.0), 1.0)
                        dragProgress = nil
                        isDragging = false
                        mediaModel.seek(toFraction: fraction)
                    }
            )
        }
        .frame(height: isMini ? 10.0 : 14.0)
        .onHover { h in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                isHovering = h
            }
        }
    }
}
