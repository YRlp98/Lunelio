# Editing Lunelio in Xcode

Open **Lunelio.xcodeproj**, choose **Lunelio → My Mac**, and use **⌘R** to build and run. **⌘B** builds, **⌘U** runs tests, and Product → Archive uses the Release configuration.

## Where to edit

- **Sources/Widget/Widget.swift**: layout, colors, progress bar, cover, controls, timeline provider.
- **Sources/App/App.swift**: settings, menu-bar icon, companion lifecycle.
- **Sources/App/PlayerModel.swift**: playback state, command routing, and connection polling.
- **Sources/App/SpotifyDesktop.swift**: desktop AppleScript connection, permission checks, metadata, and controls.
- **Sources/App/PlaybackSource.swift**: desktop/browser selection rules.
- **Sources/App/BrowserPlayback.swift**: browser profile selection and command delivery.
- **Sources/App/BrowserConnector.swift**: installing the native host and opening Spotify.
- **Sources/App/BridgeServer.swift**: loopback server.
- **Sources/Shared/**: playback data, commands, protocol parsers, local requests, App Intents.
- **Sources/NativeHost/NativeHost.swift**: Chrome native messaging process.
- **BrowserExtension/**: Spotify page reading, commands, tab/window reuse, popup.
- **Tests/LunelioTests/**: Swift Testing checks available in Xcode’s Test navigator.
- **Tests/BuildScripts/**: shared-version and resource-generation checks, included in check.command.

## Targets and build configuration

**Lunelio**, **LunelioWidget**, **LunelioBridge**, and **LunelioTests** are native Xcode targets. **PrepareResources** generates the browser connector before dependent targets copy resources. A scheme pre-build action initializes the private token under **.local/**; Xcode Clean does not remove it. Xcode manages Swift compilation, asset catalogs, App Intents metadata, embedding, signing, and Debug/Release behavior.

The unhosted test bundle compiles the same shared and browser-selection source files as the app. It does not start the companion or require Spotify.

Shared settings live in **Config/Project.xcconfig**, versions in **Config/Version.xcconfig**, and bundle metadata/entitlements in **Config/**. The app and helper retain their internal executable/module names for compatibility with installed widgets and the existing connector.

When adding a widget size, increase **CURRENT_PROJECT_VERSION**, then rebuild and run the app. macOS can cache the available sizes for an existing build; close and reopen Edit Widgets after installing the new build.

## Icons and previews

**Resources/Assets.xcassets** is the app icon catalog. **BrandMark.png** supplies the widget’s empty artwork and settings; **MenuBarIcon.png** is a monochrome template. All earlier concepts remain in **Design/Branding/**, and reference widget images are in **Design/Previews/**.

Run `xcrun swift Tools/CreateIcons.swift` from the project folder to regenerate the artwork and asset catalog, then rebuild. The exporter’s temporary iconset is under **build/**. Xcode compiles the production app icon from the asset catalog.

## Generated files and compatibility

Do not edit **build/ChromeExtension/**; edit **BrowserExtension/** and rebuild. The root app links and old project-location links preserve macOS’s cached widget launch paths. Keep these links while the current installed widgets use them. The native scheme resolves its executable through the app target, so it has no personal absolute Run path.

Build artifacts, connection tokens, and Xcode’s personal state are excluded from Git. The local baseline commit preserves the working prototype before this migration.

## Beta installer

Run **./package.command** to build and create the universal beta DMG in **build/Downloads/**. **Scripts/package-release.py** stages and verifies the installer; **Tests/BuildScripts/test_package_release.py** checks safe staging. The installer uses local signing. Developer ID signing and notarization remain a separate public-release step.
