# Preparing Lunelio for public release

Run **./package.command** to create **build/Downloads/Lunelio-0.0.3-beta.dmg** and its SHA-256 checksum. The disk image includes the complete app, embedded widget, native helper, Chrome connector, an Applications shortcut, user instructions, and the MIT license. The app also includes the license in its resources. All three executables contain Apple silicon and Intel binaries.

The packager uses a separate app copy, replaces the development connection token with a fresh package token, and signs the helper, widget, and app locally. It checks matching versions, architectures, signatures, and the disk image. It does not change the running development app or its compatibility links.

## Beta downloads

Publish each beta through [GitHub Releases](https://github.com/YRlp98/Lunelio/releases), with a matching version tag, the DMG, and its `.sha256` file. The current release tag is **v0.0.3-beta**. Keep the README and installation guide’s download links in sync with the release. Users drag the app to Applications; they do not build it. Explain that this beta is not notarized and link [Installing Lunelio](Installing%20Lunelio.md).

Installation on a clean Mac, Intel runtime behavior, and restart recovery still need testing before recommending the beta broadly. The Chrome connector remains an unpacked installation until it is published to the Chrome Web Store.

## Public signing

The current beta uses local signing, so macOS may require a one-time security approval. For ordinary public installation, use Developer ID signing and Apple notarization. This Mac currently has no Developer ID identity; the public signing steps below remain pending.

## Chrome connector

1. Upload a ZIP containing `manifest.json`, `content.js`, `worker.js`, `popup.html`, and `popup.js` and the icons/ folder from build/ChromeExtension to your Chrome Web Store developer dashboard.
2. Obtain the dashboard’s extension ID and public key. Set `Resources/extension-id.txt` to that ID and BrowserExtension/manifest.template.json’s `key` to that public key. Rebuild so the Mac native-host manifest permits the published extension.
3. Publish the connector after review. Set `Resources/extension-store-url.txt` to its actual `https://chromewebstore.google.com/…` listing URL, then rebuild. The existing Add Chrome Connector button will open that listing automatically.
4. Confirm the store-installed extension can connect, display artwork and song metadata, pause/resume, and skip in both a regular Spotify tab and the installed Chrome Spotify web app. Check reconnecting after Chrome and Mac restarts.

The connector requests native messaging and access only to `https://open.spotify.com/*`. It sends playback information to the local companion. Do not request broader browser permissions for distribution.

Chrome documentation: [Publishing](https://developer.chrome.com/docs/webstore/publish/), [stable extension IDs](https://developer.chrome.com/docs/extensions/reference/manifest/key), [native messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging).

## Mac application

Choose permanent bundle identifiers before release. Use your Apple Developer ID certificate to sign the helper, widget extension, and containing app, in that order, with hardened runtime and a secure timestamp. Preserve the widget’s sandbox and network-client entitlements, the app’s Apple events entitlement, and its NSAppleEventsUsageDescription for the desktop connection. Config/Project.xcconfig currently configures ad hoc local signing. Set the native targets’ distribution signing and hardened runtime settings for public releases; preserve the widget’s entitlements. The current beta packager re-signs its staged copy locally, so replace that signing step with Developer ID signing before notarizing a public build.

Notarize the final signed package using Apple’s notary service, staple the accepted ticket, then verify installation and Gatekeeper acceptance on a clean Mac. Test opening the app from Applications, connecting Spotify Desktop with allowed and denied Automation permission, installing the browser connector, adding both widget sizes, switching sources, and controlling playback. Build and test an Intel version too if Intel Macs will be supported.

Apple documentation: [Developer ID](https://developer.apple.com/developer-id/), [Notarizing macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## User experience after release

Users will move the app to Applications and open it. For Spotify Desktop, they click Connect Spotify Desktop and allow macOS Automation permission. For browser playback, they click Add Chrome Connector to install from the store. After that one-time setup, opening Spotify connects automatically. Widget controls also restart the quiet companion when it has stopped; Chrome’s JavaScript-from-Apple-Events setting is unnecessary.

Widget refresh timing is controlled by macOS. Test song changes and playback buttons separately; desktop and Notification Center widgets both use the system’s scheduled refresh behavior. Playback commands use the quiet background companion.
