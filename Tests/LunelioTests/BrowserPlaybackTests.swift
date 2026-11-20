import Foundation
import JavaScriptCore
import Testing

@Test("Chrome helper stops when unused and reconnects without interrupting another player", arguments: [
    "last-tab", "navigate", "redacted-url", "multiple-tabs", "paused-player", "reopen",
    "settings", "multiple-settings", "settings-with-player", "snapshot-during-check",
    "stale-query", "query-failure", "settings-during-check", "old-command", "failed-settings", "closed-popup"
])
@MainActor
func browserWorkerLifecycle(scenario: String) async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let source = try String(contentsOf: root.appendingPathComponent("BrowserExtension/worker.js"), encoding: .utf8)
    let context = try #require(JSContext())
    context.evaluateScript("""
        function check(value, message) { if (!value) throw new Error(message); }
        function event() {
          return { addListener(callback) { this.listener = callback; },
            emit(...args) { return this.listener?.(...args); } };
        }
        let tabs = [{id:7, url:'https://open.spotify.com/'}];
        let deferQuery = false, queryFails = false, releaseQuery;
        let getTab = async id => tabs.find(tab => tab.id === id);
        const ports = [];
        const chrome = {
          runtime: {
            onMessage:event(),
            connectNative(name) {
              check(name === 'local.spotifymini.bridge', 'Wrong native host');
              const port = {onDisconnect:event(), onMessage:event(), messages:[], disconnected:false,
                postMessage(message) {
                  check(!this.disconnected, 'Posted to a closed connection'); this.messages.push(message);
                  if (message.kind === 'disconnect') this.disconnected = true;
                },
                disconnect() { throw new Error('Disconnected before the helper could clear playback'); }
              };
              ports.push(port); return port;
            }
          },
          tabs: {
            onRemoved:event(), onUpdated:event(),
            query(filter) {
              check(filter.url === 'https://open.spotify.com/*', 'Query exceeded Spotify host access');
              if (queryFails) return Promise.reject(new Error('Query unavailable'));
              if (deferQuery) return new Promise(resolve => { releaseQuery = resolve; });
              return Promise.resolve(tabs.slice());
            },
            get:id => getTab(id), update:async () => {},
            sendMessage:async () => ({playback:{title:'Song'}})
          },
          windows:{get:async () => ({state:'normal'}), update:async () => {}}
        };
        function snapshot(id = 7) {
          chrome.runtime.onMessage.emit({kind:'snapshot', playback:{playing:false}},
            {tab:{id}, url:'https://open.spotify.com/'}, () => {});
        }
        const settingsReplies = [];
        function openSettings(popupClosed = false) {
          chrome.runtime.onMessage.emit({kind:'open'}, {}, reply => {
            if (popupClosed) throw new Error('Popup already closed');
            settingsReplies.push(reply);
          });
        }
        let finished = false, failure = '';
        """)
    context.evaluateScript(source)
    #expect(context.exception == nil, "\(context.exception?.toString() ?? "")")
    let scenarioJSON = String(decoding: try JSONEncoder().encode(scenario), as: UTF8.self)
    context.evaluateScript("""
        (async () => {
          check(ports.length === 0, 'Started helper before Spotify or Settings needed it');
          const scenario = \(scenarioJSON);
          if (['settings', 'multiple-settings', 'failed-settings', 'closed-popup'].includes(scenario)) {
            tabs = [];
            openSettings(scenario === 'closed-popup');
            const connection = ports[0];
            check(connection.messages[0].kind === 'open', 'Lost Settings request');
            check(settingsReplies.length === 0, 'Reported Settings open before the helper acknowledged it');
            if (scenario === 'failed-settings') {
              connection.onDisconnect.emit();
              check(settingsReplies[0]?.connected === false, 'Missing helper did not report failure');
              return;
            }
            if (scenario === 'multiple-settings') openSettings();
            await chrome.tabs.onRemoved.emit(99);
            check(!connection.disconnected, 'Closed before Settings handoff finished');
            await connection.onMessage.emit({kind:'opened'});
            if (scenario === 'multiple-settings') {
              check(!connection.disconnected, 'Closed with another Settings request pending');
              await connection.onMessage.emit({kind:'opened'});
            }
            check(connection.disconnected, 'Settings left an idle helper');
            check(settingsReplies.every(reply => reply.connected === true), 'Settings handoff reported failure');
            return;
          }
          snapshot();
          const first = ports[0];
          if (scenario === 'multiple-tabs' || scenario === 'paused-player') {
            if (scenario === 'multiple-tabs') {
              tabs.push({id:9, url:'https://open.spotify.com/'}); snapshot(9); tabs.shift();
            }
            await chrome.tabs.onRemoved.emit(scenario === 'multiple-tabs' ? 7 : 99);
            check(!first.disconnected && ports.length === 1, 'Disconnected an available player');
            const id = tabs[0].id;
            await first.onMessage.emit({kind:'command', tab:id, id:'next-command', action:'next'});
            check(first.messages.some(message => message.kind === 'ack' && message.commandID === 'next-command'),
              'Remaining player lost its controls');
            return;
          }
          if (scenario === 'settings-with-player') {
            openSettings(); await first.onMessage.emit({kind:'opened'});
            check(!first.disconnected, 'Opening Settings disconnected Spotify'); return;
          }
          if (scenario === 'query-failure') {
            tabs = []; queryFails = true;
            await chrome.tabs.onRemoved.emit(7);
            check(!first.disconnected, 'Query failure was treated as no players');
            queryFails = false; await chrome.tabs.onRemoved.emit(7);
            check(first.disconnected, 'Did not recover after query failure'); return;
          }
          if (['snapshot-during-check', 'stale-query', 'settings-during-check'].includes(scenario)) {
            tabs = []; deferQuery = true;
            const closing = chrome.tabs.onRemoved.emit(7);
            if (scenario === 'settings-during-check') openSettings();
            else {
              if (scenario === 'stale-query') { first.disconnected = true; first.onDisconnect.emit(); }
              tabs = [{id:9, url:'https://open.spotify.com/'}]; snapshot(9);
            }
            releaseQuery([]); await closing; deferQuery = false;
            if (scenario === 'settings-during-check') {
              check(!first.disconnected, 'Idle check interrupted Settings');
              await first.onMessage.emit({kind:'opened'});
              check(first.disconnected, 'Settings acknowledgement left an idle helper');
            } else {
              check(!ports[ports.length-1].disconnected, 'Stale query stopped a new connection or player');
            }
            return;
          }
          let pendingCommand, releaseGet;
          if (scenario === 'old-command') {
            getTab = () => new Promise(resolve => { releaseGet = resolve; });
            pendingCommand = first.onMessage.emit({kind:'command', tab:7, id:'old-command', action:'next'});
          }
          tabs = [];
          if (scenario === 'navigate') await chrome.tabs.onUpdated.emit(7, {url:'https://example.com/'});
          else if (scenario === 'redacted-url') await chrome.tabs.onUpdated.emit(7, {status:'complete'});
          else await chrome.tabs.onRemoved.emit(7);
          check(first.disconnected, 'Last Spotify tab left the helper running');
          if (scenario === 'reopen' || scenario === 'old-command') {
            tabs = [{id:9, url:'https://open.spotify.com/'}]; snapshot(9);
            check(ports.length === 2 && !ports[1].disconnected, 'Spotify did not reconnect');
            first.onDisconnect.emit(); snapshot(9);
            check(ports.length === 2, 'Old disconnect cleared a new connection');
            if (pendingCommand) {
              releaseGet({id:7, url:'https://open.spotify.com/'}); await pendingCommand;
              check(!ports[1].messages.some(message => message.commandID === 'old-command'),
                'Old command reply leaked to a new connection');
            }
          }
        })().catch(error => { failure = String(error); }).finally(() => { finished = true; });
        """)
    for _ in 0..<100 {
        if context.evaluateScript("finished")?.toBool() == true { break }
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(context.exception == nil, "\(context.exception?.toString() ?? "")")
    #expect(context.evaluateScript("finished")?.toBool() == true, "Lifecycle scenario did not finish: \(scenario)")
    #expect(context.evaluateScript("failure")?.toString() == "", "\(context.evaluateScript("failure")?.toString() ?? scenario)")
}

