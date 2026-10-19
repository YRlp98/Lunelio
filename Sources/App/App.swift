import AppKit
import SwiftUI
import WidgetKit
import ServiceManagement


struct SetupView: View {
    @ObservedObject var model: PlayerModel
    let onHideMenuBarIconChange: (Bool) -> Void
    @AppStorage("hideMenuBarIcon") private var hideMenuBarIcon = false
    @State private var loginError = ""
    @State private var login = SMAppService.mainApp.status == .enabled

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                if let url = Bundle.main.url(forResource: "BrandMark", withExtension: "png"),
                   let image = NSImage(contentsOf: url) {
                    Image(nsImage: image).resizable().scaledToFit()
                        .frame(width: 40, height: 40).accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lunelio").font(.system(size: 26, weight: .semibold))
                    Text("Your music, within reach.").foregroundStyle(.secondary)
                    if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleGetInfoString") as? String {
                        Text("Version \(version)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Text("Choose how Spotify connects.").font(.headline)
            Picker("Music source", selection: $model.source) {
                ForEach(PlaybackSource.allCases) { Text($0.label).tag($0) }
            }
            Text("Automatic uses the playing source. If both are playing, Spotify Desktop takes priority.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                Text("Spotify Desktop · No extension needed").font(.headline)
                Text("Open the Spotify app, click Connect, and allow Lunelio to control Spotify when macOS asks.")
                    .fixedSize(horizontal: false, vertical: true)
                Button("Connect Spotify Desktop") { Task { await model.connectDesktop() } }
                    .disabled(model.connectingDesktop)
                Text(model.desktopMessage).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                Text("Spotify in Chrome · Browser connector").font(.headline)
                Text(BrowserConnector.storeURL == nil ? "Add the Chrome connector: open chrome://extensions, enable Developer mode, choose Load unpacked, and select the folder revealed below. Reload Spotify once." : "Add the connector from the Chrome Web Store, then reload Spotify once.")
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Open Spotify in Chrome", action: BrowserConnector.openSpotify)
                    Button("Add Chrome connector", action: model.connect)
                        .buttonStyle(.borderedProminent).disabled(model.busy)
                }
            }
            Text(model.playback.title.isEmpty ? model.playback.message : "Connected · \(model.playback.title)")
                .font(.callout).foregroundStyle(model.playback.canControl ? Color.green : Color.secondary)
                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            Divider()
            Text("Desktop & Notification Center").font(.headline)
            Text("For your desktop, right-click it → Edit Widgets → Lunelio. For Notification Center, click the date/time → Edit Widgets → Lunelio, then add a size.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("Lunelio runs quietly in the background to connect your widget to Spotify Desktop or Chrome. Its controls work without opening a player window. macOS may delay song updates.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Toggle("Start widget connection at login", isOn: $login)
                .onChange(of: login) { _, enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                    } catch { loginError = error.localizedDescription }
                }
            VStack(alignment: .leading, spacing: 6) {
                Toggle("Hide menu-bar icon", isOn: $hideMenuBarIcon)
                    .onChange(of: hideMenuBarIcon) { _, hidden in onHideMenuBarIconChange(hidden) }
                Text("You can still open settings from the widget’s ••• menu.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !loginError.isEmpty { Text(loginError).font(.caption).foregroundStyle(.red) }
            if !model.serverMessage.isEmpty { Text(model.serverMessage).font(.caption).foregroundStyle(.red) }
            Text("No Spotify password, API key, or Premium account is required. Playback availability still follows Spotify’s rules for your account.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(28)
        }.frame(width: 490, height: 680)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = PlayerModel()
    private let server = BridgeServer()
    private var setupWindow: NSWindow?
    private var status: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenu()
        server.handler = { [weak self] command in
            guard let self else { return Playback() }
            if command != nil {
                if command != .menu {
                    // Avoid silently dropping a playback action during a short metadata read.
                    for _ in 0..<40 where self.model.busy { try? await Task.sleep(for: .milliseconds(100)) }
                    if self.model.busy { return Playback(message: "The player is busy. Try again.") }
                }
                await self.model.refresh(command)
            }
            return self.model.playback
        }
        server.onError = { [weak self] message in self?.model.serverMessage = message }
        server.start()
        server.browserHandler = { [weak self] message in self?.model.browser.receive(message) ?? Data("{}".utf8) }
        model.browser.onOpen = { [weak self] in self?.showSetup() }
        model.start()
        WidgetCenter.shared.reloadTimelines(ofKind: "SpotifyMiniWidget")
        if !UserDefaults.standard.bool(forKey: "setupShown") {
            showSetup(); UserDefaults.standard.set(true, forKey: "setupShown")
        }
    }

    private func configureMenu() {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png")
            .flatMap { NSImage(contentsOf: $0) }
        icon?.isTemplate = true
        icon?.size = NSSize(width: 18, height: 18)
        status?.button?.image = icon
        status?.button?.setAccessibilityLabel("Lunelio")
        let menu = NSMenu()
        let entries: [(String, Selector, String)] = [
            ("Settings…", #selector(showSetup), ","),
            ("Open Spotify", #selector(openSpotify), ""),
            ("Quit Lunelio", #selector(quit), "q")
        ]
        for (title, selector, key) in entries {
            if title == "Quit Lunelio" { menu.addItem(.separator()) }
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            item.target = self
            menu.addItem(item)
        }
        status?.menu = menu
        status?.isVisible = !UserDefaults.standard.bool(forKey: "hideMenuBarIcon")
    }

    @objc func openSpotify() {
        model.openSpotify()
    }
    @objc func quit() { NSApp.terminate(nil) }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url == LocalBridge.settingsURL || url == LocalBridge.openSpotifyURL {
                if model.playback.optionsVisible == true {
                    model.playback.optionsVisible = false
                    WidgetCenter.shared.reloadTimelines(ofKind: "SpotifyMiniWidget")
                }
                if url == LocalBridge.settingsURL { showSetup() }
                else { openSpotify() }
            } else if url == LocalBridge.nowPlayingURL || Playback(trackURL: url.absoluteString).spotifyURL != nil {
                Task { await model.refresh(.show) }
            }
        }
    }

    @objc func showSetup() {
        if setupWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 490, height: 640),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Lunelio · Settings"
            window.contentView = NSHostingView(rootView: SetupView(model: model,
                onHideMenuBarIconChange: { [weak self] hidden in self?.status?.isVisible = !hidden }))
            window.isReleasedWhenClosed = false
            window.center()
            setupWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        setupWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Background launches and widget actions must never open a window.
        WidgetCenter.shared.reloadTimelines(ofKind: "SpotifyMiniWidget")
        return true
    }
}

@main
struct SpotifyMiniApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}
