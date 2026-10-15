import AppKit
import SwiftUI
import WidgetKit

@MainActor
final class PlayerModel: ObservableObject {
    @Published var playback = Playback(message: "Open Spotify Desktop or connect Spotify in Chrome.")
    @Published var busy = false
    @Published var serverMessage = ""
    @Published var desktopMessage = "Click Connect Spotify Desktop to allow the connection."
    @Published var connectingDesktop = false
    @Published var source = PlaybackSource(rawValue: UserDefaults.standard.string(forKey: "playbackSource") ?? "") ?? .automatic {
        didSet {
            UserDefaults.standard.set(source.rawValue, forKey: "playbackSource")
            selectPlayback()
            Task { await pollDesktop() }
        }
    }
    let browser = BrowserPlayback()
    private let desktop = SpotifyDesktop()
    private var desktopPlayback: Playback?
    private var browserPlayback: Playback?
    private var polling: Task<Void, Never>?
    private var readingDesktop = false
    var activeSource: PlaybackSource? { PlaybackSource.select(preference: source, desktop: desktopPlayback, browser: browserPlayback) }

    func start() {
        browser.onPlayback = { [weak self] value in
            guard let self else { return }
            self.browserPlayback = self.browser.hasPlayer ? value : nil
            self.selectPlayback()
        }
        do { try BrowserConnector.installHost() }
        catch { serverMessage = "Could not install the Chrome connector: " + error.localizedDescription }
        polling = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.browser.expire()
                await self.pollDesktop()
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }

    func connect() {
        do { try BrowserConnector.installHost(); BrowserConnector.installExtension() }
        catch { serverMessage = error.localizedDescription }
    }

    func connectDesktop() async {
        guard !connectingDesktop else { return }
        guard SpotifyDesktop.isInstalled else {
            desktopMessage = "Install Spotify’s desktop app first."
            return
        }
        connectingDesktop = true
        defer { connectingDesktop = false }
        SpotifyDesktop.open()
        for _ in 0..<30 where !SpotifyDesktop.isRunning { try? await Task.sleep(for: .milliseconds(100)) }
        do {
            try await desktop.authorize()
            if source == .browser { source = .desktop }
            await pollDesktop()
        } catch { desktopMessage = error.localizedDescription }
    }

    private func pollDesktop() async {
        guard !readingDesktop else { return }
        guard source != .browser, SpotifyDesktop.isRunning else {
            desktopPlayback = nil
            desktopMessage = SpotifyDesktop.isInstalled ? "Open Spotify Desktop to connect." : "Install Spotify’s desktop app to use it without an extension."
            selectPlayback()
            return
        }
        readingDesktop = true
        defer { readingDesktop = false }
        do {
            desktopPlayback = try await desktop.read()
            desktopMessage = "Spotify Desktop connected."
        } catch {
            desktopPlayback = nil
            desktopMessage = error.localizedDescription
        }
        selectPlayback()
    }

    private func selectPlayback() {
        switch activeSource {
        case .desktop: update(desktopPlayback ?? Playback())
        case .browser: update(browserPlayback ?? Playback())
        default:
            update(Playback(message: source == .desktop ? desktopMessage : source == .browser
                ? "Open Spotify in Chrome and connect the extension." : "Open Spotify Desktop or connect Spotify in Chrome."))
        }
    }

    func openSpotify() {
        if activeSource != nil { Task { await refresh(.show) } }
        else if source == .desktop || (source == .automatic && SpotifyDesktop.isInstalled) { SpotifyDesktop.open() }
        else { BrowserConnector.openSpotify() }
    }

    func refresh(_ command: PlayerCommand? = nil) async {
        if command == .menu {
            // Options stay available while a playback command is in flight.
            playback.optionsVisible = !(playback.optionsVisible ?? false)
            WidgetCenter.shared.reloadTimelines(ofKind: "SpotifyMiniWidget")
            return
        }
        guard let command, !busy else { return }
        busy = true
        defer { busy = false }
        await pollDesktop()
        guard let target = activeSource else {
            if command == .show || command == .toggle {
                if source == .desktop || (source == .automatic && SpotifyDesktop.isInstalled) { SpotifyDesktop.open() }
                else { BrowserConnector.openSpotify() }
            }
            return
        }
        let action: PlayerCommand = command == .toggle && playback.title.isEmpty ? .show : command
        do {
            if target == .desktop {
                if action == .show { SpotifyDesktop.open() }
                else { try await desktop.send(action) }
                await pollDesktop()
            } else { try await browser.send(action) }
            serverMessage = ""
        } catch {
            if target == .browser, (command == .show || command == .toggle),
               let error = error as? URLError, error.code == .resourceUnavailable || error.code == .timedOut {
                BrowserConnector.openSpotify()
            }
            serverMessage = error.localizedDescription
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "SpotifyMiniWidget")
    }

    private func update(_ value: Playback) {
        let previous = playback
        playback = value
        // Keep the widget menu open when the player publishes new metadata.
        playback.optionsVisible = previous.optionsVisible
        let seeked = abs(previous.elapsed(at: Date(timeIntervalSince1970: playback.updated)) - playback.position)
            > (playback.playing ? 3 : 0.5)
        if previous.title != playback.title || previous.artist != playback.artist || previous.artwork != playback.artwork ||
            previous.spotifyURL != playback.spotifyURL || previous.playing != playback.playing || previous.duration != playback.duration ||
            previous.message != playback.message || seeked {
            WidgetCenter.shared.reloadTimelines(ofKind: "SpotifyMiniWidget")
        }
    }
}
