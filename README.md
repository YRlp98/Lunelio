<h1>
  <img src="Design/Branding/Selected/AppIcon-1024.png" alt="Lunelio app icon" width="80" height="80" align="middle">
  Lunelio
</h1>

A small macOS widget for [Spotify Desktop](https://www.spotify.com/download/mac/) and the [Spotify web player](https://open.spotify.com/).

Free to use, with all features included. No Spotify Premium subscription or API key required by Lunelio. Spotify’s own playback rules still apply.

See what’s playing, pause, skip, and seek from your desktop or Notification Center.

[![Release](https://img.shields.io/badge/release-v0.1.2--beta-1DB954?style=flat-square)](https://github.com/YRlp98/Lunelio/releases/tag/v0.1.2-beta)
[![License: MIT](https://img.shields.io/badge/license-MIT-1DB954?style=flat-square)](LICENSE)
[![Star on GitHub](https://img.shields.io/badge/GitHub-star-181717?style=flat-square&logo=github)](https://github.com/YRlp98/Lunelio/stargazers)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-555555?style=flat-square&logo=apple)](#current-support)

[![Download for Mac](https://img.shields.io/badge/download-for%20Mac-1DB954?style=flat-square)](https://github.com/YRlp98/Lunelio/releases/tag/v0.1.2-beta)

![Lunelio cover with small, medium, and large macOS widgets playing Breathing Stone by Tenno](Docs/Images/lunelio-cover.webp)

## Current support

- **macOS 14 or later.** Support for other operating systems is planned.
- **Spotify Desktop and the Spotify web player in Google Chrome.** More browsers are planned.

Current release: **[0.1.2-beta](https://github.com/YRlp98/Lunelio/releases/tag/v0.1.2-beta)** · [Changelog](CHANGELOG.md)

Upcoming beta: **0.2.2-beta**, with about **80% lower CPU usage** in our short Chrome playback test, automatic helper shutdown when Spotify tabs close, and clearer setup instructions. See the [unreleased changes](CHANGELOG.md#022-beta--unreleased).

## Features

- Small, medium, and large widgets with album artwork, song details, and track progress.
- Play/pause, previous, and next controls.
- Click the progress bar to seek in 10% steps, from 0% to 100%.
- Automatic switching between Spotify Desktop and Chrome based on what’s playing.
- Start at login and hide the menu-bar icon from Settings.

I’m actively improving Lunelio and adding more features.

## Preview

![Lunelio’s small, medium, and large widgets on the macOS desktop, with the medium widget also in Notification Center](Docs/Images/lunelio-desktop.webp)

<details>
  <summary>See the small and large widgets, menu, and Settings</summary>

  <p align="center">
    <img src="Docs/Images/widget-small.png" alt="Lunelio small widget preview with album artwork as its background" width="164">
    <img src="Docs/Images/widget-large.png" alt="Lunelio large widget preview with album artwork and larger playback controls" width="344">
  </p>

  <p align="center">
    <img src="Docs/Images/widget-options.png" alt="Lunelio’s inline widget menu with Settings and Open Spotify" width="600">
  </p>
  <p align="center">
    <img src="Docs/Images/settings.png" alt="Lunelio Settings with Spotify Desktop and Chrome connection options" width="490">
  </p>
</details>

<!-- Add a demo GIF here when available. -->

## How to use

Download **[Lunelio-0.1.2-beta.dmg](https://github.com/YRlp98/Lunelio/releases/download/v0.1.2-beta/Lunelio-0.1.2-beta.dmg)**, open it, and drag **Lunelio** to **Applications**. No Xcode is needed to use the app.

This beta is not notarized yet. See the [installation guide](Docs/Installing%20Lunelio.md) if macOS blocks it.

1. Open **Lunelio**.
2. Right-click your desktop → **Edit Widgets → Lunelio** and add a small, medium, or large widget. You can also add it in Notification Center.
3. Open **••• → Settings…** on the widget and connect Spotify using either option below.

### Spotify Desktop

1. Download and open [Spotify’s native Mac app](https://www.spotify.com/download/mac/).
2. In Lunelio Settings, click **Connect Spotify Desktop** and allow Lunelio to control Spotify when macOS asks.

No browser extension is needed.

### Spotify web player in Chrome

1. In Lunelio Settings, click **Add Chrome connector** to reveal the connector folder.
2. Open `chrome://extensions`, enable **Developer mode**, click **Load unpacked**, and select that folder.
3. Open [Spotify’s web player](https://open.spotify.com), reload the tab once, and start a song in Spotify. You can then use the widget’s controls.

After updating the connector, reload your Spotify tabs again. If a freshly reopened tab does not start from the widget, click Play in Spotify once.

This also works with Spotify installed as a Chrome web app. Choose **Automatic** in Settings to follow the playing source; Spotify Desktop takes priority when both are playing.

Click the cover to open Spotify, or **•••** for Settings. macOS may delay widget updates.

## Development

Open **Lunelio.xcodeproj**, select **Lunelio → My Mac**, then press **⌘R** to run or **⌘U** to test. From the project folder:

```sh
./build.command   # Build the app
./check.command   # Run all regression checks
./package.command # Create the beta installer in build/Downloads/
```

The current development version is **0.2.2-beta**. The app, widget, and connector share their version in **Config/Version.xcconfig**. The Chrome connection waits for commands during playback and exits when no Spotify tabs remain. Background polling stops when no player is connected. Both reconnect automatically.

See [Editing in Xcode](Docs/Editing%20in%20Xcode.md) for the code map and [Release Guide](Docs/Release%20Guide.md) for distribution details.

## Donate

If you’d like to support Lunelio’s development, donation links will be added here.
