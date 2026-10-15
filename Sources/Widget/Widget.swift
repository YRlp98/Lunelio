import SwiftUI
import WidgetKit
import AppIntents
import AppKit

struct MusicEntry: TimelineEntry {
    var date: Date
    var playback: Playback
    var artwork: Data?
}

@MainActor
struct MusicProvider: @preconcurrency TimelineProvider {
    func placeholder(in context: Context) -> MusicEntry {
        MusicEntry(date: .now, playback: Playback(title: "Your music", artist: "Spotify", position: 65, duration: 240, canControl: true, message: ""))
    }

    func getSnapshot(in context: Context, completion: @escaping (MusicEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)) }
        else { load(completion) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MusicEntry>) -> Void) {
        load { entry in completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300)))) }
    }

    private func load(_ completion: @escaping (MusicEntry) -> Void) {
        Task {
            let playback = (try? await LocalBridge.request()) ?? Playback()
            var artwork: Data?
            if let url = URL(string: playback.artwork), url.scheme == "https",
               let host = url.host, host == "i.scdn.co" || host.hasSuffix(".scdn.co") {
                if let (data, response) = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 5)),
                   (response as? HTTPURLResponse)?.statusCode == 200, data.count < 5_000_000,
                   NSImage(data: data) != nil { artwork = data }
            }
            completion(MusicEntry(date: .now, playback: playback, artwork: artwork))
        }
    }
}

struct MusicWidgetView: View {
    let entry: MusicEntry
    #if WIDGET_PREVIEW
    let family: WidgetFamily
    #else
    @Environment(\.widgetFamily) var family
    #endif
    private let green = Color(red: 30 / 255, green: 215 / 255, blue: 96 / 255)
    private let secondary = Color(red: 179 / 255, green: 179 / 255, blue: 179 / 255)
    private var small: Bool { family == .systemSmall }

