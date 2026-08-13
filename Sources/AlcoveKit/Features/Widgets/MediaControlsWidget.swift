import SwiftUI
import AppKit
@preconcurrency import CoreFoundation

public struct MediaTrackInfo: Sendable, Equatable {
    public var title: String
    public var artist: String
    public var album: String
    public var isPlaying: Bool
    public var appName: String
    public var progress: Double
    public var duration: Double
    public var elapsedTime: Double
    public var artworkData: Data?
    public var isPodcast: Bool
    public var podcastSpeed: Double
    public var isAutoMixEnabled: Bool
    public var airPlayDevice: String
    
    public static let placeholder = MediaTrackInfo(
        title: "No Media Playing",
        artist: "Play audio in Spotify, Apple Music, or Browser",
        album: "",
        isPlaying: false,
        appName: "System",
        progress: 0.0,
        duration: 0.0,
        elapsedTime: 0.0,
        artworkData: nil,
        isPodcast: false,
        podcastSpeed: 1.0,
        isAutoMixEnabled: true,
        airPlayDevice: "MacBook Pro Speakers"
    )
}

public enum SystemMediaRemote {
    private typealias MRMediaRemoteSendCommandFunction = @convention(c) (Int32, AnyObject?) -> Bool
    private typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @escaping (CFDictionary) -> Void) -> Void
    private typealias MRMediaRemoteRegisterFunction = @convention(c) (DispatchQueue) -> Void
    
    private static let bundle: CFBundle? = {
        CFBundleCreate(kCFAllocatorDefault, NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework"))
    }()
    
    private static let sendCommandPtr: MRMediaRemoteSendCommandFunction? = {
        guard let b = bundle,
              let ptr = CFBundleGetFunctionPointerForName(b, "MRMediaRemoteSendCommand" as CFString) else {
            return nil
        }
        return unsafeBitCast(ptr, to: MRMediaRemoteSendCommandFunction.self)
    }()
    
    private static let getInfoPtr: MRMediaRemoteGetNowPlayingInfoFunction? = {
        guard let b = bundle,
              let ptr = CFBundleGetFunctionPointerForName(b, "MRMediaRemoteGetNowPlayingInfo" as CFString) else {
            return nil
        }
        return unsafeBitCast(ptr, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
    }()
    
    private static let registerPtr: MRMediaRemoteRegisterFunction? = {
        guard let b = bundle,
              let ptr = CFBundleGetFunctionPointerForName(b, "MRMediaRemoteRegisterForNowPlayingNotifications" as CFString) else {
            return nil
        }
        return unsafeBitCast(ptr, to: MRMediaRemoteRegisterFunction.self)
    }()
    
    public static func registerForNotifications() {
        registerPtr?(DispatchQueue.main)
    }
    
    public static func sendCommand(_ commandId: Int32) -> Bool {
        if let send = sendCommandPtr {
            return send(commandId, nil)
        }
        return false
    }
    
    public static func togglePlayPause() {
        if !sendCommand(2) {
            if isAppRunning("com.spotify.client") {
                runAppleScript("tell application \"Spotify\" to playpause")
            } else if isAppRunning("com.apple.Music") {
                runAppleScript("tell application \"Music\" to playpause")
            }
        }
    }
    
    public static func nextTrack() {
        if !sendCommand(4) {
            if isAppRunning("com.spotify.client") {
                runAppleScript("tell application \"Spotify\" to next track")
            } else if isAppRunning("com.apple.Music") {
                runAppleScript("tell application \"Music\" to next track")
            }
        }
    }
    
    public static func previousTrack() {
        if !sendCommand(5) {
            if isAppRunning("com.spotify.client") {
                runAppleScript("tell application \"Spotify\" to previous track")
            } else if isAppRunning("com.apple.Music") {
                runAppleScript("tell application \"Music\" to previous track")
            }
        }
    }
    
    private static func runAppleScript(_ script: String) {
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
    
    public static func isAppRunning(_ bundleId: String) -> Bool {
        return NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == bundleId })
    }
    
    public static func fetchNowPlayingInfo(completion: @escaping @Sendable (MediaTrackInfo?) -> Void) {
        // Step 1: Query Apple MediaRemote
        if let getInfo = getInfoPtr {
            getInfo(DispatchQueue.main) { infoDict in
                let dict = infoDict as NSDictionary
                let title = (dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let artist = (dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let album = (dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let playbackRate = dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"] as? Double ?? 0.0
                let duration = dict["kMRMediaRemoteNowPlayingInfoDuration"] as? Double ?? 0.0
                let elapsedTime = dict["kMRMediaRemoteNowPlayingInfoElapsedTime"] as? Double ?? 0.0
                let artworkData = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data
                
                if let title = title, !title.isEmpty {
                    let isPlaying = playbackRate > 0.0
                    let progress = duration > 0 ? min(max(elapsedTime / duration, 0.0), 1.0) : (isPlaying ? 0.5 : 0.0)
                    let track = MediaTrackInfo(
                        title: title,
                        artist: (artist?.isEmpty ?? true) ? ((album?.isEmpty ?? true) ? "Now Playing" : album!) : artist!,
                        album: album ?? "",
                        isPlaying: isPlaying,
                        appName: "System",
                        progress: progress,
                        duration: duration,
                        elapsedTime: elapsedTime,
                        artworkData: artworkData,
                        isPodcast: duration > 1200,
                        podcastSpeed: 1.0,
                        isAutoMixEnabled: true,
                        airPlayDevice: "MacBook Pro Speakers"
                    )
                    completion(track)
                    return
                }
                
                fallbackFetch(completion: completion)
            }
        } else {
            fallbackFetch(completion: completion)
        }
    }
    
    private static func fallbackFetch(completion: @escaping @Sendable (MediaTrackInfo?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // Check Spotify ONLY if running
            if isAppRunning("com.spotify.client"), let spotTrack = checkSpotifyApp() {
                DispatchQueue.main.async { completion(spotTrack) }
                return
            }
            
            // Check Apple Music ONLY if running
            if isAppRunning("com.apple.Music"), let musicTrack = checkAppleMusicApp() {
                DispatchQueue.main.async { completion(musicTrack) }
                return
            }
            
            // Check Browsers (Brave, Chrome, Safari, Arc) ONLY if running
            if let browserTrack = checkBrowsers() {
                DispatchQueue.main.async { completion(browserTrack) }
                return
            }
            
            DispatchQueue.main.async { completion(nil) }
        }
    }
    
    private static func checkSpotifyApp() -> MediaTrackInfo? {
        guard isAppRunning("com.spotify.client") else { return nil }
        let script = """
        tell application "Spotify"
            set pState to player state as string
            set tName to name of current track
            set aName to artist of current track
            set alName to album of current track
            set tDur to (duration of current track) / 1000
            set tPos to player position
            set aUrl to artwork url of current track
            return pState & "|||" & tName & "|||" & aName & "|||" & alName & "|||" & tPos & "|||" & tDur & "|||" & aUrl
        end tell
        """
        guard let output = executeScript(script), !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }
        
        let isPlaying = parts[0].lowercased() == "playing"
        let title = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let elapsed = Double(parts[4]) ?? 0.0
        let duration = Double(parts[5]) ?? 0.0
        let artUrl = parts.count > 6 ? parts[6] : ""
        
        var artData: Data? = nil
        if let url = URL(string: artUrl), url.scheme != nil {
            artData = try? Data(contentsOf: url)
        }
        
        let progress = duration > 0 ? min(max(elapsed / duration, 0.0), 1.0) : 0.0
        return MediaTrackInfo(
            title: title,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            appName: "Spotify",
            progress: progress,
            duration: duration,
            elapsedTime: elapsed,
            artworkData: artData,
            isPodcast: false,
            podcastSpeed: 1.0,
            isAutoMixEnabled: true,
            airPlayDevice: "MacBook Pro Speakers"
        )
    }
    
    private static func checkAppleMusicApp() -> MediaTrackInfo? {
        guard isAppRunning("com.apple.Music") else { return nil }
        let script = """
        tell application "Music"
            set pState to player state as string
            set tName to name of current track
            set aName to artist of current track
            set alName to album of current track
            set tDur to duration of current track
            set tPos to player position
            return pState & "|||" & tName & "|||" & aName & "|||" & alName & "|||" & tPos & "|||" & tDur
        end tell
        """
        guard let output = executeScript(script), !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }
        
        let isPlaying = parts[0].lowercased() == "playing"
        let title = parts[1]
        let artist = parts[2]
        let album = parts[3]
        let elapsed = Double(parts[4]) ?? 0.0
        let duration = Double(parts[5]) ?? 0.0
        
        let progress = duration > 0 ? min(max(elapsed / duration, 0.0), 1.0) : 0.0
        return MediaTrackInfo(
            title: title,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            appName: "Apple Music",
            progress: progress,
            duration: duration,
            elapsedTime: elapsed,
            artworkData: nil,
            isPodcast: false,
            podcastSpeed: 1.0,
            isAutoMixEnabled: true,
            airPlayDevice: "MacBook Pro Speakers"
        )
    }
    
    private static func checkBrowsers() -> MediaTrackInfo? {
        let browsers: [(name: String, bundleId: String)] = [
            ("Brave Browser", "com.brave.Browser"),
            ("Google Chrome", "com.google.Chrome"),
            ("Arc", "company.thebrowser.Browser"),
            ("Safari", "com.apple.Safari")
        ]
        
        for browser in browsers {
            guard isAppRunning(browser.bundleId) else { continue }
            
            let script: String
            if browser.name == "Safari" {
                script = """
                tell application "Safari"
                    repeat with aWin in every window
                        repeat with aTab in every tab of aWin
                            set tURL to URL of aTab
                            set tTitle to name of aTab
                            if tURL contains "youtube.com/watch" or tURL contains "music.youtube.com" or tURL contains "soundcloud.com" or tURL contains "spotify.com" then
                                return tTitle & "|||" & tURL
                            end if
                        end repeat
                    end repeat
                end tell
                """
            } else {
                script = """
                tell application "\(browser.name)"
                    repeat with aWin in every window
                        repeat with aTab in every tab of aWin
                            set tURL to URL of aTab
                            set tTitle to title of aTab
                            if tURL contains "youtube.com/watch" or tURL contains "music.youtube.com" or tURL contains "soundcloud.com" or tURL contains "spotify.com" then
                                return tTitle & "|||" & tURL
                            end if
                        end repeat
                    end repeat
                end tell
                """
            }
            
            if let output = executeScript(script), !output.isEmpty {
                let parts = output.components(separatedBy: "|||")
                if parts.count >= 2 {
                    var rawTitle = parts[0]
                    let urlString = parts[1]
                    
                    // Clean up title
                    rawTitle = rawTitle.replacingOccurrences(of: "\\(\\d+\\)\\s*", with: "", options: .regularExpression)
                    rawTitle = rawTitle.replacingOccurrences(of: "\\s*-\\s*YouTube.*$", with: "", options: .regularExpression)
                    
                    var title = rawTitle
                    var artist = browser.name
                    
                    if rawTitle.contains("–") {
                        let subparts = rawTitle.components(separatedBy: "–")
                        artist = subparts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        title = subparts.dropFirst().joined(separator: "–").trimmingCharacters(in: .whitespacesAndNewlines)
                    } else if rawTitle.contains("-") {
                        let subparts = rawTitle.components(separatedBy: "-")
                        artist = subparts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        title = subparts.dropFirst().joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    var artData: Data? = nil
                    if let range = urlString.range(of: "v=") {
                        let afterV = urlString[range.upperBound...]
                        let vid = String(afterV.prefix(while: { $0 != "&" && $0 != "#" }))
                        if !vid.isEmpty, let thumbUrl = URL(string: "https://img.youtube.com/vi/\(vid)/hqdefault.jpg") {
                            artData = try? Data(contentsOf: thumbUrl)
                        }
                    }
                    
                    return MediaTrackInfo(
                        title: title.isEmpty ? rawTitle : title,
                        artist: artist,
                        album: "Web Media",
                        isPlaying: true,
                        appName: browser.name,
                        progress: 0.5,
                        duration: 0.0,
                        elapsedTime: 0.0,
                        artworkData: artData,
                        isPodcast: false,
                        podcastSpeed: 1.0,
                        isAutoMixEnabled: true,
                        airPlayDevice: "MacBook Pro Speakers"
                    )
                }
            }
        }
        return nil
    }
    
    private static func executeScript(_ source: String) -> String? {
        if let script = NSAppleScript(source: source) {
            var error: NSDictionary?
            let result = script.executeAndReturnError(&error)
            if error == nil {
                return result.stringValue
            }
        }
        return nil
    }
}

@MainActor
@Observable
public final class MediaControlsWidget: AlcoveWidget, @unchecked Sendable {
    public static let shared = MediaControlsWidget()
    
    public let id: String = "alcove.widget.media"
    public let displayName: String = "Now Playing"
    public let systemImage: String = "play.circle.fill"
    public var isEnabled: Bool = true
    
    public var trackInfo: MediaTrackInfo = .placeholder
    public var availableAirPlayDevices: [String] = [
        "MacBook Pro Speakers",
        "AirPods Pro",
        "HomePod (Studio)",
        "Living Room Apple TV"
    ]
    
    private var syncTask: Task<Void, Never>?
    
    private init() {
        SystemMediaRemote.registerForNotifications()
        startLiveSync()
    }
    
    public func startLiveSync() {
        refresh()
        syncTask?.cancel()
        syncTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                self?.refresh()
            }
        }
    }
    
    public func refresh() {
        SystemMediaRemote.fetchNowPlayingInfo { [weak self] liveTrack in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let live = liveTrack {
                    var updated = live
                    updated.podcastSpeed = self.trackInfo.podcastSpeed
                    updated.isAutoMixEnabled = self.trackInfo.isAutoMixEnabled
                    updated.airPlayDevice = self.trackInfo.airPlayDevice
                    self.trackInfo = updated
                } else {
                    self.trackInfo = .placeholder
                }
            }
        }
    }
    
    public func togglePlayback() {
        SystemMediaRemote.togglePlayPause()
        trackInfo.isPlaying.toggle()
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            self?.refresh()
        }
    }
    
    public func skipNext() {
        SystemMediaRemote.nextTrack()
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            self?.refresh()
        }
    }
    
    public func skipPrevious() {
        SystemMediaRemote.previousTrack()
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            self?.refresh()
        }
    }
    
    public func setPodcastSpeed(_ speed: Double) {
        trackInfo.podcastSpeed = speed
    }
    
    public func toggleAutoMix() {
        trackInfo.isAutoMixEnabled.toggle()
    }
    
    public func selectAirPlayDevice(_ device: String) {
        trackInfo.airPlayDevice = device
    }
    
    public func openSpotifyAlbum() {
        let query = trackInfo.album.isEmpty ? trackInfo.title : trackInfo.album
        if let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "spotify:search:\(encoded)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func openSpotifyArtist() {
        if let encoded = trackInfo.artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "spotify:search:\(encoded)") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func renderView() -> AnyView {
        AnyView(MediaControlsView(model: self))
    }
}

