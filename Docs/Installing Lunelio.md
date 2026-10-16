# Install Lunelio

Requires **macOS 14 or later**. The beta installer includes Apple silicon and Intel binaries. You do not need Xcode, a compiler, or a paid Spotify account to use Lunelio.

1. Download **[Lunelio-0.0.6-beta.dmg](https://github.com/YRlp98/Lunelio/releases/download/v0.0.6-beta/Lunelio-0.0.6-beta.dmg)** from the [GitHub release](https://github.com/YRlp98/Lunelio/releases/tag/v0.0.6-beta).
2. Open it and drag **Lunelio** to **Applications**. Quit an older copy before replacing it.
3. Open Lunelio from Applications, then eject the disk image.
4. Right-click the desktop → **Edit Widgets → Lunelio** and add a small, medium, or large widget. You can also add it in Notification Center.

## macOS security approval

This beta is locally signed, without Apple Developer ID signing or notarization. If macOS cannot verify the developer, only proceed if you trust the download’s source. After trying to open it, go to **System Settings → Privacy & Security → Open Anyway** and confirm the app. Do not override alerts that say the app will damage your computer. See [Apple’s guidance](https://support.apple.com/en-us/102445).

## Connect Spotify

**Desktop:** open [Spotify’s Mac app](https://www.spotify.com/download/mac/). In Lunelio Settings, click **Connect Spotify Desktop** and allow the macOS Automation request. No extension is needed.

**Chrome:** in Lunelio Settings, click **Add Chrome connector**. In `chrome://extensions`, enable **Developer mode**, choose **Load unpacked**, and select the revealed folder. Open the [Spotify web player](https://open.spotify.com) and reload once. Install Lunelio in Applications before loading the connector so its folder stays in place.

Use the widget’s **••• → Settings…** menu to choose a source, hide the menu-bar icon, or start the connection at login. Spotify’s playback rules still apply.