    static var surface: some View {
        LinearGradient(colors: [Color(white: 0.14), Color(white: 0.07)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: small ? 6 : 5) {
            HStack(spacing: small ? 4 : 12) {
                Group {
                    if entry.playback.title.isEmpty {
                        Link(destination: LocalBridge.openSpotifyURL) { artwork }
                            .accessibilityLabel("Open Spotify")
                    } else {
                        Button(intent: PlaybackIntent(.show)) { artwork }
                            .accessibilityLabel("Show \(entry.playback.displayTitle) in Spotify")
                    }
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.playback.displayTitle)
                        .font(.system(size: small ? 14 : 18, weight: .semibold))
                        .lineLimit(1)
                    Text(entry.playback.displayArtist)
                        .font(.system(size: small ? 11 : 12)).foregroundStyle(secondary)
                        .lineLimit(entry.playback.title.isEmpty ? 2 : 1)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button(intent: PlaybackIntent(.menu)) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: small ? 14 : 17, weight: .semibold))
                        .foregroundStyle(secondary)
                        .frame(width: small ? 24 : 28, height: small ? 40 : 44, alignment: .top)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.playback.optionsVisible == true ? "Close options" : "More options")
            }
            if entry.playback.optionsVisible == true {
                VStack(spacing: 7) {
                    option("Settings…", icon: "gearshape", url: LocalBridge.settingsURL)
                    option("Open Spotify", icon: "arrow.up.forward.app", url: LocalBridge.openSpotifyURL)
                }
                .padding(.top, 5)
            } else {
                progress
                HStack(spacing: small ? 6 : 16) {
                    control(.previous, icon: "backward.end.fill", label: "Previous track")
                    control(.toggle, icon: entry.playback.playing ? "pause.fill" : "play.fill",
                            label: entry.playback.playing ? "Pause Spotify" : "Play Spotify")
                    control(.next, icon: "forward.end.fill", label: "Next track")
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .containerBackground(for: .widget) { Self.surface }
        // Keep background navigation separate from the options' individual links.
        .widgetURL(small && entry.playback.optionsVisible != true ? LocalBridge.nowPlayingURL : nil)
    }

    private func option(_ title: String, icon: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: small ? 6 : 9) {
                Image(systemName: icon).foregroundStyle(green).frame(width: small ? 14 : 18).accessibilityHidden(true)
                Text(title).font(.system(size: small ? 11 : 12, weight: .medium)).lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(secondary).accessibilityHidden(true)
            }
            .padding(.horizontal, small ? 8 : 10).frame(height: 32)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var artwork: some View {
        Group {
            if let data = entry.artwork, let image = NSImage(data: data) {
                Image(nsImage: image).resizable().scaledToFit()
            } else {
                Color(white: 0.19).overlay {
                    if let url = Bundle.main.url(forResource: "BrandMark", withExtension: "png"),
                       let image = NSImage(contentsOf: url) {
                        Image(nsImage: image).resizable().scaledToFit().padding(7)
                    }
                }
            }
        }
        .frame(width: small ? 40 : 44, height: small ? 40 : 44)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityHidden(true)
    }

    private var progress: some View {
        VStack(spacing: 0) {
            Group {
                #if WIDGET_PREVIEW
                progressTrack
                #else
                if let interval = entry.playback.timerInterval {
                    ProgressView(timerInterval: interval, countsDown: false) { EmptyView() }
                        currentValueLabel: { EmptyView() }
                } else {
                    progressTrack
                }
                #endif
            }
            .tint(green)
            .frame(height: 4).clipShape(Capsule())
            .accessibilityHidden(true)
            .frame(height: 18)
            .overlay {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ForEach(PlayerCommand.seekSteps, id: \.rawValue) { command in
                            let percent = command.seekPercent!
                            // ponytail: ten fixed targets; replace with a slider if WidgetKit supports one.
                            Button(intent: PlaybackIntent(command)) {
                                Color.white.opacity(0.001)
                                    .frame(width: geometry.size.width * (percent == 10 ? 0.15 : percent == 100 ? 0.05 : 0.10), height: 18)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Jump to \(percent)%")
                            .accessibilityHint("\(Playback.timeLabel(entry.playback.duration * Double(percent) / 100)) into the song")
                        }
                    }
                    .disabled(!entry.playback.canControl || entry.playback.duration <= 0)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Song position")
                }
            }
            HStack {
                Group {
                    if let interval = entry.playback.timerInterval {
                        Text(timerInterval: interval, countsDown: false, showsHours: entry.playback.duration >= 3600)
                    } else {
                        Text(Playback.timeLabel(entry.playback.elapsed()))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Elapsed time")
                Text(entry.playback.duration > 0 ? Playback.timeLabel(entry.playback.duration) : "–:––")
                    .accessibilityLabel("Total time")
            }
            .font(.system(size: 11, weight: .medium)).monospacedDigit()
            .foregroundStyle(secondary)
        }
    }

    private var progressTrack: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.18))
                Capsule().fill(green).frame(width: geometry.size.width * entry.playback.progress)
            }
        }
    }

    private func control(_ command: PlayerCommand, icon: String, label: String) -> some View {
        let opensSpotify = command == .toggle && entry.playback.title.isEmpty
        let image = Image(systemName: icon)
                .font(.system(size: command == .toggle ? 15 : 17, weight: .semibold))
                .foregroundStyle(command == .toggle ? Color.black : Color.white)
                .frame(width: small ? 32 : 36, height: small ? 32 : 36)
                .background {
                    if command == .toggle { Circle().fill(green) }
                }
                .frame(width: small ? 40 : 44, height: small ? 40 : 44)
                .contentShape(Rectangle())
        return Group {
            if opensSpotify {
                Link(destination: LocalBridge.openSpotifyURL) { image }
            } else {
                Button(intent: PlaybackIntent(command)) { image }
            }
        }
        .disabled(!opensSpotify && !entry.playback.canControl)
        .opacity(opensSpotify || entry.playback.canControl ? 1 : 0.45)
        .accessibilityLabel(opensSpotify ? "Open Spotify" : label)
    }
}

#if !WIDGET_PREVIEW
@main
struct SpotifyMiniWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SpotifyMiniWidget", provider: MusicProvider()) { entry in MusicWidgetView(entry: entry) }
            .configurationDisplayName("Lunelio")
            .description("Now playing, track progress, and playback controls for Spotify Desktop and Spotify in Chrome.")
            .supportedFamilies([.systemSmall, .systemMedium])
            .containerBackgroundRemovable(false)
    }
}

#endif

#Preview("Small", as: .systemSmall) {
    SpotifyMiniWidget()
} timeline: {
    MusicEntry(date: .now, playback: Playback(title: "Your music", artist: "Spotify", position: 65, duration: 240, canControl: true, message: ""))
}

#Preview("Medium", as: .systemMedium) {
    SpotifyMiniWidget()
} timeline: {
    MusicEntry(date: .now, playback: Playback(title: "Your music", artist: "Spotify", position: 65, duration: 240, canControl: true, message: ""))
}
