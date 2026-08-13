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
    private typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @convention(block) @escaping (AnyObject?) -> Void) -> Void
    private typealias MRMediaRemoteRegisterFunction = @convention(c) (DispatchQueue) -> Void
    
    nonisolated(unsafe) private static let bundleHandle: UnsafeMutableRawPointer? = {
        let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
        if handle == nil {
            print("❌ MediaRemote dlopen failed: \(String(cString: dlerror()))")
        }
        return handle
    }()
    
    nonisolated(unsafe) private static let sendCommandPtr: MRMediaRemoteSendCommandFunction? = {
        if let h = bundleHandle, let sym = dlsym(h, "MRMediaRemoteSendCommand") {
            return unsafeBitCast(sym, to: MRMediaRemoteSendCommandFunction.self)
        }
        return nil
    }()
    
    nonisolated(unsafe) private static let getInfoPtr: MRMediaRemoteGetNowPlayingInfoFunction? = {
        if let h = bundleHandle, let sym = dlsym(h, "MRMediaRemoteGetNowPlayingInfo") {
            return unsafeBitCast(sym, to: MRMediaRemoteGetNowPlayingInfoFunction.self)
        }
        print("❌ MRMediaRemoteGetNowPlayingInfo dlsym failed!")
        return nil
    }()
    
    nonisolated(unsafe) private static let registerPtr: MRMediaRemoteRegisterFunction? = {
        if let h = bundleHandle, let sym = dlsym(h, "MRMediaRemoteRegisterForNowPlayingNotifications") {
            return unsafeBitCast(sym, to: MRMediaRemoteRegisterFunction.self)
        }
        return nil
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
    
    private static func parseDouble(_ value: Any?) -> Double {
        if let num = value as? NSNumber { return num.doubleValue }
        if let str = value as? String, let d = Double(str) { return d }
        if let d = value as? Double { return d }
        return 0.0
    }
    
    public static func fetchNowPlayingInfo(completion: @escaping @Sendable (MediaTrackInfo?) -> Void) {
        print("fetchNowPlayingInfo called! getInfoPtr is nil?:", getInfoPtr == nil)
        // Step 1: Query Apple MediaRemote on high-priority global queue
        if let getInfo = getInfoPtr {
            getInfo(DispatchQueue.global(qos: .userInteractive)) { obj in
                print("DEBUG: in getInfo callback, obj is:", obj as Any)
                guard let dict = obj as? [String: Any] else {
                    print("DEBUG: failed to cast obj to [String: Any]! type(of: obj) is:", type(of: obj as Any))
                    fallbackFetch(completion: completion)
                    return
                }
                
                let rawTitle = (dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                print("SystemMediaRemote: rawTitle is '\(rawTitle ?? "<nil>")'")
                let rawArtist = (dict["kMRMediaRemoteNowPlayingInfoArtist"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let rawAlbum = (dict["kMRMediaRemoteNowPlayingInfoAlbum"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let playbackRate = parseDouble(dict["kMRMediaRemoteNowPlayingInfoPlaybackRate"])
                let duration = parseDouble(dict["kMRMediaRemoteNowPlayingInfoDuration"])
                let elapsedTime = parseDouble(dict["kMRMediaRemoteNowPlayingInfoElapsedTime"])
                
                var artworkData: Data? = nil
                if let d = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data {
                    artworkData = d
                } else if let nsD = dict["kMRMediaRemoteNowPlayingInfoArtworkData"] as? NSData {
                    artworkData = nsD as Data
                }
                
                if let rawTitle = rawTitle, !rawTitle.isEmpty {
                    let isPlaying = playbackRate > 0.0
                    
                    // Live real-time elapsed time calculation from snapshot timestamp
                    var liveElapsed = elapsedTime
                    if let ts = dict["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date, isPlaying {
                        let delta = Date().timeIntervalSince(ts)
                        if delta > 0 && delta < 86400 {
                            liveElapsed = elapsedTime + (delta * playbackRate)
                            if duration > 0 {
                                liveElapsed = min(liveElapsed, duration)
                            }
                        }
                    }
                    
                    // Smart title/artist parsing (e.g. "Song | Artist" or "Artist - Song")
                    var displayTitle = rawTitle
                    var displayArtist = rawArtist ?? ""
                    
                    if displayArtist.isEmpty && displayTitle.contains(" | ") {
                        let comps = displayTitle.components(separatedBy: " | ")
                        displayTitle = comps[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        displayArtist = comps.dropFirst().joined(separator: " | ").trimmingCharacters(in: .whitespacesAndNewlines)
                    } else if displayArtist.isEmpty && displayTitle.contains(" - ") {
                        let comps = displayTitle.components(separatedBy: " - ")
                        displayArtist = comps[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        displayTitle = comps.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespacesAndNewlines)
                    } else if displayArtist.isEmpty && displayTitle.contains(" – ") {
                        let comps = displayTitle.components(separatedBy: " – ")
                        displayArtist = comps[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        displayTitle = comps.dropFirst().joined(separator: " – ").trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    
                    if displayArtist.isEmpty {
                        displayArtist = (rawAlbum?.isEmpty ?? true) ? "Now Playing" : rawAlbum!
                    }
                    
                    let progress = duration > 0 ? min(max(liveElapsed / duration, 0.0), 1.0) : (isPlaying ? 0.5 : 0.0)
                    let track = MediaTrackInfo(
                        title: displayTitle,
                        artist: displayArtist,
                        album: rawAlbum ?? "",
                        isPlaying: isPlaying,
                        appName: "System",
                        progress: progress,
                        duration: duration,
                        elapsedTime: liveElapsed,
                        artworkData: artworkData,
                        isPodcast: duration > 1200,
                        podcastSpeed: 1.0,
                        isAutoMixEnabled: true,
                        airPlayDevice: "MacBook Pro Speakers"
                    )
                    DispatchQueue.main.async {
                        completion(track)
                    }
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
            try
                set pState to player state as string
                set tName to name of current track
                set aName to artist of current track
                set alName to album of current track
                set tDur to (duration of current track) / 1000
                set tPos to player position
                set aUrl to artwork url of current track
                return pState & "|||" & tName & "|||" & aName & "|||" & alName & "|||" & tPos & "|||" & tDur & "|||" & aUrl
            on error
                return ""
            end try
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
            try
                set pState to player state as string
                if pState is not "stopped" then
                    set tName to name of current track
                    set aName to artist of current track
                    set alName to album of current track
                    set tDur to duration of current track
                    set tPos to player position
                    return pState & "|||" & tName & "|||" & aName & "|||" & alName & "|||" & tPos & "|||" & tDur
                end if
            on error
                return ""
            end try
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
                    try
                        repeat with aWin in every window
                            repeat with aTab in every tab of aWin
                                set tURL to (get URL of aTab)
                                set tTitle to (get name of aTab)
                                if tURL contains "youtube.com/watch" or tURL contains "music.youtube.com" or tURL contains "soundcloud.com" or tURL contains "spotify.com" then
                                    return tTitle & "|||" & tURL
                                end if
                            end repeat
                        end repeat
                    on error
                        return ""
                    end try
                end tell
                """
            } else {
                script = """
                tell application "\(browser.name)"
                    try
                        repeat with aWin in windows
                            repeat with aTab in tabs of aWin
                                set tURL to (get url of aTab)
                                set tTitle to (get title of aTab)
                                if tURL contains "youtube.com/watch" or tURL contains "music.youtube.com" or tURL contains "soundcloud.com" or tURL contains "spotify.com" then
                                    return tTitle & "|||" & tURL
                                end if
                            end repeat
                        end repeat
                    on error
                        return ""
                    end try
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
        
        // Listen for immediate MediaRemote notification changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingInfoDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("kMRMediaRemoteNowPlayingApplicationDidChangeNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        
        startLiveSync()
    }
    
    public func startLiveSync() {
        refresh()
        syncTask?.cancel()
        syncTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms smooth ticker
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
            try? await Task.sleep(nanoseconds: 150_000_000)
            self?.refresh()
        }
    }
    
    public func skipNext() {
        SystemMediaRemote.nextTrack()
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            self?.refresh()
        }
    }
    
    public func skipPrevious() {
        SystemMediaRemote.previousTrack()
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
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
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: Color.black.opacity(0.4), radius: 4, y: 2)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isPlaying ? [
                                Color(red: 0.25, green: 0.25, blue: 0.28),
                                Color(red: 0.12, green: 0.12, blue: 0.14)
                            ] : [
                                Color(red: 0.18, green: 0.18, blue: 0.20),
                                Color(red: 0.08, green: 0.08, blue: 0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                
                Image(systemName: isPlaying ? "waveform" : "music.note")
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
        }
    }
}