// Compact Grid View with Live Waveform
public struct MediaControlsView: View {
    @Bindable var model: MediaControlsWidget
    @State private var isHovering: Bool = false
    
    public var body: some View {
        HStack(spacing: 10) {
            Button {
                model.openSpotifyAlbum()
            } label: {
                ArtworkThumbnail(data: model.trackInfo.artworkData, isPlaying: model.trackInfo.isPlaying, size: 38)
            }
            .buttonStyle(.plain)
            .help("Open in Spotify / Apple Music")
            
            VStack(alignment: .leading, spacing: 2) {
                Text(model.trackInfo.title)
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(AlcoveTheme.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(model.trackInfo.artist)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(AlcoveTheme.textSecondary)
                        .lineLimit(1)
                    
                    if model.trackInfo.isPlaying {
                        LiveWaveformView(isPlaying: true, barCount: 4, height: 9)
                    }
                }
            }
            
            Spacer()
            
            // Controls
            HStack(spacing: 6) {
                Button { model.skipPrevious() } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AlcoveTheme.textSecondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                
                Button { model.togglePlayback() } label: {
                    Image(systemName: model.trackInfo.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(model.trackInfo.isPlaying ? AlcoveTheme.accentPurple.opacity(0.5) : Color.white.opacity(0.14))
                        )
                }
                .buttonStyle(.plain)
                
                Button { model.skipNext() } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(AlcoveTheme.textSecondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AlcoveMetrics.cardCornerRadius, style: .continuous)
                .fill(isHovering ? AlcoveTheme.cardHoverBackground : AlcoveTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AlcoveMetrics.cardCornerRadius, style: .continuous)
                        .strokeBorder(AlcoveTheme.cardBorder, lineWidth: 0.75)
                )
        )
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { isHovering = h } }
    }
}

