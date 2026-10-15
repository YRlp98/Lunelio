import Foundation

enum PlaybackSource: String, CaseIterable, Identifiable, Sendable {
    case automatic, desktop, browser
    var id: String { rawValue }
    var label: String {
        switch self {
        case .automatic: "Automatic"
        case .desktop: "Spotify Desktop"
        case .browser: "Spotify in Chrome"
        }
    }

    static func select(preference: Self, desktop: Playback?, browser: Playback?) -> Self? {
        switch preference {
        case .desktop: return desktop == nil ? nil : .desktop
        case .browser: return browser == nil ? nil : .browser
        case .automatic:
            // Desktop wins ties, so mirrored Spotify Connect states don't make
            // commands jump between the app and browser on every update.
            if desktop?.playing == true { return .desktop }
            if browser?.playing == true { return .browser }
            if desktop?.title.isEmpty == false { return .desktop }
            if browser?.title.isEmpty == false { return .browser }
            if desktop != nil { return .desktop }
            return browser == nil ? nil : .browser
        }
    }
}
