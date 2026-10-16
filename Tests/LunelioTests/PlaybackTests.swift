import Foundation
import Testing

@Test("Playback decoding, links, timing, and seek targets")
@MainActor
func playbackTests() async throws {
    let sample = Data(#"{"title":"A \"song\" 🎵","artist":"Artist","artwork":"","playing":false,"position":50,"duration":100,"canControl":true,"updated":0}"#.utf8)
    let decoded = try Playback.decode(sample)
    #expect(decoded.title == "A \"song\" 🎵" && decoded.progress == 0.5 && decoded.message == "")
    #expect(decoded.trackURL == nil && decoded.spotifyURL == nil)
    #expect(decoded.optionsVisible == nil)
    var options = decoded; options.optionsVisible = true
    let decodedOptions = try Playback.decode(JSONEncoder().encode(options))
    #expect(decodedOptions.optionsVisible == true)
    let appURL = URL(fileURLWithPath: "/Applications/Lunelio.app")
    #expect(LocalBridge.companionAppURL(for: appURL) == appURL)
    #expect(LocalBridge.companionAppURL(for: appURL.appendingPathComponent("Contents/PlugIns/SpotifyMiniWidget.appex"))?.path == appURL.path)
    #expect(LocalBridge.companionAppURL(for: URL(fileURLWithPath: "/tmp/Checks")) == nil)
    let track = "https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC"
    #expect(Playback(trackURL: track + "?si=example").spotifyURL?.absoluteString == track)
    #expect(Playback(trackURL: track.replacingOccurrences(of: "/track/", with: "/intl-de/track/")).spotifyURL?.absoluteString == track)
    #expect(Playback(trackURL: track.replacingOccurrences(of: "/track/", with: "/episode/")).spotifyURL != nil)
    #expect(Playback(trackURL: track.replacingOccurrences(of: "/track/", with: "/album/")).spotifyURL != nil)
    for invalid in ["https://example.com/track/4uLU6hMCjMI75M1A2tKUQC", "javascript:alert(1)",
                    "https://open.spotify.com/playlist/4uLU6hMCjMI75M1A2tKUQC", "https://open.spotify.com/track/short",
                    "https://user@open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC"] {
        #expect(Playback(trackURL: invalid).spotifyURL == nil)
    }
    #expect(Playback(position: -10, duration: 100).progress == 0)
    #expect(Playback(position: 110, duration: 100).progress == 1)
    #expect(Playback(duration: 0).progress == 0)
    let clock = Date(timeIntervalSince1970: 1000)
    var timed = Playback(playing: true, position: 65, duration: 200, updated: 990)
    #expect(timed.elapsed(at: clock) == 75)
    #expect(timed.timerInterval == Date(timeIntervalSince1970: 925)...Date(timeIntervalSince1970: 1125))
    #expect(timed.elapsed(at: Date(timeIntervalSince1970: 2000)) == 200)
    timed.playing = false
    #expect(timed.elapsed(at: clock) == 65 && timed.timerInterval == nil)
    #expect(Playback(playing: true, position: 0, duration: 0).timerInterval == nil)
    #expect(Playback(playing: true, position: 0, duration: 20, updated: 1010).elapsed(at: clock) == 0)
    #expect(Playback.timeLabel(0) == "0:00" && Playback.timeLabel(65.9) == "1:05")
    #expect(Playback.timeLabel(3723) == "1:02:03" && Playback.timeLabel(.infinity) == "–:––")
    #expect(PlayerCommand.seekSteps.compactMap(\.seekPercent) == Array(stride(from: 0, through: 100, by: 10)))
    for invalid in ["seek-10", "seek1", "seek01", "seek37", "seek99", "seek101", "seek110", "seek200", "seekNaN", "seek50/next"] {
        #expect(PlayerCommand(rawValue: invalid) == nil)
    }

}

@Test("Widget options toggle while playback is busy and with no connected player")
@MainActor
func optionsRemainAvailable() async {
    let model = PlayerModel()
    model.playback = Playback(title: "Current song", playing: true, position: 30, duration: 120, canControl: true)
    model.busy = true
    await model.refresh(.menu)
    #expect(model.playback.optionsVisible == true)
    #expect(model.playback.title == "Current song" && model.playback.position == 30 && model.playback.playing)
    #expect(model.busy)
    await model.refresh(.menu)
    #expect(model.playback.optionsVisible == false)
    #expect(model.busy)
    model.playback = Playback()
    model.busy = false
    await model.refresh(.menu)
    #expect(model.playback.optionsVisible == true)
    #expect(!model.playback.canControl)
    await model.refresh(.menu)
    #expect(model.playback.optionsVisible == false)
}
