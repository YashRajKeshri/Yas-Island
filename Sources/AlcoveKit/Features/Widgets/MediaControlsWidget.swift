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
    public var snapshotTimestamp: Date?
    public var playbackRate: Double
    
    public init(
        title: String,
        artist: String,
        album: String,
        isPlaying: Bool,
        appName: String,
        progress: Double,
        duration: Double,
        elapsedTime: Double,
        artworkData: Data? = nil,
        isPodcast: Bool = false,
        podcastSpeed: Double = 1.0,
        isAutoMixEnabled: Bool = true,
        airPlayDevice: String = "MacBook Pro Speakers",
        snapshotTimestamp: Date? = nil,
        playbackRate: Double = 0.0
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.appName = appName
        self.progress = progress
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.artworkData = artworkData
        self.isPodcast = isPodcast
        self.podcastSpeed = podcastSpeed
        self.isAutoMixEnabled = isAutoMixEnabled
        self.airPlayDevice = airPlayDevice
        self.snapshotTimestamp = snapshotTimestamp
        self.playbackRate = playbackRate
    }
    
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
        airPlayDevice: "MacBook Pro Speakers",
        snapshotTimestamp: nil,
        playbackRate: 0.0
    )
}

public enum SystemMediaRemote {
    private typealias MRMediaRemoteSendCommandFunction = @convention(c) (Int32, AnyObject?) -> Bool
    private typealias MRMediaRemoteGetNowPlayingInfoFunction = @convention(c) (DispatchQueue, @convention(block) @escaping (AnyObject?) -> Void) -> Void
    private typealias MRMediaRemoteSetElapsedTimeFunction = @convention(c) (Double) -> Bool
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
    
