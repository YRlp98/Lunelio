import Foundation
import AppKit

enum LocalBridge {
    static let port: UInt16 = 49178
    static let nowPlayingURL = URL(string: "spotifymini://now-playing")!
    static let settingsURL = URL(string: "spotifymini://settings")!
    static let openSpotifyURL = URL(string: "spotifymini://open-spotify")!
    static func companionAppURL(for bundleURL: URL) -> URL? {
        var app = bundleURL
        if app.pathExtension == "appex" {
            for _ in 0..<3 { app.deleteLastPathComponent() }
        }
        return app.pathExtension == "app" ? app : nil
    }

    @MainActor static func startCompanion() async throws {
        guard let app = companionAppURL(for: Bundle.main.bundleURL) else { throw CocoaError(.fileNoSuchFile) }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        _ = try await NSWorkspace.shared.openApplication(at: app, configuration: configuration)
    }
    static var token: String {
        guard let url = Bundle.main.url(forResource: "bridge-token", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "" }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func request(_ command: PlayerCommand? = nil) async throws -> Playback {
        guard !token.isEmpty else { throw URLError(.userAuthenticationRequired) }
        let path = command.map { "/command/\($0.rawValue)" } ?? "/state"
        guard let url = URL(string: "http://127.0.0.1:\(port)\(path)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url, timeoutInterval: 12)
        request.httpMethod = command == nil ? "GET" : "POST"
        request.setValue(token, forHTTPHeaderField: "X-Mini-Token")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try Playback.decode(data)
    }
}
