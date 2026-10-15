import Foundation
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
