import Foundation

@MainActor
final class BrowserPlayback {
    private var snapshots: [String: BrowserSnapshot] = [:]
    private var active: String?
    var hasPlayer: Bool { active != nil }
    private var pending: (session: String, command: BrowserCommand, sent: Bool)?
    private var completion: CheckedContinuation<Void, any Error>?
    var onPlayback: ((Playback) -> Void)?
    var onOpen: (() -> Void)?
    var onError: ((String) -> Void)?

    func receive(_ message: BrowserMessage) -> Data {
        guard !message.session.isEmpty, message.session.count < 100 else { return Data("{}".utf8) }
        if message.kind == "snapshot", var snapshot = message.snapshot {
            let state = snapshot.playback
            guard snapshot.tab >= 0, state.title.count <= 4096, state.artist.count <= 4096,
                  state.artwork.count <= 4096, (state.trackURL?.count ?? 0) <= 4096,
                  state.duration.isFinite, state.position.isFinite,
                  state.duration >= 0, state.position >= 0 else { return Data("{}".utf8) }
            snapshot.playback.updated = Date().timeIntervalSince1970
            snapshot.playback.message = state.title.isEmpty ? "Choose a song in Spotify." : ""
            snapshots["\(message.session):\(snapshot.tab)"] = snapshot
            selectPlayback()
        } else if message.kind == "poll" {
            if var pending, pending.session == message.session, !pending.sent {
                pending.sent = true; self.pending = pending
                return (try? JSONEncoder().encode(pending.command)) ?? Data("{}".utf8)
            }
        } else if message.kind == "ack", message.commandID == pending?.command.id {
            if let pending, pending.session == message.session {
                self.pending = nil
                let continuation = completion; completion = nil
                if message.error == "player-unavailable" {
                    snapshots.removeValue(forKey: "\(message.session):\(pending.command.tab)")
                    selectPlayback()
                    continuation?.resume(throwing: URLError(.resourceUnavailable))
                } else if let error = message.error, !error.isEmpty {
                    continuation?.resume(throwing: NSError(domain: "SpotifyMini", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Spotify could not use that control: \(String(error.prefix(180)))"]))
                } else { continuation?.resume() }
            }
        } else if message.kind == "closed", let tab = message.tab, tab >= 0 {
            snapshots.removeValue(forKey: "\(message.session):\(tab)")
            selectPlayback()
        } else if message.kind == "disconnect" {
            snapshots = snapshots.filter { !$0.key.hasPrefix(message.session + ":") }
            selectPlayback()
        } else if message.kind == "open" { onOpen?() }
        return Data("{}".utf8)
    }

    func expire() {
        snapshots = snapshots.filter { Date().timeIntervalSince1970 - $0.value.playback.updated < 90 }
        selectPlayback()
    }

    private func selectPlayback() {
        let best = snapshots.max { left, right in
            let l = left.value.playback, r = right.value.playback
            if l.playing != r.playing { return !l.playing }
            if l.title.isEmpty != r.title.isEmpty { return l.title.isEmpty }
            return l.updated < r.updated
        }
        active = best?.key
        onPlayback?(best?.value.playback ?? Playback(message: "Reload Spotify in Chrome to connect."))
    }

    func send(_ action: PlayerCommand) async throws {
        guard pending == nil, let active, let snapshot = snapshots[active],
              action == .show || snapshot.playback.canControl,
              let separator = active.lastIndex(of: ":") else {
            throw NSError(domain: "SpotifyMini", code: 2, userInfo: [NSLocalizedDescriptionKey: "Open Spotify and connect the Chrome extension first."])
        }
        let id = UUID().uuidString
        pending = (String(active[..<separator]), BrowserCommand(id: id, action: action.rawValue, tab: snapshot.tab), false)
        let timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(8)) } catch { return }
            guard let self, self.pending?.command.id == id else { return }
            self.pending = nil
            let continuation = self.completion; self.completion = nil
            continuation?.resume(throwing: URLError(.timedOut))
        }
        defer { timeout.cancel() }
        try await withCheckedThrowingContinuation { completion = $0 }
    }
}
