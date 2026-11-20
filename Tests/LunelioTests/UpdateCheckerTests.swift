import Foundation
import Testing

private func releaseResponse(_ request: URLRequest, tag: String, status: Int = 200,
                             draft: Bool = false, prerelease: Bool = false) throws -> (Data, URLResponse) {
    let data = try JSONSerialization.data(withJSONObject: ["tag_name": tag, "draft": draft, "prerelease": prerelease])
    let url = try #require(request.url)
    let response = try #require(HTTPURLResponse(url: url, statusCode: status,
                                              httpVersion: nil, headerFields: ["X-RateLimit-Remaining": "0"]))
    return (data, response)
}

@Test("Newer releases compare major, minor, and patch numbers", arguments: ["v1.9.4", "v1.10.0", "v2.0.0", "1.10.0"])
@MainActor
func newerReleaseVersions(tag: String) async throws {
    let checker = UpdateChecker(installedVersion: "1.9.3") { request in
        #expect(request.url?.absoluteString == "https://api.github.com/repos/YRlp98/Lunelio/releases/latest")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "Lunelio/1.9.3")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData && request.timeoutInterval == 10)
        return try releaseResponse(request, tag: tag)
    }
    await checker.check()
    let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    #expect(checker.state == .available(version))
}

@Test("Current or older releases do not offer a downgrade", arguments: ["v1.9.3", "v1.9.2", "v1.8.30", "v0.3.0"])
@MainActor
func currentReleaseVersions(tag: String) async throws {
    let checker = UpdateChecker(installedVersion: "1.9.3") { try releaseResponse($0, tag: tag) }
    await checker.check()
    #expect(checker.state == .upToDate)
}

@Test("Invalid release versions cannot report a successful check", arguments: [
    "v1.2", "latest", "v1.0.2-beta", "v01.0.2", "v1.0.-1", "v1.0.2/other", "v9999999999999999999999.0.0"
])
@MainActor
func invalidReleaseVersions(tag: String) async throws {
    let checker = UpdateChecker(installedVersion: "1.0.1") { try releaseResponse($0, tag: tag) }
    await checker.check()
    guard case .failed = checker.state else { Issue.record("Invalid release was accepted"); return }
}

@Test("Draft and prerelease metadata cannot offer a stable update", arguments: [true, false])
@MainActor
func unpublishedReleases(draft: Bool) async throws {
    let checker = UpdateChecker(installedVersion: "1.0.1") {
        try releaseResponse($0, tag: "v1.0.2", draft: draft, prerelease: !draft)
    }
    await checker.check()
    guard case .failed = checker.state else { Issue.record("Unpublished stable release was accepted"); return }
}

@Test("HTTP failures remain actionable", arguments: [403, 429, 404, 500])
@MainActor
func updateHTTPFailures(status: Int) async throws {
    let checker = UpdateChecker(installedVersion: "1.0.1") { try releaseResponse($0, tag: "v1.0.2", status: status) }
    await checker.check()
    guard case .failed(let message) = checker.state else { Issue.record("HTTP failure was reported as success"); return }
    #expect(!message.isEmpty)
    if status == 403 || status == 429 { #expect(message.contains("request limit")) }
}

@Test("Checks start on request and can retry after a network failure")
@MainActor
func retryUpdateCheck() async throws {
    var requests = 0
    let checker = UpdateChecker(installedVersion: "1.0.1") { request in
        requests += 1
        if requests == 1 { throw URLError(.notConnectedToInternet) }
        return try releaseResponse(request, tag: "v1.0.1")
    }
    #expect(requests == 0 && checker.state == .idle)
    await checker.check()
    guard case .failed = checker.state else { Issue.record("Network failure was reported as success"); return }
    await checker.check()
    #expect(requests == 2 && checker.state == .upToDate)
}

@Test("Repeated clicks share the in-flight update check")
@MainActor
func concurrentUpdateChecks() async throws {
    var requests = 0
    let checker = UpdateChecker(installedVersion: "1.0.1") { request in
        requests += 1
        try await Task.sleep(for: .milliseconds(100))
        return try releaseResponse(request, tag: "v1.0.2")
    }
    let first = Task { await checker.check() }
    for _ in 0..<100 where !checker.isChecking { await Task.yield() }
    #expect(checker.isChecking)
    await checker.check()
    await first.value
    #expect(requests == 1 && checker.state == .available("1.0.2"))
}

@Test("Malformed release metadata produces a recoverable error")
@MainActor
func invalidReleaseResponse() async throws {
    let checker = UpdateChecker(installedVersion: "1.0.1") { request in
        let (_, response) = try releaseResponse(request, tag: "v1.0.2")
        return (Data("{}".utf8), response)
    }
    await checker.check()
    guard case .failed = checker.state else { Issue.record("Missing release metadata was accepted"); return }
}
