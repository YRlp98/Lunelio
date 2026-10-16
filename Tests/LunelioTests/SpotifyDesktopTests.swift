import Foundation
import Testing

@Test("Desktop metadata, duration units, safe links, and seek commands")
func spotifyDesktopTests() throws {
    func snapshot(_ duration: Double = 180_000, position: Double = 45, state: String = "playing") -> NSAppleEventDescriptor {
        let descriptor = NSAppleEventDescriptor.list()
        let values: [NSAppleEventDescriptor] = [
            .init(string: "A \"song\" 🎵"), .init(string: "Artist"),
            .init(string: "https://example.org/cover.png"), .init(string: "spotify:track:4uLU6hMCjMI75M1A2tKUQC"),
            .init(double: duration), .init(double: position), .init(string: state)
        ]
        for (index, value) in values.enumerated() { descriptor.insert(value, at: index + 1) }
        return descriptor
    }
    let playback = try SpotifyDesktop.decode(snapshot())
    #expect(playback.title == "A \"song\" 🎵")
    #expect(playback.duration == 180 && playback.position == 45)
    #expect(playback.playing && playback.canControl)
    #expect(playback.spotifyURL?.absoluteString == "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC")
    #expect(try SpotifyDesktop.decode(snapshot(position: 200)).position == 180)
    #expect(try !SpotifyDesktop.decode(snapshot(state: "paused")).playing)
    #expect(try SpotifyDesktop.decode(NSAppleEventDescriptor.list()).title.isEmpty)
    #expect(throws: SpotifyDesktop.ConnectionError.self) { try SpotifyDesktop.decode(.init(string: "invalid")) }
    #expect(throws: SpotifyDesktop.ConnectionError.self) { try SpotifyDesktop.decode(snapshot(-1)) }
    #expect(throws: SpotifyDesktop.ConnectionError.self) { try SpotifyDesktop.decode(snapshot(position: -1)) }
    #expect(throws: SpotifyDesktop.ConnectionError.self) { try SpotifyDesktop.decode(snapshot(state: "invalid")) }
    #expect(SpotifyDesktop.webURL(from: "spotify:track:invalid") == nil)
    #expect(SpotifyDesktop.webURL(from: "spotify:track:../../bad") == nil)
    #expect(SpotifyDesktop.webURL(from: "https://example.org/track/4uLU6hMCjMI75M1A2tKUQC") == nil)
    #expect(SpotifyDesktop.script(for: .toggle) == "playpause")
    #expect(SpotifyDesktop.script(for: .show) == nil)
    #expect(SpotifyDesktop.script(for: .seek50)?.contains("duration of current track") == true)
    #expect(SpotifyDesktop.script(for: .seek50)?.contains("* 50 / 100.0") == true)
    #expect(SpotifyDesktop.script(for: .seek0)?.contains("* 0 / 100.0") == true)
    #expect(SpotifyDesktop.script(for: .seek100)?.contains("* 100 / 100.0") == true)
}

@Test("Desktop and browser source selection honors preference and playback state")
func playbackSourceTests() {
    let desktop = Playback(title: "Desktop", playing: true, canControl: true)
    let browser = Playback(title: "Browser", playing: true, canControl: true)
    #expect(PlaybackSource.select(preference: .automatic, desktop: desktop, browser: browser) == .desktop)
    var paused = desktop; paused.playing = false
    #expect(PlaybackSource.select(preference: .automatic, desktop: paused, browser: browser) == .browser)
    #expect(PlaybackSource.select(preference: .desktop, desktop: paused, browser: browser) == .desktop)
    #expect(PlaybackSource.select(preference: .browser, desktop: desktop, browser: browser) == .browser)
    #expect(PlaybackSource.select(preference: .desktop, desktop: nil, browser: browser) == nil)
    #expect(PlaybackSource.select(preference: .automatic, desktop: nil, browser: browser) == .browser)
    #expect(PlaybackSource.select(preference: .automatic, desktop: desktop, browser: nil) == .desktop)
    #expect(PlaybackSource.select(preference: .automatic, desktop: nil, browser: nil) == nil)
    #expect(PlaybackSource.select(preference: .automatic, desktop: Playback(), browser: browser) == .browser)
}
