import AppKit
import Carbon

// Apple events can wait on another process. Keep their descriptors and execution
// on one serial executor rather than blocking the app's UI or widget server.
actor SpotifyDesktop {
    static let bundleID = "com.spotify.client"

    enum ConnectionError: LocalizedError {
        case permissionRequired, permissionDenied, unavailable, invalidSnapshot
        case script(String)

        var errorDescription: String? {
            switch self {
            case .permissionRequired: "Click Connect Spotify Desktop in Settings to allow the connection."
            case .permissionDenied: "Allow Lunelio to control Spotify in System Settings → Privacy & Security → Automation."
            case .unavailable: "Open Spotify Desktop to connect."
            case .invalidSnapshot: "Spotify Desktop returned incomplete playback information."
            case .script(let message): "Spotify Desktop: \(message)"
            }
        }
    }

    func authorize() throws {
        // A real read lets macOS show its consent prompt and verifies access.
        // Background reads only check permission and never request it.
        _ = try execute("get player state")
    }

    func read() throws -> Playback {
        try checkPermission()
        let result = try execute("""
            if current track is missing value then return {}
            return {name of current track, artist of current track, artwork url of current track, spotify url of current track, duration of current track, player position, player state as text}
            """)
        return try Self.decode(result)
    }

    func send(_ action: PlayerCommand) throws {
        try checkPermission()
        guard let command = Self.script(for: action) else { return }
        _ = try execute(command)
    }

    private func checkPermission() throws {
        let target = NSAppleEventDescriptor(bundleIdentifier: Self.bundleID)
        let status = AEDeterminePermissionToAutomateTarget(target.aeDesc, kCoreEventClass, kAEGetData, false)
        switch status {
        case noErr: return
        case -1744: throw ConnectionError.permissionRequired
        case -1743: throw ConnectionError.permissionDenied
        case -600: throw ConnectionError.unavailable
        default: throw ConnectionError.script("Connection failed (\(status)).")
        }
    }

    private func execute(_ command: String) throws -> NSAppleEventDescriptor {
        let source = """
            if application id "com.spotify.client" is not running then error "Open Spotify Desktop to connect." number -600
            with timeout of 5 seconds
                tell application id "com.spotify.client"
                    \(command)
                end tell
            end timeout
            """
        guard let script = NSAppleScript(source: source) else { throw ConnectionError.invalidSnapshot }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let number = error[NSAppleScript.errorNumber] as? Int
            if number == -1743 { throw ConnectionError.permissionDenied }
            if number == -600 { throw ConnectionError.unavailable }
            throw ConnectionError.script(error[NSAppleScript.errorMessage] as? String ?? "Could not read or control the player.")
        }
        return result
    }

    nonisolated static func decode(_ result: NSAppleEventDescriptor) throws -> Playback {
        guard result.descriptorType == typeAEList else { throw ConnectionError.invalidSnapshot }
        if result.numberOfItems == 0 { return Playback(canControl: true, message: "Choose a song in Spotify Desktop.") }
        guard result.numberOfItems == 7,
              let title = result.atIndex(1)?.stringValue,
              let artist = result.atIndex(2)?.stringValue,
              let artwork = result.atIndex(3)?.stringValue,
              let uri = result.atIndex(4)?.stringValue,
              let duration = result.atIndex(5)?.doubleValue,
              let position = result.atIndex(6)?.doubleValue,
              let state = result.atIndex(7)?.stringValue,
              duration.isFinite, duration >= 0, position.isFinite, position >= 0,
              ["playing", "paused", "stopped"].contains(state) else { throw ConnectionError.invalidSnapshot }
        // Spotify's scripting implementation returns duration in milliseconds,
        // despite its dictionary describing seconds. Position is in seconds.
        let seconds = duration / 1000
        return Playback(title: title, artist: artist, artwork: artwork,
                        trackURL: webURL(from: uri), playing: state == "playing",
                        position: min(position, seconds), duration: seconds,
                        canControl: true, message: title.isEmpty ? "Choose a song in Spotify Desktop." : "")
    }

    nonisolated static func webURL(from uri: String) -> String? {
        let parts = uri.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "spotify" else { return Playback(trackURL: uri).spotifyURL?.absoluteString }
        return Playback(trackURL: "https://open.spotify.com/\(parts[1])/\(parts[2])").spotifyURL?.absoluteString
    }

    nonisolated static func script(for action: PlayerCommand) -> String? {
        if let percent = action.seekPercent {
            // Read the live track length when seeking, never a cached widget value.
            return "if current track is not missing value then set player position to ((duration of current track) / 1000.0 * \(percent) / 100.0)"
        }
        switch action {
        case .toggle: return "playpause"
        case .previous: return "previous track"
        case .next: return "next track"
        default: return nil
        }
    }

    @MainActor static var isRunning: Bool { !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty }
    @MainActor static var isInstalled: Bool { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil }

    @MainActor static func open() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }
}
