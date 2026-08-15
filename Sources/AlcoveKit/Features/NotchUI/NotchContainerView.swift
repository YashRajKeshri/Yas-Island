import SwiftUI
import UniformTypeIdentifiers

public struct NotchContainerView: View {
    @Environment(NotchPanelManager.self) private var manager
    @State private var timerModel = QuickTimerWidget.shared
    @State private var isTargetedForDrop: Bool = false
    @State private var isHovering: Bool = false
    
    public init() {}
    
    private var isDuoActive: Bool {
        manager.displayMode == .duo || timerModel.isRunning
    }
    
    // Dynamic Morphing Dimensions computed directly in SwiftUI
    private var notchWidth: CGFloat {
        switch manager.state {
        case .collapsed:
            if isDuoActive {
                return manager.metrics.hasPhysicalNotch ? (manager.metrics.notchWidth + 110.0) : 260.0
            } else {
                return manager.metrics.hasPhysicalNotch ? manager.metrics.notchWidth : 179.0
            }
        case .hoverPeeking:
            return manager.metrics.hasPhysicalNotch ? (manager.metrics.notchWidth + 70.0) : 240.0
        case .expanded:
            return isDuoActive ? 460.0 : 380.0
        }
    }
    
    private var notchHeight: CGFloat {
        switch manager.state {
        case .collapsed:
            return manager.metrics.hasPhysicalNotch ? manager.metrics.notchHeight : 32.0
        case .hoverPeeking:
            return manager.metrics.hasPhysicalNotch ? (manager.metrics.notchHeight + 14.0) : 46.0
        case .expanded:
            return manager.metrics.hasPhysicalNotch ? (isDuoActive ? 116.0 : 112.0) : 104.0
        }
    }
    
    private var bottomCornerRadius: CGFloat {
        switch manager.state {
        case .collapsed:
            return 9.0
        case .hoverPeeking:
            return 14.0
        case .expanded:
            return 36.0
        }
    }
    
    public var body: some View {
        ZStack(alignment: .top) {
            // Main Morphing Black Notch Droplet
            ZStack(alignment: .top) {
                // Background Black OLED Silhouette
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: bottomCornerRadius,
                    bottomTrailingRadius: bottomCornerRadius,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(Color.black)
                
                // Content Layer
                ZStack(alignment: .top) {
                    if manager.state == .collapsed {
                        Group {
                            if isDuoActive {
                                YasIslandDuoCollapsedView(isHovered: false, isDropTargeted: isTargetedForDrop)
                            } else {
                                YasIslandCollapsedEarsView(isHovered: false, isDropTargeted: isTargetedForDrop)
                            }
                        }
                        .frame(height: manager.metrics.hasPhysicalNotch ? manager.metrics.notchHeight : 32)
                        .transition(.opacity)
                    } else if manager.state == .hoverPeeking {
                        Group {
                            if isDuoActive {
                                YasIslandDuoCollapsedView(isHovered: true, isDropTargeted: isTargetedForDrop)
                            } else {
                                YasIslandCollapsedEarsView(isHovered: true, isDropTargeted: isTargetedForDrop)
                            }
                        }
                        .padding(.top, topContentPadding)
                        .transition(.opacity)
                    } else {
                        ExpandedDashboardView()
                            .padding(.top, topContentPadding)
                            .padding(.horizontal, isDuoActive ? 14 : 16)
                            .padding(.bottom, 12)
                            .transition(.opacity)
                    }
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: bottomCornerRadius,
                        bottomTrailingRadius: bottomCornerRadius,
                        topTrailingRadius: 0,
                        style: .continuous
                    )
                )
            }
            .frame(width: notchWidth, height: notchHeight)
            .contentShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: bottomCornerRadius,
                    bottomTrailingRadius: bottomCornerRadius,
                    topTrailingRadius: 0,
                    style: .continuous
                )
            )
            .onHover { h in
                isHovering = h
                manager.handleHoverChange(h)
            }
            .onTapGesture {
                manager.setExpansionState(manager.state == .expanded ? .collapsed : .expanded)
            }
            .onDrop(of: [.fileURL, .text, .image], isTargeted: $isTargetedForDrop) { providers in
                DropHandler.handleIncoming(providers: providers)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(manager.isFullscreenActive && !isHovering && manager.state != .expanded ? 0.0 : 1.0)
    }
    
    private var topContentPadding: CGFloat {
        if manager.metrics.hasPhysicalNotch {
            return manager.metrics.notchHeight + 2.0
        } else {
            return manager.state == .expanded ? 8.0 : 4.0
        }
    }
}

