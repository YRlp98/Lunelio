import Foundation
import Network

@MainActor
final class BridgeServer {
    private let port: UInt16
    private var listener: NWListener?
    private var retryTask: Task<Void, Never>?
    private var connections: [UUID: NWConnection] = [:]
    private var timeouts: [UUID: Task<Void, Never>] = [:]
    var handler: ((PlayerCommand?) async -> Playback)?
    var browserHandler: ((BrowserMessage) async -> Data)?
    var onError: ((String) -> Void)?

    init(port: UInt16 = LocalBridge.port) { self.port = port }

    func start() {
        guard listener == nil, retryTask == nil else { return }
        do {
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
            let listener = try NWListener(using: parameters)
            self.listener = listener
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                Task { @MainActor in
                    guard let self, let listener, self.listener === listener else { return }
                    switch state {
                    case .ready: self.onError?("")
                    case .failed(let error): self.retry(after: error)
                    default: break
                    }
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.accept(connection) }
            }
            listener.start(queue: .main)
        } catch { retry(after: error) }
    }

    private func retry(after error: Error) {
        listener?.cancel()
        listener = nil
        // A brief port conflict at login must not leave the widget disconnected until the app restarts.
        retryTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            self?.retryTask = nil
            self?.start()
        }
        onError?("The widget connection is unavailable: \(error.localizedDescription). Retrying…")
    }

    func stop() {
        retryTask?.cancel()
        retryTask = nil
        listener?.cancel()
        listener = nil
        for id in Array(connections.keys) { finish(id) }
    }

    private func accept(_ connection: NWConnection) {
        guard connections.count < 16 else { connection.cancel(); return }
        let id = UUID()
        connections[id] = connection
        connection.start(queue: .main)
        receive(connection, id: id, accumulated: Data())
        timeouts[id] = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            self?.finish(id)
        }
    }

    private func finish(_ id: UUID) {
        timeouts.removeValue(forKey: id)?.cancel()
        connections.removeValue(forKey: id)?.cancel()
    }

    private func receive(_ connection: NWConnection, id: UUID, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, complete, error in
            Task { @MainActor in
                guard let self, self.connections[id] != nil else { return }
                var buffer = accumulated
                if let data { buffer.append(data) }
                guard error == nil, buffer.count <= 81_920 else { self.finish(id); return }
                if BridgeRequest(buffer) != nil {
                    await self.respond(connection, id: id, buffer: buffer)
                } else if complete { self.finish(id) }
                else { self.receive(connection, id: id, accumulated: buffer) }
            }
        }
    }

    private func respond(_ connection: NWConnection, id: UUID, buffer: Data) async {
        var status = "403 Forbidden"
        var body = Data("{}".utf8)
        if let request = BridgeRequest(buffer), request.authorized(token: LocalBridge.token) {
            let command = PlayerCommand(rawValue: String(request.path.dropFirst("/command/".count)))
            if request.method == "POST", request.path == "/browser",
               let message = try? JSONDecoder().decode(BrowserMessage.self, from: request.body), let browserHandler {
                body = await browserHandler(message); status = "200 OK"
            } else if request.body.isEmpty && ((request.method == "GET" && request.path == "/state") ||
                (request.method == "POST" && request.path.hasPrefix("/command/") && command != nil)) {
                if let handler {
                    let playback = await handler(request.method == "GET" ? nil : command)
                    body = (try? JSONEncoder().encode(playback)) ?? Data("{}".utf8)
                    status = "200 OK"
                } else { status = "503 Service Unavailable" }
            } else { status = "404 Not Found" }
        }
        var response = Data("HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n".utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { [weak self] _ in
            Task { @MainActor in self?.finish(id) }
        })
    }
}
