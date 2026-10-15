import Foundation
import AppIntents
import WidgetKit

struct PlaybackIntent: AppIntent {
    static let title: LocalizedStringResource = "Control Spotify"
    static let openAppWhenRun = false
    @Parameter(title: "Command") var command: String

    init() { command = "toggle" }
    init(_ value: PlayerCommand) { command = value.rawValue }

    func perform() async throws -> some IntentResult {
        guard let action = PlayerCommand(rawValue: command) else { throw URLError(.badURL) }
        var lastError: (any Error)?
        for attempt in 0..<8 {
            do {
                _ = try await LocalBridge.request(action)
                WidgetCenter.shared.reloadTimelines(ofKind: "SpotifyMiniWidget")
                return .result()
            } catch {
                lastError = error
                // Never retry a command after it might have reached the player.
                guard let error = error as? URLError, error.code == .cannotConnectToHost else { throw error }
                if attempt == 0 { try await LocalBridge.startCompanion() }
                try await Task.sleep(for: .milliseconds(300))
            }
        }
        throw lastError ?? URLError(.cannotConnectToHost)
    }
}
