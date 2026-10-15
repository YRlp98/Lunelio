import Foundation

struct Playback: Codable, Equatable, Sendable {
    var title = ""
    var artist = ""
    var artwork = ""
    var trackURL: String?
    var optionsVisible: Bool?
    var playing = false
    var position: Double = 0
    var duration: Double = 0
    var canControl = false
    var updated: Double = Date().timeIntervalSince1970
    var message = "Waiting for Spotify connection."

    static func decode(_ data: Data) throws -> Playback {
        // The browser response has no message; normalize it before decoding.
        var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        if object["message"] == nil { object["message"] = "" }
        return try JSONDecoder().decode(Playback.self, from: JSONSerialization.data(withJSONObject: object))
    }

    var displayTitle: String { title.isEmpty ? "Lunelio" : title }
    var displayArtist: String { title.isEmpty ? message : artist }
    var spotifyURL: URL? {
        guard let trackURL, let url = URL(string: trackURL),
              url.scheme == "https", url.host == "open.spotify.com",
              url.user == nil, url.password == nil, url.port == nil else { return nil }
        var parts = url.path.split(separator: "/")
        if parts.first?.hasPrefix("intl-") == true { parts.removeFirst() }
        guard parts.count == 2, parts[0] == "track" || parts[0] == "episode" || parts[0] == "album",
              parts[1].count == 22, parts[1].utf8.allSatisfy({
                  (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
              }) else { return nil }
        return URL(string: "https://open.spotify.com/\(parts[0])/\(parts[1])")
    }
    func elapsed(at date: Date = .now) -> Double {
        guard duration.isFinite, duration > 0, position.isFinite, updated.isFinite else { return 0 }
        let advance = playing ? max(0, date.timeIntervalSince1970 - updated) : 0
        return min(duration, max(0, position + advance))
    }

    var progress: Double { duration > 0 ? elapsed() / duration : 0 }

    var timerInterval: ClosedRange<Date>? {
        guard playing, duration.isFinite, duration > 0, position.isFinite, updated.isFinite else { return nil }
        let start = Date(timeIntervalSince1970: updated - min(duration, max(0, position)))
        return start...start.addingTimeInterval(duration)
    }

    static func timeLabel(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0, seconds < Double(Int.max) else { return "–:––" }
        let value = Int(seconds)
        if value >= 3600 { return String(format: "%d:%02d:%02d", value / 3600, value / 60 % 60, value % 60) }
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
