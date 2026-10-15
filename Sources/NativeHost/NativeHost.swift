import AppKit

@MainActor
final class NativeHost {
    private var parser = NativeFrameParser()
    private var wait: CheckedContinuation<Void, Never>?
    private var polling: Task<Void, Never>?
    private let session = UUID().uuidString
    private var closing = false

    func run() async {
        guard let idFile = Bundle.main.url(forResource: "extension-id", withExtension: "txt"),
              let id = try? String(contentsOf: idFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              CommandLine.arguments.dropFirst().contains("chrome-extension://\(id)/") else { return }
        // The installed extension can start the companion quietly when Spotify opens.
        let app = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration(); configuration.activates = false
        _ = try? await NSWorkspace.shared.openApplication(at: app, configuration: configuration)
        FileHandle.standardInput.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            Task { @MainActor in await self?.read(data) }
        }
        polling = Task {
            while !Task.isCancelled {
                let data = try? await post(BrowserMessage(kind: "poll", session: session))
                if let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], object["kind"] as? String == "command" { write(data) }
                do { try await Task.sleep(for: .milliseconds(data == nil ? 2000 : 350)) } catch { return }
            }
        }
        await withCheckedContinuation { wait = $0 }
    }

    private func read(_ data: Data) async {
        guard !closing else { return }
        if data.isEmpty { await close(); return }
        do {
            let frames = try parser.append(data)
            for frame in frames {
                var message = try JSONDecoder().decode(BrowserMessage.self, from: frame)
                message.session = session
                if message.kind == "open" {
                    let configuration = NSWorkspace.OpenConfiguration(); configuration.activates = false
                    _ = try? await NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration)
                }
                if message.kind == "snapshot" || message.kind == "ack" || message.kind == "open" || message.kind == "closed" {
                    _ = try? await post(message)
                }
            }
        } catch { await close() }
    }

    private func post(_ message: BrowserMessage) async throws -> Data {
        guard let url = URL(string: "http://127.0.0.1:\(LocalBridge.port)/browser") else { throw URLError(.badURL) }
        var request = URLRequest(url: url, timeoutInterval: 2)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(message)
        request.setValue(LocalBridge.token, forHTTPHeaderField: "X-Mini-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    private func write(_ data: Data) {
        guard data.count <= 1_048_576 else { return }
        var size = UInt32(data.count).littleEndian
        var packet = withUnsafeBytes(of: &size) { Data($0) }; packet.append(data)
        try? FileHandle.standardOutput.write(contentsOf: packet)
    }

    private func close() async {
        guard !closing else { return }; closing = true
        FileHandle.standardInput.readabilityHandler = nil; polling?.cancel()
        _ = try? await post(BrowserMessage(kind: "disconnect", session: session))
        wait?.resume(); wait = nil
    }
}

@main struct NativeHostMain {
    static func main() async { await NativeHost().run() }
}