// Hero View with Spotify Podcast Speed, AutoMix & AirPlay Routing
public struct MediaControlsHeroView: View {
    @State private var model = MediaControlsWidget.shared
    @State private var showAirPlaySheet: Bool = false
    
    public var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                // Large Clickable Album Art
                Button {
                    model.openSpotifyAlbum()
                } label: {
                    ArtworkThumbnail(data: model.trackInfo.artworkData, isPlaying: model.trackInfo.isPlaying, size: 66)
                }
                .buttonStyle(.plain)
                .help("Tap to open Spotify playlist / album")
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.trackInfo.title)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(AlcoveTheme.textPrimary)
                        .lineLimit(1)
                    
                    Button {
                        model.openSpotifyArtist()
                    } label: {
                        Text(model.trackInfo.artist)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(AlcoveTheme.textSecondary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    
                    HStack(spacing: 8) {
                        // AirPlay Selector Menu
                        Menu {
                            ForEach(model.availableAirPlayDevices, id: \.self) { dev in
                                Button {
                                    model.selectAirPlayDevice(dev)
                                } label: {
                                    HStack {
                                        Text(dev)
                                        if model.trackInfo.airPlayDevice == dev {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "airplayaudio")
                                    .font(.system(size: 9.5))
                                Text(model.trackInfo.airPlayDevice)
                                    .font(.system(size: 9.5, weight: .medium))
                            }
                            .foregroundStyle(AlcoveTheme.accentTeal)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AlcoveTheme.accentTeal.opacity(0.12)))
                        }
                        .menuStyle(.borderlessButton)
                        
                        // AutoMix Toggle Pill
                        Button {
                            model.toggleAutoMix()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "waveform.path.badge.plus")
                                    .font(.system(size: 9))
                                Text("AutoMix")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundStyle(model.trackInfo.isAutoMixEnabled ? AlcoveTheme.accentGreen : AlcoveTheme.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(model.trackInfo.isAutoMixEnabled ? AlcoveTheme.accentGreen.opacity(0.14) : Color.white.opacity(0.06))
                            )
                        }
                        .buttonStyle(.plain)
                        .help("AutoMix intelligent DJ crossfades")
                    }
                    .padding(.top, 2)
                }
                
                Spacer()
                
                // Playback Buttons
                HStack(spacing: 8) {
                    Button { model.skipPrevious() } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(AlcoveTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    
                    Button { model.togglePlayback() } label: {
                        Image(systemName: model.trackInfo.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(
                                Circle().fill(
                                    LinearGradient(
                                        colors: [AlcoveTheme.accentPurple, AlcoveTheme.accentPink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: AlcoveTheme.accentPurple.opacity(0.4), radius: 6, y: 3)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Button { model.skipNext() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(AlcoveTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Podcast Speed Bar / Live Waveform
            HStack {
                HStack(spacing: 4) {
                    Text("Speed:")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(AlcoveTheme.textTertiary)
                    
                    ForEach([1.0, 1.25, 1.5, 2.0], id: \.self) { spd in
                        Button {
                            model.setPodcastSpeed(spd)
                        } label: {
                            Text(String(format: "%.2fx", spd).replacingOccurrences(of: ".00", with: ""))
                                .font(.system(size: 9.5, weight: model.trackInfo.podcastSpeed == spd ? .bold : .regular))
                                .foregroundStyle(model.trackInfo.podcastSpeed == spd ? AlcoveTheme.textPrimary : AlcoveTheme.textTertiary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(model.trackInfo.podcastSpeed == spd ? Color.white.opacity(0.16) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                if model.trackInfo.isPlaying {
                    LiveWaveformView(isPlaying: true, barCount: 7, height: 12)
                }
            }
            
            // Timeline Scrubber
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 4)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [AlcoveTheme.accentPurple, AlcoveTheme.accentPink],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(geo.size.width * model.trackInfo.progress, 4), height: 4)
                    }
                }
                .frame(height: 4)
                
                HStack {
                    Text(formatTime(model.trackInfo.elapsedTime))
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(AlcoveTheme.textTertiary)
                    Spacer()
                    Text(formatTime(model.trackInfo.duration))
                        .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(AlcoveTheme.textTertiary)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AlcoveMetrics.cardCornerRadius, style: .continuous)
                .fill(AlcoveTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AlcoveMetrics.cardCornerRadius, style: .continuous)
                        .strokeBorder(AlcoveTheme.cardBorder, lineWidth: 0.75)
                )
        )
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds > 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

public struct ArtworkThumbnail: View {
    let data: Data?
    let isPlaying: Bool
    let size: CGFloat
    
    public var body: some View {
        ZStack {
            if let d = data, let img = NSImage(data: d) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: Color.black.opacity(0.4), radius: 5, y: 2)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isPlaying ? [
                                AlcoveTheme.accentPurple,
                                AlcoveTheme.accentPink,
                                AlcoveTheme.accentTeal
                            ] : [
                                Color(nsColor: .darkGray),
                                Color(nsColor: .black)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .shadow(color: isPlaying ? AlcoveTheme.accentPurple.opacity(0.4) : Color.clear, radius: 5, y: 2)
                
                Image(systemName: isPlaying ? "waveform" : "music.note")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}
