import Foundation
import Network
import Testing

@Test("HTTP authorization and native message framing")
@MainActor
func bridgeProtocolTests() async throws {
    let sample = Data(#"{"title":"A \"song\" 🎵","artist":"Artist","artwork":"","playing":false,"position":50,"duration":100,"canControl":true,"updated":0}"#.utf8)
    let token = "test-local-token"
    func request(_ text: String) -> BridgeRequest? { BridgeRequest(Data(text.utf8)) }
    #expect(request("GET /state HTTP/1.1\r\nHost: 127.0.0.1:49178\r\nX-Mini-Token: \(token)\r\n\r\n")!.authorized(token: token))
    #expect(!request("POST /command/next HTTP/1.1\r\nHost: 127.0.0.1:49178\r\nOrigin: https://example.com\r\nX-Mini-Token: \(token)\r\n\r\n")!.authorized(token: token))
    #expect(!request("GET /state HTTP/1.1\r\nHost: 127.0.0.1:49178\r\nX-Mini-Token: wrong\r\n\r\n")!.authorized(token: token))
    #expect(request("GET /state HTTP/1.1\r\nX-Mini-Token: \(token)\r\nX-Mini-Token: \(token)\r\n\r\n") == nil)
    #expect(request("POST /browser HTTP/1.1\r\nContent-Length: 2\r\n\r\n{") == nil)
    #expect(request("POST /browser HTTP/1.1\r\nContent-Length: 2\r\n\r\n{}")!.body == Data("{}".utf8))
    var parser = NativeFrameParser()
    var length = UInt32(sample.count).littleEndian
    var packet = withUnsafeBytes(of: &length) { Data($0) }; packet.append(sample)
    let partial = try parser.append(Data(packet.prefix(3)))
    let complete = try parser.append(Data(packet.dropFirst(3)))
    #expect(partial.isEmpty && complete == [sample])
    var invalid = NativeFrameParser()
    do { _ = try invalid.append(Data([255,255,255,255])); Issue.record("Oversized frame accepted") }
    catch { }

}

@MainActor
private final class BridgeStartupState {
    var blockerReady = false
}

@Test("The bridge recovers after its port is temporarily occupied")
@MainActor
func bridgeRecoversFromPortConflict() async throws {
    let parameters = NWParameters.tcp
    parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
    let blocker = try NWListener(using: parameters)
    defer { blocker.cancel() }
    blocker.newConnectionHandler = { $0.cancel() }
    let readiness = BridgeStartupState()
    blocker.stateUpdateHandler = { state in
        if state == .ready { Task { @MainActor in readiness.blockerReady = true } }
    }
    blocker.start(queue: .main)
    for _ in 0..<250 where !readiness.blockerReady { try await Task.sleep(for: .milliseconds(20)) }
    try #require(readiness.blockerReady)
    let port = try #require(blocker.port)
    let server = BridgeServer(port: port.rawValue)
    defer { server.stop() }
    var failures = 0
    var recovered = false
    server.onError = { message in
        if message.isEmpty { recovered = true }
        else {
            failures += 1
            blocker.cancel()
        }
    }
    server.start()
    server.start()
    for _ in 0..<300 where !recovered { try await Task.sleep(for: .milliseconds(20)) }
    #expect(failures > 0)
    try #require(recovered)
    let url = try #require(URL(string: "http://127.0.0.1:\(port.rawValue)/state"))
    let (_, response) = try await URLSession.shared.data(from: url)
    // Recovery must keep the existing request authorization in place.
    #expect((response as? HTTPURLResponse)?.statusCode == 403)
}