    nonisolated(unsafe) private static let setElapsedPtr: MRMediaRemoteSetElapsedTimeFunction? = {
        if let h = bundleHandle, let sym = dlsym(h, "MRMediaRemoteSetElapsedTime") {
            return unsafeBitCast(sym, to: MRMediaRemoteSetElapsedTimeFunction.self)
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
    
    public static func seek(to seconds: Double) {
        let clamped = max(seconds, 0.0)
        
        // 1. Direct private MediaRemote API
        if let setElapsed = setElapsedPtr {
            _ = setElapsed(clamped)
        }
        
        // 2. MediaRemote command 71 (kMRSetPlaybackPosition)
        if let send = sendCommandPtr {
            let opts: NSDictionary = ["kMRMediaRemoteOptionPlaybackPosition": NSNumber(value: clamped)]
            _ = send(71, opts)
        }
        
        // 3. Spotify
        if isAppRunning("com.spotify.client") {
            runAppleScript("tell application \"Spotify\" to set player position to \(clamped)")
        }
        
        // 4. Apple Music
        if isAppRunning("com.apple.Music") {
            runAppleScript("tell application \"Music\" to set player position to \(clamped)")
        }
        
        // 5. QuickTime Player
        if isAppRunning("com.apple.QuickTimePlayerX") {
            runAppleScript("tell application \"QuickTime Player\" to try\nset current time of front document to \(clamped)\nend try")
        }
        
        // 6. Podcasts
        if isAppRunning("com.apple.podcasts") {
            runAppleScript("tell application \"Podcasts\" to try\nset playback position to \(clamped)\nend try")
        }
        
        // 7. Safari
        if isAppRunning("com.apple.Safari") {
            runAppleScript("tell application \"Safari\" to try\ntell front document to do JavaScript \"if(document.querySelector('video')){ document.querySelector('video').currentTime = \(clamped); }\"\nend try")
        }
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
    
    public static func cleanTrackInfo(rawTitle: String, rawArtist: String?, rawAlbum: String?) -> (title: String, artist: String) {
        var title = rawTitle
        var artist = rawArtist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        // Remove YouTube noise: (Official Music Video), [Remastered 2015], (Official Audio), (Lyrics), etc.
        let patterns = [
            "\\s*\\[[^\\]]*Remaster[^\\]]*\\]",
            "\\s*\\([^\\)]*Remaster[^\\]]*\\)",
            "\\s*\\([^\\)]*Official[^\\)]*\\)",
            "\\s*\\[[^\\]]*Official[^\\]]*\\]",
            "\\s*\\([^\\)]*Music Video[^\\)]*\\)",
            "\\s*\\([^\\)]*Video[^\\)]*\\)",
            "\\s*\\([^\\)]*Audio[^\\)]*\\)",
            "\\s*\\([^\\)]*Lyric[^\\)]*\\)",
            "\\s*\\([^\\)]*Promo[^\\)]*\\)",
            "\\s*\\(4K\\)",
            "\\s*\\(HD\\)",
            "\\s*\\[4K\\]",
            "\\s*\\[HD\\]"
        ]
        for p in patterns {
            title = title.replacingOccurrences(of: p, with: "", options: [.regularExpression, .caseInsensitive])
        }
        
        // Remove duplicate prefix: "Artist - Artist - Song" -> "Artist - Song"
        if let range = title.range(of: "^(.+?)\\s*-\\s*\\1\\s*-\\s*", options: .regularExpression) {
            title = String(title[range.upperBound...])
        }
        
        // Clean VEVO from artist channel name: "TheBeatlesVEVO" -> "The Beatles"
        if artist.hasSuffix("VEVO") {
            artist = String(artist.dropLast(4))
        }
        
        // Parse "Artist - Title" or "Title | Channel"
        if title.contains(" - ") {
            let parts = title.components(separatedBy: " - ")
            if parts.count >= 2 {
                let possibleArtist = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let possibleTitle = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespacesAndNewlines)
                if !possibleTitle.isEmpty {
                    artist = possibleArtist
                    title = possibleTitle
                }
            }
        } else if title.contains(" – ") {
            let parts = title.components(separatedBy: " – ")
            if parts.count >= 2 {
                let possibleArtist = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let possibleTitle = parts.dropFirst().joined(separator: " – ").trimmingCharacters(in: .whitespacesAndNewlines)
                if !possibleTitle.isEmpty {
                    artist = possibleArtist
                    title = possibleTitle
                }
            }
        } else if title.contains(" | ") {
            let parts = title.components(separatedBy: " | ")
            if parts.count >= 2 {
                title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                if artist.isEmpty {
                    artist = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        artist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if artist.isEmpty {
            artist = (rawAlbum?.isEmpty ?? true) ? "Now Playing" : rawAlbum!
        }
        
        return (title, artist)
    }
    
    public static func fetchNowPlayingInfo(completion: @escaping @Sendable (MediaTrackInfo?) -> Void) {
        // Step 1: Query Apple MediaRemote on high-priority global queue
        if let getInfo = getInfoPtr {
            getInfo(DispatchQueue.global(qos: .userInteractive)) { obj in
                guard let dict = obj as? [String: Any] else {
                    fallbackFetch(completion: completion)
                    return
                }
                
                let rawTitle = (dict["kMRMediaRemoteNowPlayingInfoTitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
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
                    let timestamp: Date? = (dict["kMRMediaRemoteNowPlayingInfoTimestamp"] as? Date) ?? ((dict["kMRMediaRemoteNowPlayingInfoTimestamp"] as? NSDate) as Date?)
                    
                    // Live real-time elapsed time calculation from snapshot timestamp
                    var liveElapsed = elapsedTime
                    if let ts = timestamp, isPlaying {
                        let delta = Date().timeIntervalSince(ts)
                        if delta >= 0 && delta < 86400 {
                            liveElapsed = elapsedTime + (delta * (playbackRate > 0 ? playbackRate : 1.0))
                            if duration > 0 {
                                liveElapsed = min(liveElapsed, duration)
                            }
                        }
                    }
                    
                    let cleaned = cleanTrackInfo(rawTitle: rawTitle, rawArtist: rawArtist, rawAlbum: rawAlbum)
                    let progress = duration > 0 ? min(max(liveElapsed / duration, 0.0), 1.0) : 0.0
                    
                    let track = MediaTrackInfo(
                        title: cleaned.title,
                        artist: cleaned.artist,
                        album: rawAlbum ?? "",
                        isPlaying: isPlaying,
                        appName: "System",
                        progress: progress,
                        duration: duration,
                        elapsedTime: elapsedTime, // Store base timestamp elapsed position (delta computed live)
                        artworkData: artworkData,
                        isPodcast: duration > 1200,
                        podcastSpeed: 1.0,
                        isAutoMixEnabled: true,
                        airPlayDevice: "MacBook Pro Speakers",
                        snapshotTimestamp: timestamp ?? Date(),
                        playbackRate: playbackRate
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
                        progress: 0.0,
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
    private var emptyPollCount: Int = 0
    private var lastSeekDate: Date = .distantPast
    private var pendingSeekTime: Double = 0.0
    
    public var currentLiveElapsedTime: Double {
        if trackInfo.isPlaying && trackInfo.playbackRate > 0, let ts = trackInfo.snapshotTimestamp {
            let delta = Date().timeIntervalSince(ts)
            if delta >= 0 && delta < 86400 {
                let live = trackInfo.elapsedTime + (delta * trackInfo.playbackRate)
                return trackInfo.duration > 0 ? min(live, trackInfo.duration) : live
            }
        }
        return trackInfo.elapsedTime
    }
    
    public var currentLiveProgress: Double {
        if trackInfo.duration > 0 {
            return min(max(currentLiveElapsedTime / trackInfo.duration, 0.0), 1.0)
        }
        return 0.0
    }
    
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
            var pollCounter = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms smooth ticker
                guard let self = self else { return }
                
                // Advance local progress and time dynamically
                if self.trackInfo.isPlaying && self.trackInfo.playbackRate > 0 {
                    let liveTime = self.currentLiveElapsedTime
                    if self.trackInfo.duration > 0 {
                        self.trackInfo.progress = min(max(liveTime / self.trackInfo.duration, 0.0), 1.0)
                    }
                }
                
                // Poll system MediaRemote every 600ms
                pollCounter += 1
                if pollCounter >= 3 {
                    pollCounter = 0
                    self.refresh()
                }
            }
        }
    }
    
    public func refresh() {
        SystemMediaRemote.fetchNowPlayingInfo { [weak self] liveTrack in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let live = liveTrack {
                    self.emptyPollCount = 0
                    var updated = live
                    updated.podcastSpeed = self.trackInfo.podcastSpeed
                    updated.isAutoMixEnabled = self.trackInfo.isAutoMixEnabled
                    updated.airPlayDevice = self.trackInfo.airPlayDevice
                    
                    // Optimistic seek protection: if user scrubbed recently (within 2 seconds), preserve the target seek position
                    let timeSinceSeek = Date().timeIntervalSince(self.lastSeekDate)
                    if timeSinceSeek < 2.0 {
                        updated.elapsedTime = self.pendingSeekTime
                        updated.snapshotTimestamp = self.lastSeekDate
                        if updated.duration > 0 {
                            let seekElapsed = self.pendingSeekTime + (timeSinceSeek * (updated.playbackRate > 0 ? updated.playbackRate : 1.0))
                            updated.progress = min(max(seekElapsed / updated.duration, 0.0), 1.0)
                        }
                    }
                    
                    self.trackInfo = updated
                } else {
                    self.emptyPollCount += 1
                    // Only revert to placeholder after 5 consecutive empty polls (~3 seconds)
                    if self.emptyPollCount >= 5 {
                        self.trackInfo = .placeholder
                    }
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
    
    public func seek(toFraction fraction: Double) {
        let clamped = min(max(fraction, 0.0), 1.0)
        let targetTime = trackInfo.duration > 0 ? (trackInfo.duration * clamped) : (clamped * 100.0)
        
        lastSeekDate = Date()
        pendingSeekTime = targetTime
        
        trackInfo.elapsedTime = targetTime
        trackInfo.progress = clamped
        trackInfo.snapshotTimestamp = Date()
        
        SystemMediaRemote.seek(to: targetTime)
    }
    
    public func seek(toSeconds seconds: Double) {
        let clamped = trackInfo.duration > 0 ? min(max(seconds, 0.0), trackInfo.duration) : max(seconds, 0.0)
        
        lastSeekDate = Date()
        pendingSeekTime = clamped
        
        trackInfo.elapsedTime = clamped
        trackInfo.snapshotTimestamp = Date()
        if trackInfo.duration > 0 {
            trackInfo.progress = min(max(clamped / trackInfo.duration, 0.0), 1.0)
        }
        
        SystemMediaRemote.seek(to: clamped)
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