// Single Ear Wings View with Live Waveform, Track Name, Timer & Timestamp (No Blue Light / Dot)
public struct YasIslandCollapsedEarsView: View {
    let isHovered: Bool
    let isDropTargeted: Bool
    
    @State private var mediaWidget = MediaControlsWidget.shared
    @State private var timerWidget = QuickTimerWidget.shared
    
    private var hasMedia: Bool {
        !mediaWidget.trackInfo.title.isEmpty && mediaWidget.trackInfo.title != "No Media Playing"
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // LEFT WING: Clean Artwork or App Glyph + Track Name
            HStack(spacing: 5) {
                if let data = mediaWidget.trackInfo.artworkData, let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 14, height: 14)
                        .clipShape(RoundedRectangle(cornerRadius: 3.5, style: .continuous))
                } else if timerWidget.isRunning {
                    Image(systemName: "timer")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AlcoveTheme.accentOrange)
                } else {
                    Image(systemName: mediaWidget.trackInfo.isPlaying ? "waveform" : (hasMedia ? "play.circle.fill" : "music.note"))
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                
                if hasMedia {
                    Text(mediaWidget.trackInfo.title)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(1)
                        .frame(maxWidth: 80)
                } else if timerWidget.isRunning {
                    Text("Timer")
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(AlcoveTheme.accentOrange)
                }
            }
            .padding(.leading, 7)
            
            // CENTER: Space for Camera Bezel
            Spacer()
            
            // RIGHT WING: Live Timestamp / Countdown + Live 3-bar Waveform
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                let liveElapsed = mediaWidget.currentLiveElapsedTime
                HStack(spacing: 4) {
                    if hasMedia {
                        if liveElapsed > 0 {
                            Text(formatCollapsedTime(liveElapsed))
                                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.70))
                        }
                        if mediaWidget.trackInfo.isPlaying {
                            LiveWaveformView(isPlaying: true, barCount: 3, height: 9)
                        } else {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.45))
                        }
                    } else if timerWidget.isRunning {
                        Text(timerWidget.formattedRemainingTime)
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(AlcoveTheme.accentOrange)
                    } else {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.35))
                    }
                }
                .frame(height: 12)
                .padding(.trailing, 7)
            }
        }
    }
    
    private func formatCollapsedTime(_ seconds: Double) -> String {
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

// Enhanced Split Screen (Duo) Collapsed View (Split Activity: Media Left + Timer/Power Right)
public struct YasIslandDuoCollapsedView: View {
    let isHovered: Bool
    let isDropTargeted: Bool
    
    @State private var mediaWidget = MediaControlsWidget.shared
    @State private var timerWidget = QuickTimerWidget.shared
    @State private var statusWidget = SystemStatusWidget.shared
    
    private var hasMedia: Bool {
        !mediaWidget.trackInfo.title.isEmpty && mediaWidget.trackInfo.title != "No Media Playing"
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // LEFT PILL: Media Status & Thumbnail
            HStack(spacing: 4) {
                if let data = mediaWidget.trackInfo.artworkData, let img = NSImage(data: data) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 13, height: 13)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                } else {
                    Image(systemName: mediaWidget.trackInfo.isPlaying ? "waveform" : (hasMedia ? "play.circle.fill" : "music.note"))
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                
                Text(hasMedia ? mediaWidget.trackInfo.title : "Now Playing")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .lineLimit(1)
                    .frame(maxWidth: 65)
                
                if mediaWidget.trackInfo.isPlaying {
                    LiveWaveformView(isPlaying: true, barCount: 3, height: 8)
                }
            }
            .padding(.leading, 6)
            
            Spacer()
            
            // RIGHT PILL: Active Timer Countdown / Battery Status
            HStack(spacing: 3.5) {
                if timerWidget.isRunning {
                    Image(systemName: "timer")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(AlcoveTheme.accentOrange)
                    Text(timerWidget.formattedRemainingTime)
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(AlcoveTheme.accentOrange)
                } else {
                    Image(systemName: statusWidget.telemetry.isCharging ? "bolt.fill" : "battery.100")
                        .font(.system(size: 8))
                        .foregroundStyle(AlcoveTheme.accentGreen)
                    Text("\(statusWidget.telemetry.batteryPercent)%")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.80))
                }
            }
            .padding(.trailing, 6)
        }
    }
}
