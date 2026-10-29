# Changelog

## [1.0.1](https://github.com/YRlp98/Lunelio/releases/tag/v1.0.1) — 2026-10-29

### Security

- Reject local bridge requests unless the `Host` header is `127.0.0.1:49178` or `localhost:49178` to guard against DNS rebinding.

## [1.0.0](https://github.com/YRlp98/Lunelio/releases/tag/v1.0.0) — 2026-10-24

### Added

- Light mode for small, medium, and large widgets, including the inline menu and disconnected state. The theme follows the system appearance automatically.
- Dark text, light surfaces, artwork fades, and contrasting green progress and menu icons in light mode. Keep the existing dark appearance.
- Improve the Settings connection status contrast in light mode.

### Changed

- Move the app, widget, and Chrome connector to the shared stable version **1.0.0**.
- Include the playback and efficiency improvements recorded in the 0.2.2-beta development build below, which was not published separately.
- Refresh the README with a dark-mode cover, light and dark widget previews, current Settings, and a live GitHub stars badge.

### Validation

- Rendered all three sizes in light and dark mode with playback, menus, disconnected states, long titles, and bright, dark, or missing artwork. Twelve static dark-mode comparisons match the previous appearance pixel for pixel.
- Passed 14 Swift regression tests and 12 build-script tests, including stable connector version generation. Confirmed the live system switch to Dark; Settings follows both appearances and displays **1.0.0**.

## 0.2.2-beta — Development build

Includes the changes tested locally as 0.2.0-beta and 0.2.1-beta; those builds were not published.

### Improved

- Reduce CPU use during Chrome playback by waiting for widget commands instead of repeatedly checking for them.
- Stop the Chrome helper and clear its playback session when the last Spotify tab closes or navigates away. Reconnect automatically when Spotify opens again.
- Keep other open Spotify players connected and stop an idle helper after it finishes opening Settings.
- Stop companion polling when no player is connected; resume when Spotify Desktop launches or Chrome reconnects.
- Release the Settings window when it closes, avoid timing-only redraws, cancel completed connection timers, and cache the bundled connection token.
- Name the app, widget, and helper processes **Lunelio**, **LunelioWidget**, and **LunelioBridge**.
- Exclude obsolete executables left by incremental Xcode builds when packaging the renamed processes.
- Clarify Chrome setup and reloading Spotify tabs after connector updates. The app, widget, and connector share version **0.2.2-beta**.

### Validation

- Tested Spotify Desktop, Spotify installed as a Chrome web app, and Spotify in a regular Chrome tab.
- Measured about **80% lower combined app and helper CPU usage** during Chrome playback in a one-minute Debug-build test. Results may vary between Macs. RAM use was broadly unchanged.

### Known limitations

- A freshly reopened Spotify web tab may need one Play click inside Spotify before the widget can start playback.
- This beta is locally signed and is not Apple-notarized. Clean-Mac installation, Intel runtime behavior, and long-session memory use still need verification.

## [0.1.2-beta](https://github.com/YRlp98/Lunelio/releases/tag/v0.1.2-beta) — 2026-10-19

- Refresh the widget after development rebuilds so an older widget process cannot leave the desktop display frozen.
- Request fresh widget content when Lunelio starts or reopens.
- Updated the README with a desktop screenshot, clearer setup instructions, and current download links.
- App, widget, and Chrome connector use the same **0.1.2-beta** version.

## 0.1.1-beta

- Updated the shared app, widget, and Chrome connector version to 0.1.1-beta.

## [0.0.6-beta](https://github.com/YRlp98/Lunelio/releases/tag/v0.0.6-beta) — 2026-10-16

- Restart a song at 0:00 by clicking the start of the widget’s progress bar.
- Seek in 10% steps from 0% through 100% in small, medium, and large widgets, with Spotify Desktop or the Spotify web player in Chrome.

## [0.0.5-beta](https://github.com/YRlp98/Lunelio/releases/tag/v0.0.5-beta) — 2026-10-16

### Added

- Large widget with an album-cover background, larger playback controls, and an inline options menu.

### Improved

- Medium widget with a full-height cover and song details, progress, and controls alongside it.
- Small widget with album artwork as its background and room for two-line song titles.
- Sharper Spotify artwork in Chrome by choosing the largest available cover for the current song, with a thumbnail fallback.
- Consistent three-dot buttons across all widget sizes, with a dark fade to keep text and controls readable over artwork.

## [0.0.3-beta](https://github.com/YRlp98/Lunelio/releases/tag/v0.0.3-beta)

- Initial GitHub beta with small and medium macOS widgets.
- Spotify Desktop support and a bundled Chrome connector for the Spotify web player.
- Playback controls, seeking, automatic source selection, and widget settings.
