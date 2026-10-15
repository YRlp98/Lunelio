import Foundation
import Testing

@Test("HTTP authorization and native message framing")
@MainActor
func bridgeProtocolTests() async throws {
    let sample = Data(#"{"title":"A \"song\" 🎵","artist":"Artist","artwork":"","playing":false,"position":50,"duration":100,"canControl":true,"updated":0}"#.utf8)
    let token = "test-local-token"
    func request(_ text: String) -> BridgeRequest? { BridgeRequest(Data(text.utf8)) }
    #expect(request("GET /state HTTP/1.1\r\nX-Mini-Token: \(token)\r\n\r\n")!.authorized(token: token))
    #expect(!request("POST /command/next HTTP/1.1\r\nOrigin: https://example.com\r\nX-Mini-Token: \(token)\r\n\r\n")!.authorized(token: token))
    #expect(!request("GET /state HTTP/1.1\r\nX-Mini-Token: wrong\r\n\r\n")!.authorized(token: token))
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
