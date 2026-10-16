import Foundation
import JavaScriptCore
import Testing

@Test("Profile selection, delivery, acknowledgements, and disconnect")
@MainActor
func browserPlaybackTests() async throws {
    let sample = Data(#"{"title":"A \"song\" 🎵","artist":"Artist","artwork":"","playing":false,"position":50,"duration":100,"canControl":true,"updated":0}"#.utf8)
    let decoded = try Playback.decode(sample)
    let browser = BrowserPlayback()
    #expect(!browser.hasPlayer)
    var current = Playback()
    browser.onPlayback = { current = $0 }
    _ = browser.receive(BrowserMessage(kind: "snapshot", session: "profile-a", snapshot: BrowserSnapshot(tab: 7, playback: decoded)))
    #expect(current.title == decoded.title)
    #expect(browser.hasPlayer)
    var playing = decoded; playing.title = "Playing"; playing.playing = true
    _ = browser.receive(BrowserMessage(kind: "snapshot", session: "profile-b", snapshot: BrowserSnapshot(tab: 9, playback: playing)))
    #expect(current.title == "Playing")
    async let operation: Void = browser.send(.next)
    try await Task.sleep(for: .milliseconds(30))
    let wrongSession = browser.receive(BrowserMessage(kind: "poll", session: "profile-a"))
    #expect(wrongSession == Data("{}".utf8))
    let data = browser.receive(BrowserMessage(kind: "poll", session: "profile-b"))
    let command = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(command["action"] as? String == "next" && command["tab"] as? Int == 9)
    #expect(browser.receive(BrowserMessage(kind: "poll", session: "profile-b")) == Data("{}".utf8))
    _ = browser.receive(BrowserMessage(kind: "ack", session: "profile-b", commandID: command["id"] as? String))
    try await operation
    _ = browser.receive(BrowserMessage(kind: "disconnect", session: "profile-b"))
    #expect(current.title == decoded.title)
    var unavailable = decoded; unavailable.canControl = false
    _ = browser.receive(BrowserMessage(kind: "snapshot", session: "profile-a", snapshot: BrowserSnapshot(tab: 7, playback: unavailable)))
    async let show: Void = browser.send(.show)
    try await Task.sleep(for: .milliseconds(30))
    let showData = browser.receive(BrowserMessage(kind: "poll", session: "profile-a"))
    let showCommand = try JSONSerialization.jsonObject(with: showData) as! [String: Any]
    #expect(showCommand["action"] as? String == "show" && showCommand["tab"] as? Int == 7)
    _ = browser.receive(BrowserMessage(kind: "ack", session: "profile-a", commandID: showCommand["id"] as? String))
    try await show
    do { try await browser.send(.seek50); Issue.record("Unavailable player accepted seek") }
    catch { }
    _ = browser.receive(BrowserMessage(kind: "snapshot", session: "profile-a", snapshot: BrowserSnapshot(tab: 7, playback: decoded)))
    async let seek: Void = browser.send(.seek50)
    try await Task.sleep(for: .milliseconds(30))
    let seekData = browser.receive(BrowserMessage(kind: "poll", session: "profile-a"))
    let seekCommand = try JSONSerialization.jsonObject(with: seekData) as! [String: Any]
    #expect(seekCommand["action"] as? String == "seek50" && seekCommand["tab"] as? Int == 7)
    _ = browser.receive(BrowserMessage(kind: "ack", session: "profile-a", commandID: seekCommand["id"] as? String))
    try await seek
    async let closedPlayer: Void = browser.send(.show)
    try await Task.sleep(for: .milliseconds(30))
    let closedData = browser.receive(BrowserMessage(kind: "poll", session: "profile-a"))
    let closedCommand = try JSONSerialization.jsonObject(with: closedData) as! [String: Any]
    _ = browser.receive(BrowserMessage(kind: "ack", session: "profile-a", commandID: closedCommand["id"] as? String, error: "player-unavailable"))
    do { try await closedPlayer; Issue.record("Closed player accepted show") }
    catch let error as URLError { #expect(error.code == .resourceUnavailable) }
    #expect(!browser.hasPlayer && current.title.isEmpty)
    _ = browser.receive(BrowserMessage(kind: "snapshot", session: "profile-a", snapshot: BrowserSnapshot(tab: 7, playback: decoded)))
    _ = browser.receive(BrowserMessage(kind: "closed", session: "other-profile", tab: 7))
    #expect(browser.hasPlayer)
    _ = browser.receive(BrowserMessage(kind: "closed", session: "profile-a", tab: -1))
    #expect(browser.hasPlayer)
    _ = browser.receive(BrowserMessage(kind: "closed", session: "profile-a", tab: 7))
    #expect(!browser.hasPlayer && current.title.isEmpty)

}

@Test("Browser artwork selects larger covers without mixing songs or degrading the thumbnail")
@MainActor
func browserArtworkTests() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let source = try String(contentsOf: root.appendingPathComponent("BrowserExtension/player.js"), encoding: .utf8)
    let thumbnail = "https://i.scdn.co/thumbnail.jpg"
    let large = "https://i.scdn.co/large.jpg"
    let medium = "https://i.scdn.co/medium.jpg"
    let cases: [(String, Int, String, [[String: String]], String)] = [
        (thumbnail, 64, "Song", [["src": medium, "sizes": "300x300"], ["src": large, "sizes": "640x640"]], large),
        (thumbnail, 640, "Song", [["src": medium, "sizes": "300x300"]], thumbnail),
        (thumbnail, 64, "Previous song", [["src": large, "sizes": "640x640"]], thumbnail),
        (thumbnail, 64, "Song", [], thumbnail),
        (thumbnail, 64, "Song", [["src": large, "sizes": "invalid any"], ["src": "", "sizes": "640x640"]], thumbnail),
        (thumbnail, 64, "Song", [["src": large, "sizes": "32x32 512X512"], ["src": medium, "sizes": "300x300"]], large),
        ("", 0, "Song", [["src": large]], large),
        ("", 0, "Song", [], "")
    ]
    for (thumbnail, width, metadataTitle, artwork, expected) in cases {
        let fixture: [String: Any] = ["thumbnail": thumbnail, "width": width, "metadataTitle": metadataTitle, "artwork": artwork]
        let json = String(decoding: try JSONSerialization.data(withJSONObject: fixture), as: UTF8.self)
        let context = try #require(JSContext())
        context.evaluateScript("""
            const fixture = \(json);
            const cover = { src: fixture.thumbnail, currentSrc: fixture.thumbnail,
              naturalWidth: fixture.width, naturalHeight: fixture.width };
            const title = { textContent: 'Song', closest: () => null };
            const root = {
              querySelector: selector => selector === 'img' ? cover :
                selector === '[data-testid="context-item-info-title"]' ? title : null,
              querySelectorAll: () => []
            };
            const document = {
              querySelector: selector => selector === '[data-testid="now-playing-bar"]' ? root : null,
              querySelectorAll: () => []
            };
            const navigator = { mediaSession: { metadata: {
              title: fixture.metadataTitle, artist: 'Artist', artwork: fixture.artwork
            } } };
            """)
        let result = context.evaluateScript(source)
        #expect(context.exception == nil, "\(context.exception?.toString() ?? "")")
        let data = Data(try #require(result?.toString()).utf8)
        let playback = try Playback.decode(data)
        #expect(playback.artwork == expected)
    }
}
