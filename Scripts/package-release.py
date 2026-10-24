#!/usr/bin/env python3
"""Package a universal, locally signed release without changing the development app."""
import hashlib
import json
import plistlib
import shutil
import subprocess
import tempfile
import uuid
from pathlib import Path


def stage_app(source: Path, destination: Path) -> dict:
    widget = Path('Contents/PlugIns/SpotifyMiniWidget.appex')
    info = plistlib.loads((source / 'Contents/Info.plist').read_bytes())
    widget_info = plistlib.loads((source / widget / 'Contents/Info.plist').read_bytes())
    for key in ('CFBundleShortVersionString', 'CFBundleVersion', 'CFBundleGetInfoString'):
        if not info.get(key) or widget_info.get(key) != info[key]:
            raise ValueError(f'App and widget versions must match: {key}')
    connector = json.loads((source / 'Contents/Resources/ChromeExtension/manifest.json').read_text())
    if (connector['version'], connector['version_name']) != (info['CFBundleShortVersionString'], info['CFBundleGetInfoString']):
        raise ValueError('Chrome connector version must match the app')
    # A downloadable release must not share the developer's private connection token.
    tokens = [Path('Contents/Resources/bridge-token.txt'), widget / 'Contents/Resources/bridge-token.txt']
    if any(not (source / path).read_text().strip() for path in tokens):
        raise ValueError('The app and widget need connection resources')
    shutil.copytree(source, destination, symlinks=True, ignore=shutil.ignore_patterns('.DS_Store'))
    for path in destination.rglob('*'):
        if path.is_symlink() and not path.resolve().is_relative_to(destination.resolve()):
            raise ValueError('The packaged app contains a link outside its bundle')
    # Incremental Xcode builds can retain executables after a product rename.
    for obsolete in (Path('Contents/MacOS/SpotifyMini'), Path('Contents/MacOS/SpotifyMiniBridge'),
                     widget / 'Contents/MacOS/SpotifyMiniWidget'):
        (destination / obsolete).unlink(missing_ok=True)
    token = str(uuid.uuid4()) + '\n'
    for path in tokens:
        (destination / path).write_text(token)
        (destination / path).chmod(0o644)
    return info


def package(root: Path) -> Path:
    output = root / 'build/Downloads'
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='lunelio-package-', dir=root / 'build') as temporary:
        stage = Path(temporary)
        app = stage / 'Lunelio.app'
        info = stage_app(root / 'build/Release/Lunelio.app', app)
        shutil.copyfile(root / 'LICENSE', app / 'Contents/Resources/LICENSE')
        shutil.copyfile(root / 'LICENSE', stage / 'LICENSE')
        version = info['CFBundleGetInfoString']
        if not version.startswith(info['CFBundleShortVersionString']) or any(c not in '0123456789abcdefghijklmnopqrstuvwxyz.-' for c in version):
            raise ValueError('Invalid release filename version')
        binaries = [app / 'Contents/MacOS/Lunelio', app / 'Contents/MacOS/LunelioBridge',
                    app / 'Contents/PlugIns/SpotifyMiniWidget.appex/Contents/MacOS/LunelioWidget']
        for binary in binaries:
            arches = subprocess.check_output(['lipo', '-archs', str(binary)], text=True).split()
            if set(arches) != {'arm64', 'x86_64'}:
                raise ValueError(f'A universal build is required: {binary.name}')
        helper, widget = binaries[1], app / 'Contents/PlugIns/SpotifyMiniWidget.appex'
        subprocess.run(['codesign', '--force', '--sign', '-', str(helper)], check=True)
        for bundle, entitlements in [(widget, 'Widget.entitlements'), (app, 'App.entitlements')]:
            subprocess.run(['codesign', '--force', '--sign', '-', '--entitlements', str(root / 'Config' / entitlements), str(bundle)], check=True)
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
        (stage / 'Applications').symlink_to('/Applications')
        (stage / 'Start Here.txt').write_text(f'''LUNELIO {version}

Requires macOS 14 or later. Includes Apple silicon and Intel binaries.
No Xcode or developer tools are needed to use this app.

INSTALL
1. Quit any existing Lunelio app before replacing it.
2. Drag Lunelio.app to Applications.
3. Open Lunelio from Applications, then eject this disk image.
4. Right-click the desktop > Edit Widgets > Lunelio. Add a widget.

CONNECT SPOTIFY DESKTOP (NO EXTENSION)
Open Spotify's native Mac app. In Lunelio Settings, click Connect Spotify Desktop
and approve macOS's request to let Lunelio control Spotify.
Download Spotify: https://www.spotify.com/download/mac/

CONNECT SPOTIFY IN CHROME (OPTIONAL)
In Lunelio Settings, click Add Chrome connector to reveal its folder.
Open chrome://extensions, enable Developer mode, choose Load unpacked,
and select the revealed folder. Open https://open.spotify.com and reload once.
Start a song in Spotify, then use the widget controls. After connector updates,
reload your Spotify tabs. If a freshly reopened tab does not start from the
widget, click Play in Spotify once.
Install the app in Applications before loading the connector; Chrome keeps
using the folder you select.

USE
Use the widget buttons to play, pause, or skip; click the progress bar to seek.
The three dots show Settings and Open Spotify inside the widget.
Automatic selects the playing source, with Desktop taking priority in a tie.
The widget theme follows the system's light or dark appearance automatically.

MACOS INSTALLATION
This app is locally signed, not Developer ID signed or notarized by Apple.
If macOS cannot verify the developer, only proceed if you trust its source.
After trying to open it, use System Settings > Privacy & Security > Open Anyway.
Never override an alert saying the app will damage your computer.
Apple's guidance: https://support.apple.com/en-us/102445

No Premium subscription or API key is required by Lunelio.
Spotify's playback rules still apply. Other browsers and music services,
iOS and iPadOS are not supported yet. macOS may delay widget updates.
''')
        image = output / f'Lunelio-{version}.dmg'
        subprocess.run(['hdiutil', 'create', '-volname', 'Lunelio', '-srcfolder', str(stage), '-format', 'UDZO', '-ov', str(image)], check=True)
        subprocess.run(['hdiutil', 'verify', str(image)], check=True)
        checksum = hashlib.sha256(image.read_bytes()).hexdigest()
        (output / f'{image.name}.sha256').write_text(f'{checksum}  {image.name}\n')
        print(f'Installer: {image}\nLocally signed; public notarization and testing on a clean Mac are still pending.')
        return image


if __name__ == '__main__':
    package(Path(__file__).resolve().parents[1])
