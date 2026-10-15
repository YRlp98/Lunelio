import AppKit

@MainActor
enum BrowserConnector {
    static let hostName = "local.spotifymini.bridge"
    static var storeURL: URL? {
        guard let file = Bundle.main.url(forResource: "extension-store-url", withExtension: "txt"),
              let value = try? String(contentsOf: file, encoding: .utf8),
              let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", url.host == "chromewebstore.google.com" else { return nil }
        return url
    }

    static func installHost() throws {
        guard let executable = Bundle.main.executableURL,
              let idURL = Bundle.main.url(forResource: "extension-id", withExtension: "txt") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let extensionID = try String(contentsOf: idURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
        guard extensionID.count == 32, extensionID.allSatisfy({ ("a"..."p").contains(String($0)) }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Google/Chrome/NativeMessagingHosts")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let manifest: [String: Any] = ["name": hostName, "description": "Lunelio connection for this Mac",
            "path": executable.deletingLastPathComponent().appendingPathComponent("SpotifyMiniBridge").path,
            "type": "stdio", "allowed_origins": ["chrome-extension://\(extensionID)/"]]
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: folder.appendingPathComponent("\(hostName).json"), options: .atomic)
    }

    static func openSpotify() {
        let pwa = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Chrome Apps.localized/Spotify.app")
        if FileManager.default.fileExists(atPath: pwa.path) { NSWorkspace.shared.openApplication(at: pwa, configuration: .init()) }
        else if let url = URL(string: "https://open.spotify.com") { NSWorkspace.shared.open(url) }
    }

    static func installExtension() {
        if let url = storeURL {
            NSWorkspace.shared.open(url)
        } else if let folder = Bundle.main.resourceURL?.appendingPathComponent("ChromeExtension") {
            NSWorkspace.shared.activateFileViewerSelecting([folder])
        }
    }
}
