#!/usr/bin/env python3
"""Generate browser assets and a local connection token for native Xcode builds."""
import json
import re
import shutil
from pathlib import Path


def prepare(root: Path) -> None:
    settings = {}
    for line in (root / 'Config/Version.xcconfig').read_text().splitlines():
        match = re.fullmatch(r'([A-Z_]+)\s*=\s*(\S+)\s*', line)
        if match:
            settings[match[1]] = match[2]
    version = settings['MARKETING_VERSION']
    display = settings['LUNELIO_DISPLAY_VERSION']
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('MARKETING_VERSION must contain three numeric components')
    components = list(map(int, version.split('.')))
    if not any(components) or any(n > 65535 for n in components):
        raise ValueError('Version is outside Chrome’s supported range')
    if any(str(n) != s for n, s in zip(components, version.split('.'))):
        raise ValueError('Version components must not contain leading zeros')
    if display != version and not display.startswith(version + '-'):
        raise ValueError('Display version must match the numeric version')

    source = root / 'BrowserExtension'
    output = root / 'build/ChromeExtension'
    output.mkdir(parents=True, exist_ok=True)
    manifest = json.loads((source / 'manifest.template.json').read_text())
    manifest.update(version=version, version_name=display)
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    content = 'const readPlayback = () => JSON.parse(\n' + (source / 'player.js').read_text() + '\n);\n' + (source / 'content-tail.js').read_text()
    (output / 'content.js').write_text(content)
    for name in ['worker.js', 'popup.html', 'popup.js']:
        shutil.copy2(source / name, output / name)
    shutil.copytree(source / 'icons', output / 'icons', dirs_exist_ok=True)



if __name__ == '__main__':
    prepare(Path(__file__).resolve().parents[1])
    print('Prepared Chrome connector and local connection resources.')
