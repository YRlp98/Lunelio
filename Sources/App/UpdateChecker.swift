import Foundation
import Combine

@MainActor
final class UpdateChecker: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(String)
        case failed(String)
    }

    static let releasesURL = URL(string: "https://github.com/YRlp98/Lunelio/releases/latest")!
    private static let endpoint = URL(string: "https://api.github.com/repos/YRlp98/Lunelio/releases/latest")!

    @Published private(set) var state: State = .idle
    let installedVersion: String
    private let fetch: (URLRequest) async throws -> (Data, URLResponse)

    init(installedVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
         fetch: @escaping (URLRequest) async throws -> (Data, URLResponse) = { request in
             try await URLSession.shared.data(for: request)
         }) {
        self.installedVersion = installedVersion
        self.fetch = fetch
    }

    var isChecking: Bool { state == .checking }

    var resultMessage: String? {
        switch state {
        case .idle, .checking: nil
        case .upToDate: "Lunelio \(installedVersion) is up to date."
        case .available(let version): "Lunelio \(version) is available."
        case .failed(let message): message
        }
    }

    func check() async {
        guard !isChecking else { return }
        guard let installed = Self.components(of: installedVersion) else {
            state = .failed("Couldn’t read the installed Lunelio version.")
            return
        }
        state = .checking
        var request = URLRequest(url: Self.endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Lunelio/\(installedVersion)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await fetch(request)
            guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            let rateLimited = response.statusCode == 429 ||
                (response.statusCode == 403 && response.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0")
            if rateLimited {
                state = .failed("GitHub’s request limit was reached. Try again later.")
                return
            }
            guard response.statusCode == 200 else {
                state = .failed("Couldn’t check GitHub for updates. Try again later.")
                return
            }
            let release = try JSONDecoder().decode(Release.self, from: data)
            let version = release.tag.hasPrefix("v") ? String(release.tag.dropFirst()) : release.tag
            guard !release.draft, !release.prerelease, let latest = Self.components(of: version) else {
                state = .failed("Couldn’t read GitHub’s latest stable release. Try again later.")
                return
            }
            state = installed.lexicographicallyPrecedes(latest) ? .available(version) : .upToDate
        } catch is DecodingError {
            state = .failed("Couldn’t read GitHub’s release information. Try again later.")
        } catch {
            state = .failed("Couldn’t check for updates. Check your internet connection and try again.")
        }
    }

    private static func components(of version: String) -> [Int]? {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        let numbers = parts.compactMap { Int($0) }
        guard parts.count == 3, numbers.count == 3, numbers.allSatisfy({ $0 >= 0 }),
              numbers.map(String.init) == parts.map(String.init) else { return nil }
        return numbers
    }

    private struct Release: Decodable {
        let tag: String
        let draft: Bool
        let prerelease: Bool

        enum CodingKeys: String, CodingKey {
            case tag = "tag_name"
            case draft, prerelease
        }
    }
}
