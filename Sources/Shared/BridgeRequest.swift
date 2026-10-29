import Foundation

struct BridgeRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data

    init?(_ data: Data) {
        guard data.count <= 81_920, let boundary = data.range(of: Data("\r\n\r\n".utf8)),
              boundary.lowerBound <= 16_384,
              let string = String(data: data[..<boundary.lowerBound], encoding: .utf8) else { return nil }
        let lines = string.components(separatedBy: "\r\n")
        let first = (lines.first ?? "").split(separator: " ")
        guard first.count == 3, first[2] == "HTTP/1.1" else { return nil }
        method = String(first[0]); path = String(first[1])
        var values: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { return nil }
            let name = line[..<colon].lowercased()
            guard values[name] == nil else { return nil }
            values[name] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        headers = values
        guard let length = Int(values["content-length"] ?? "0"), (0...65_536).contains(length),
              data.count - boundary.upperBound == length else { return nil }
        body = Data(data[boundary.upperBound...])
    }

    func authorized(token: String) -> Bool {
        !token.isEmpty && headers["x-mini-token"] == token
            && ["127.0.0.1:\(LocalBridge.port)", "localhost:\(LocalBridge.port)"].contains(headers["host"] ?? "")
            && headers["origin"] == nil
            && headers["transfer-encoding"] == nil
    }
}
