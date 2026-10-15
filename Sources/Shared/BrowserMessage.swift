import Foundation

struct BrowserSnapshot: Codable, Sendable {
    let tab: Int
    var playback: Playback
}

struct BrowserMessage: Codable, Sendable {
    var kind: String
    var session: String = ""
    var snapshot: BrowserSnapshot?
    var commandID: String?
    var error: String?
    var tab: Int?
}

struct BrowserCommand: Encodable, Sendable {
    let kind = "command"
    let id: String
    let action: String
    let tab: Int
}
