# Using Lunelio

Lunelio controls Spotify’s native desktop app or Spotify playing in Chrome or its installed web app on macOS 14 or later.

## Install and connect

1. Open the beta DMG, drag **Lunelio** to **Applications**, and open it there. No Xcode is needed. See [Installing Lunelio](Installing%20Lunelio.md) for macOS security approval.
2. For **Spotify Desktop**, open its native Mac app. In Lunelio Settings click **Connect Spotify Desktop**, then allow the macOS automation request. No browser extension is needed. If permission was denied, enable **Lunelio → Spotify** in **System Settings → Privacy & Security → Automation**.
3. For **Spotify in Chrome**, open **chrome://extensions**, enable Developer mode, and choose **Load unpacked** with the folder revealed by **Add Chrome connector** in Lunelio Settings. Reload your Spotify tab or installed web app once.
4. Right-click the desktop and choose **Edit Widgets → Lunelio**. Add a small, medium, or large widget. The same widgets can be added in Notification Center. The large size is available in 0.0.5-beta and later.

## Daily use

The companion runs quietly in the background. Choose Automatic, Spotify Desktop, or Spotify in Chrome in Settings. Automatic prefers a playing source, with desktop winning ties, and falls back to the browser when desktop closes. Spotify must be open for live song information. The widget’s cover and play button open the selected Spotify app when no player is connected. With desktop connected, the cover brings that app forward. With Chrome connected, it reuses the existing Spotify window or tab and navigates to the current song.

Click along the progress bar to seek in 10% steps: 0%, 10%, 20%, through 100%. Click the start to return to 0:00. Dragging is not supported inside the widget. The three dots show Settings and Open Spotify inside the widget. Click the dots again to return to playback controls. These options work even when no player is connected. Settings can hide the menu-bar icon and enable starting the connection at login.

Playback controls use Spotify’s desktop scripting controls or browser controls, depending on the selected source. Lunelio does not require a Spotify password, Web API key, or Premium subscription of its own; Spotify’s playback rules for your account still apply. macOS controls widget refresh scheduling, so song updates can be delayed.

## Development and distribution

Use **⌘U** for the native Swift tests, or **./check.command** for the Swift tests plus browser build-script checks. The development app is signed locally. Public signing, notarization, and store publication are covered in **Release Guide.md**.

YouTube, SoundCloud, Apple Music, other browsers, and iOS/iPadOS are future work. They are not implemented in this build.