@Test("Connector shows only newer stable updates without starting the native helper", arguments: [
    "patch", "minor", "major", "beta-to-stable", "same", "older", "older-major", "draft", "prerelease",
    "invalid-tag", "leading-zero", "overflow", "missing-tag", "offline", "timeout", "rate-limit", "bad-json"
])
@MainActor
func connectorUpdateTag(scenario: String) async throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let source = try String(contentsOf: root.appendingPathComponent("BrowserExtension/popup.js"), encoding: .utf8)
    let context = try #require(JSContext())
    let scenarioJSON = String(decoding: try JSONEncoder().encode(scenario), as: UTF8.self)
    context.evaluateScript("""
        function check(value, message) { if (!value) throw new Error(message); }
        const scenario = \(scenarioJSON);
        const elements = {};
        const document = {querySelector(selector) {
          return elements[selector] ||= {textContent:'',hidden:true,addEventListener(event,callback) {this.click = callback;}};
        }};
        let request, finished = false, fetches = 0;
        const installed = scenario === 'minor' ? '1.9.3' : scenario === 'older-major' ? '2.0.0' : '1.0.1';
        const chrome = {runtime:{
          getManifest:() => ({version:installed, version_name:scenario === 'beta-to-stable' ? '1.0.1-beta' : installed}),
          sendMessage:async message => {request = message; return {connected:true};}
        }};
        const AbortSignal = {timeout:ms => {check(ms === 10000, 'Missing deadline'); return 'deadline';}};
        const tags = {patch:'v1.0.2', minor:'v1.10.0', major:'v2.0.0', same:'v1.0.1', older:'v1.0.0',
          'older-major':'v1.99.99', 'invalid-tag':'v1.0.2-beta', 'leading-zero':'v01.0.2',
          overflow:'v9007199254740992.0.0', 'missing-tag':null, 'beta-to-stable':'v1.0.1'};
        async function fetch(url, options) {
          fetches++;
          check(url === 'https://api.github.com/repos/YRlp98/Lunelio/releases/latest', 'Wrong update endpoint');
          check(options.credentials === 'omit' && options.signal === 'deadline', 'Missing privacy or timeout setting');
          check(options.headers.Accept === 'application/vnd.github+json', 'Wrong API response type');
          if (scenario === 'offline' || scenario === 'timeout') throw new Error(scenario);
          return {ok:scenario !== 'rate-limit', async json() {
            if (scenario === 'bad-json') throw new SyntaxError('Invalid JSON');
            return {tag_name:tags[scenario] ?? (scenario === 'missing-tag' ? null : 'v1.0.2'),
              draft:scenario === 'draft', prerelease:scenario === 'prerelease'};
          }};
        }
        """)
    context.evaluateScript(source)
    // All mocked requests settle immediately; drain their promise continuations.
    context.evaluateScript("Promise.resolve().then(() => {}).then(() => {}).then(() => {finished = true;});")
    for _ in 0..<100 where context.evaluateScript("finished")?.toBool() != true {
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(context.exception == nil)
    #expect(context.evaluateScript("finished")?.toBool() == true)
    #expect(context.evaluateScript("fetches")?.toInt32() == 1)
    #expect(context.evaluateScript("request === undefined")?.toBool() == true)
    let shouldShow = ["patch", "minor", "major", "beta-to-stable"].contains(scenario)
    #expect(context.evaluateScript("document.querySelector('#update').hidden")?.toBool() == !shouldShow)
    #expect(context.evaluateScript("elements['#updates'] === undefined")?.toBool() == true)
    context.evaluateScript("elements['#show'].click().finally(() => {finished = false;});")
    for _ in 0..<100 where context.evaluateScript("finished")?.toBool() != false {
        try await Task.sleep(for: .milliseconds(5))
    }
    #expect(context.evaluateScript("request.kind")?.toString() == "open")
    #expect(context.evaluateScript("Object.keys(request).length")?.toInt32() == 1)
    let html = try String(contentsOf: root.appendingPathComponent("BrowserExtension/popup.html"), encoding: .utf8)
    #expect(html.contains("href=\"https://github.com/YRlp98/Lunelio/releases/latest\""))
    #expect(html.contains("rel=\"noopener noreferrer\" hidden>Update available</a>"))
}

