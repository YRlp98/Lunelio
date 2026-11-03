<h1>
  <img src="Design/Branding/Selected/AppIcon-1024.png" alt="Lunelio app icon" width="80" height="80" align="middle">
  Lunelio
</h1>

A handy macOS widget for [Spotify Desktop](https://www.spotify.com/download/mac/) and the [Spotify web player](https://open.spotify.com/).

See what’s playing and control Spotify from your Mac’s desktop or Notification Center. Play, pause, skip, and seek without switching apps.

Lunelio is free and open source, with all features included. It’s built to be lightweight and efficient, and you don’t need Spotify Premium or an API key to use it. Spotify’s own playback rules still apply.

[![Release 1.0.1](https://img.shields.io/badge/release-v1.0.1-1DB954?style=flat-square)](https://github.com/YRlp98/Lunelio/releases/tag/v1.0.1)
[![License: MIT](https://img.shields.io/badge/license-MIT-1DB954?style=flat-square)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/YRlp98/Lunelio?style=flat-square&logo=github&label=stars)](https://github.com/YRlp98/Lunelio/stargazers)
[![Release downloads](https://img.shields.io/github/downloads/YRlp98/Lunelio/total?style=flat-square&color=1DB954&label=release%20downloads "Downloads of all release files, including checksums")](https://github.com/YRlp98/Lunelio/releases)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-555555?style=flat-square&logo=apple)](#current-support)

[![Download for Mac](https://img.shields.io/badge/download-for%20Mac-1DB954?style=flat-square)](https://github.com/YRlp98/Lunelio/releases/download/v1.0.1/Lunelio-1.0.1.dmg)

![Lunelio cover with dark macOS widgets playing Breathing Stone by Tenno](Docs/Images/lunelio-cover.webp)

## Current support

- Requires macOS 14 or later. Support for other operating systems is planned.
- Works with Spotify Desktop and the Spotify web player in Google Chrome. More browsers are planned.

Current release: [1.0.1](https://github.com/YRlp98/Lunelio/releases/tag/v1.0.1), with a DNS rebinding protection fix. [Changelog](CHANGELOG.md#101--2026-10-29) · [All releases](https://github.com/YRlp98/Lunelio/releases).

## Features

- Small, medium, and large widgets with album artwork, song details, and track progress.
- Light and dark themes that follow your Mac’s appearance automatically.
- Play/pause, previous, and next controls.
- Click the progress bar to seek in 10% steps, from 0% to 100%.
- Automatic switching between Spotify Desktop and Chrome based on what’s playing.
- Start at login and hide the menu-bar icon from Settings.

I’m working on improvements and new features.

## Preview

![Lunelio’s small, medium, and large widgets on the macOS desktop, with the medium widget also in Notification Center](Docs/Images/lunelio-desktop.webp)

<details>
  <summary>Light and dark appearance, and Settings</summary>

  <p align="center">
    <img src="Docs/Images/widget-themes.webp" alt="Lunelio’s small, medium, and large widgets in light and dark appearance, showing Breathing Stone by Tenno" width="1120">
  </p>

  <p align="center">
    <img src="Docs/Images/settings.webp" alt="Lunelio 1.0.0 Settings with Spotify Desktop and Chrome connection options" width="490">
  </p>
</details>

<!-- Add a demo GIF here when available. -->

## How to use

Download [Lunelio-1.0.1.dmg](https://github.com/YRlp98/Lunelio/releases/download/v1.0.1/Lunelio-1.0.1.dmg), open it, and drag **Lunelio** to **Applications**. You don’t need Xcode to use the app.

The app is not notarized yet. See the [installation guide](Docs/Installing%20Lunelio.md) if macOS blocks it.

1. Open **Lunelio**.
2. Right-click your desktop → **Edit Widgets → Lunelio** and add a small, medium, or large widget. You can also add it in Notification Center.
3. Open **••• → Settings…** on the widget and connect Spotify using either option below.

### Spotify Desktop

1. Download and open [Spotify’s native Mac app](https://www.spotify.com/download/mac/).
2. In Lunelio Settings, click **Connect Spotify Desktop** and allow Lunelio to control Spotify when macOS asks.

You don’t need a browser extension for Spotify Desktop.

### Spotify web player in Chrome

1. In Lunelio Settings, click **Add Chrome connector** to reveal the connector folder.
2. Open `chrome://extensions`, enable **Developer mode**, click **Load unpacked**, and select that folder.
3. Open [Spotify’s web player](https://open.spotify.com) and reload the tab once. Start a song in Spotify, then use the widget to control playback.

Reload your Spotify tabs after each connector update. If the widget can’t start playback in a newly reopened tab, click Play in Spotify once.

Spotify installed as a Chrome web app works too. Choose **Automatic** in Settings to follow whichever source is playing. If both are playing, Spotify Desktop takes priority.

Click the cover to open Spotify, or use **•••** for Settings. macOS may delay widget updates.

Lunelio follows your Mac’s light or dark appearance automatically, so there’s no theme setting to change in the app.

## Development

Open **Lunelio.xcodeproj**, select **Lunelio → My Mac**, then press **⌘R** to run or **⌘U** to test. From the project folder:

```sh
./build.command   # Build the app
./check.command   # Run all regression checks
./package.command # Create the installer in build/Downloads/
```

The current development version is **1.0.1**. The app, widget, and connector share their version in **Config/Version.xcconfig**.

See [Editing in Xcode](Docs/Editing%20in%20Xcode.md) for the code map and [Release Guide](Docs/Release%20Guide.md) for distribution details.

## Donate

I’ll add donation links here for anyone who’d like to support Lunelio’s development.