@Test("Profile selection, delivery, acknowledgements, and disconnect")
@MainActor
func browserPlaybackTests() async throws {
    let sample = Data(#"{"title":"A \"song\" 🎵","artist":"Artist","artwork":"","playing":false,"position":50,"duration":100,"canControl":true,"updated":0}"#.utf8)
    let decoded = try Playback.decode(sample)
    let browser = BrowserPlayback()
    #expect(!browser.hasPlayer)
    var current = Playback()
    browser.onPlayback = { current = $0 }
    _ = browser.receive(BrowserMessage(kind: "snapshot", session: "profile-a", snapshot: BrowserSnapshot(tab: 7, playback: decoded)))
    #expect(current.title == decoded.title)
    #expect(browser.hasPlayer)
    var playing = decoded; playing.title = "Playing"; playing.playing = true
    _ = browser.receive(BrowserMessage(kind: "snapshot", session: "profile-b", snapshot: BrowserSnapshot(tab: 9, playback: playing)))
    #expect(current.title == "Playing")
    async let operation: Void = browser.send(.next)
    try await Task.sleep(for: .milliseconds(30))
    let wrongSession = browser.receive(BrowserMessage(kind: "poll", session: "profile-a"))
    #expect(wrongSession == Data("{}".utf8))
    let data = browser.receive(BrowserMessage(kind: "poll", session: "profile-b"))
    let command = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(command["action"] as? String == "next" && command["tab"] as? Int == 9)
    #expect(browser.receive(BrowserMessage(kind: "poll", session: "profile-b")) == Data("{}".utf8))
    _ = browser.receive(BrowserMessage(kind: "ack", session: "profile-b", commandID: command["id"] as? String))
    try await operation
    _ = browser.receive(BrowserMessage(kind: "disconnect", session: "profile-b"))
    #expect(current.title == decoded.title)
    var unavailable = decoded; unavailable.canControl = false
    _ = browser.receive(BrowserMessage(kind: "snapshot", session: "profile-a", snapshot: BrowserSnapshot(tab: 7, playback: unavailable)))
    async let show: Void = browser.send(.show)
    try await Task.sleep(for: .milliseconds(30))
    let showData = browser.receive(BrowserMessage(kind: "poll", session: "profile-a"))
    let showCommand = try JSONSerialization.jsonObject(with: showData) as! [String: Any]
    #expect(showCommand["action"] as? String == "show" && showCommand["tab"] as? Int == 7)
    _ = browser.receive(BrowserMessage(kind: "ack", session: "profile-a", commandID: showCommand["id"] as? String))
    try await show
    do { try await browser.send(.seek50); Issue.record("Unavailable player accepted seek") }
    catch { }
    _ = browser.receive(BrowserMessage(kind: "snapshot", session: "profile-a", snapshot: BrowserSnapshot(tab: 7, playback: decoded)))
    async let seek: Void = browser.send(.seek0)
    try await Task.sleep(for: .milliseconds(30))
    let seekData = browser.receive(BrowserMessage(kind: "poll", session: "profile-a"))
    let seekCommand = try JSONSerialization.jsonObject(with: seekData) as! [String: Any]
    #expect(seekCommand["action"] as? String == "seek0" && seekCommand["tab"] as? Int == 7)
    _ = browser.receive(BrowserMessage(kind: "ack", session: "profile-a", commandID: seekCommand["id"] as? String))
    try await seek
    async let closedPlayer: Void = browser.send(.show)
    try await Task.sleep(for: .milliseconds(30))
    let closedData = browser.receive(BrowserMessage(kind: "poll", session: "profile-a"))
    let closedCommand = try JSONSerialization.jsonObject(with: closedData) as! [String: Any]
    _ = browser.receive(BrowserMessage(kind: "ack", session: "profile-a", commandID: closedCommand["id"] as? String, error: "player-unavailable"))
    do { try await closedPlayer; Issue.record("Closed player accepted show") }
    catch let error as URLError { #expect(error.code == .resourceUnavailable) }
    #expect(!browser.hasPlayer && current.title.isEmpty)
    _ = browser.receive(BrowserMessage(kind: "snapshot", session: "profile-a", snapshot: BrowserSnapshot(tab: 7, playback: decoded)))
    _ = browser.receive(BrowserMessage(kind: "closed", session: "other-profile", tab: 7))
    #expect(browser.hasPlayer)
    _ = browser.receive(BrowserMessage(kind: "closed", session: "profile-a", tab: -1))
    #expect(browser.hasPlayer)
    _ = browser.receive(BrowserMessage(kind: "closed", session: "profile-a", tab: 7))
    #expect(!browser.hasPlayer && current.title.isEmpty)

}

@Test("Waiting browser polls deliver each command once to its own profile", arguments: [false, true])
@MainActor
func browserCommandWaiterTests(commandQueuedFirst: Bool) async throws {
    let browser = BrowserPlayback()
    _ = browser.receive(BrowserMessage(kind: "snapshot", session: "player",
        snapshot: BrowserSnapshot(tab: 7, playback: Playback(title: "Song", canControl: true))))
    let poll: Task<Data, Never>?
    if commandQueuedFirst { poll = nil }
    else {
        poll = Task { await browser.waitForCommand(session: "player", timeout: .seconds(2)) }
        try await Task.sleep(for: .milliseconds(30))
    }
    let operation = Task { try await browser.send(.next) }
    try await Task.sleep(for: .milliseconds(30))
    let wrongProfile = await browser.waitForCommand(session: "other", timeout: .milliseconds(30))
    #expect(wrongProfile == Data("{}".utf8))
    let data: Data
    if let poll { data = await poll.value }
    else { data = await browser.waitForCommand(session: "player", timeout: .seconds(2)) }
    let command = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let id = try #require(command["id"] as? String)
    #expect(command["action"] as? String == "next" && command["tab"] as? Int == 7)
    let duplicate = await browser.waitForCommand(session: "player", timeout: .milliseconds(30))
    #expect(duplicate == Data("{}".utf8))
    _ = browser.receive(BrowserMessage(kind: "ack", session: "player", commandID: id))
    try await operation.value
}

@Test("Browser polls finish on timeout, disconnect, and cancellation", arguments: ["timeout", "disconnect", "cancel", "replaced"])
@MainActor
func browserWaiterLifecycleTests(scenario: String) async throws {
    let browser = BrowserPlayback()
    var completed = false
    let poll = Task {
        let data = await browser.waitForCommand(session: "player", timeout: .milliseconds(100))
        completed = true
        return data
    }
    try await Task.sleep(for: .milliseconds(30))
    #expect(!completed)
    if scenario == "disconnect" { _ = browser.receive(BrowserMessage(kind: "disconnect", session: "player")) }
    if scenario == "cancel" { poll.cancel() }
    if scenario == "replaced" {
        var replacementCompleted = false
        let replacement = Task {
            let data = await browser.waitForCommand(session: "player", timeout: .seconds(2))
            replacementCompleted = true
            return data
        }
        #expect(await poll.value == Data("{}".utf8))
        poll.cancel()
        try await Task.sleep(for: .milliseconds(150))
        #expect(!replacementCompleted, "An old timeout or cancellation finished the replacement poll")
        _ = browser.receive(BrowserMessage(kind: "disconnect", session: "player"))
        #expect(await replacement.value == Data("{}".utf8))
    }
    #expect(await poll.value == Data("{}".utf8))
    #expect(completed)
    #expect(await browser.waitForCommand(session: "", timeout: .seconds(2)) == Data("{}".utf8))
    #expect(await browser.waitForCommand(session: String(repeating: "a", count: 100), timeout: .seconds(2)) == Data("{}".utf8))
    let cancelled = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return await browser.waitForCommand(session: "cancelled", timeout: .seconds(2))
    }
    #expect(await cancelled.value == Data("{}".utf8))
}

@Test("Fresh browser playback stays quiet; expired playback is cleared once")
@MainActor
func browserExpiryTests() {
    let browser = BrowserPlayback()
    var updates = 0
    browser.onPlayback = { _ in updates += 1 }
    browser.expire()
    #expect(updates == 0)
    let snapshot = BrowserSnapshot(tab: 7, playback: Playback(title: "Song", canControl: true))
    _ = browser.receive(BrowserMessage(kind: "snapshot", session: "expiry", snapshot: snapshot))
    #expect(updates == 1 && browser.hasPlayer)
    browser.expire()
    #expect(updates == 1 && browser.hasPlayer)
    browser.expire(now: Date().addingTimeInterval(91))
    #expect(updates == 2 && !browser.hasPlayer)
    browser.expire(now: Date().addingTimeInterval(92))
    #expect(updates == 2)
}

@Test("Browser seek commands reach both endpoints and reject invalid percentages", arguments: zip(
    stride(from: 0, through: 100, by: 10).map { "seek\($0)" } + ["seek-10", "seek1", "seek01", "seek37", "seek99", "seek101", "seek110", "seekNaN", "seek50/next"],
    Array(stride(from: 0, through: 100, by: 10)) + Array(repeating: -1, count: 9)
))
@MainActor
func browserSeekTests(action: String, percent: Int) throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let source = try String(contentsOf: root.appendingPathComponent("BrowserExtension/content-tail.js"), encoding: .utf8)
    let context = try #require(JSContext())
    context.evaluateScript("""
        let listener, response;
        const events = [];
        function HTMLInputElement() {}
        Object.defineProperty(HTMLInputElement.prototype, 'value', {
          get() { return this.position; }, set(value) { this.position = value; }
        });
        const slider = Object.assign(new HTMLInputElement(), {
          min: '0', max: '200000', disabled: false, position: '120000',
          dispatchEvent(event) { events.push(event.type); }
        });
        const document = { querySelector: selector =>
          selector === '[data-testid="playback-progressbar"] input[type="range"]' ? slider : null };
        const chrome = { runtime: { id: 'test', sendMessage: async () => ({}),
          onMessage: { addListener(callback) { listener = callback; } } } };
        function readPlayback() { return {canControl: true, duration: 200}; }
        function Event(type) { this.type = type; }
        function MutationObserver() {}
        function setInterval() {}
        function setTimeout() {}
        function clearTimeout() {}
        """)
    context.evaluateScript(source)
    #expect(context.exception == nil, "\(context.exception?.toString() ?? "")")
    let actionJSON = String(decoding: try JSONEncoder().encode(action), as: UTF8.self)
    context.evaluateScript("listener({kind:'command', action:\(actionJSON)}, {id:'test'}, value => { response = value; })")
    #expect(context.exception == nil, "\(context.exception?.toString() ?? "")")
    let position = context.evaluateScript("Number(slider.value)")?.toDouble()
    let eventCount = context.evaluateScript("events.length")?.toInt32()
    if percent < 0 {
        #expect(context.evaluateScript("response.error")?.toString() == "Unknown command")
        #expect(position == 120_000 && eventCount == 0)
    } else {
        #expect(context.evaluateScript("response.playback.canControl")?.toBool() == true)
        #expect(position == Double(percent) * 2_000)
        #expect(context.evaluateScript("events.join(',')")?.toString() == "input,change")
    }
}

@Test("Browser artwork selects larger covers without mixing songs or degrading the thumbnail")
@MainActor
func browserArtworkTests() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let source = try String(contentsOf: root.appendingPathComponent("BrowserExtension/player.js"), encoding: .utf8)
    let thumbnail = "https://i.scdn.co/thumbnail.jpg"
    let large = "https://i.scdn.co/large.jpg"
    let medium = "https://i.scdn.co/medium.jpg"
    let cases: [(String, Int, String, [[String: String]], String)] = [
        (thumbnail, 64, "Song", [["src": medium, "sizes": "300x300"], ["src": large, "sizes": "640x640"]], large),
        (thumbnail, 640, "Song", [["src": medium, "sizes": "300x300"]], thumbnail),
        (thumbnail, 64, "Previous song", [["src": large, "sizes": "640x640"]], thumbnail),
        (thumbnail, 64, "Song", [], thumbnail),
        (thumbnail, 64, "Song", [["src": large, "sizes": "invalid any"], ["src": "", "sizes": "640x640"]], thumbnail),
        (thumbnail, 64, "Song", [["src": large, "sizes": "32x32 512X512"], ["src": medium, "sizes": "300x300"]], large),
        ("", 0, "Song", [["src": large]], large),
        ("", 0, "Song", [], "")
    ]
    for (thumbnail, width, metadataTitle, artwork, expected) in cases {
        let fixture: [String: Any] = ["thumbnail": thumbnail, "width": width, "metadataTitle": metadataTitle, "artwork": artwork]
        let json = String(decoding: try JSONSerialization.data(withJSONObject: fixture), as: UTF8.self)
        let context = try #require(JSContext())
        context.evaluateScript("""
            const fixture = \(json);
            const cover = { src: fixture.thumbnail, currentSrc: fixture.thumbnail,
              naturalWidth: fixture.width, naturalHeight: fixture.width };
            const title = { textContent: 'Song', closest: () => null };
            const root = {
              querySelector: selector => selector === 'img' ? cover :
                selector === '[data-testid="context-item-info-title"]' ? title : null,
              querySelectorAll: () => []
            };
            const document = {
              querySelector: selector => selector === '[data-testid="now-playing-bar"]' ? root : null,
              querySelectorAll: () => []
            };
            const navigator = { mediaSession: { metadata: {
              title: fixture.metadataTitle, artist: 'Artist', artwork: fixture.artwork
            } } };
            """)
        let result = context.evaluateScript(source)
        #expect(context.exception == nil, "\(context.exception?.toString() ?? "")")
        let data = Data(try #require(result?.toString()).utf8)
        let playback = try Playback.decode(data)
        #expect(playback.artwork == expected)
    }
}
