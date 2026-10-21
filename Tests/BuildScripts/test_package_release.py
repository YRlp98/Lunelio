import importlib.util
import json
import os
import plistlib
import subprocess
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('package_release', Path(__file__).resolve().parents[2] / 'Scripts/package-release.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PackageReleaseTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.source = self.root / 'source/Lunelio.app'
        self.target = self.root / 'staged/Lunelio.app'
        self.widget = self.source / 'Contents/PlugIns/SpotifyMiniWidget.appex'
        self.info = {'CFBundleShortVersionString': '0.0.3', 'CFBundleVersion': '26', 'CFBundleGetInfoString': '0.0.3-beta'}
        for bundle in (self.source, self.widget):
            (bundle / 'Contents/Resources').mkdir(parents=True)
            (bundle / 'Contents/Info.plist').write_bytes(plistlib.dumps(self.info))
            (bundle / 'Contents/Resources/bridge-token.txt').write_text('private-developer-fixture\n')
        connector = self.source / 'Contents/Resources/ChromeExtension'
        connector.mkdir()
        (connector / 'manifest.json').write_text(json.dumps({'version': '0.0.3', 'version_name': '0.0.3-beta'}))

    def test_packaging_isolates_the_development_token_and_preserves_source(self):
        module.stage_app(self.source, self.target)
        app_token = (self.target / 'Contents/Resources/bridge-token.txt').read_text()
        widget_token = (self.target / 'Contents/PlugIns/SpotifyMiniWidget.appex/Contents/Resources/bridge-token.txt').read_text()
        self.assertTrue(app_token.strip())
        self.assertEqual(app_token, widget_token)
        self.assertNotEqual(app_token, 'private-developer-fixture\n')
        for bundle in (self.source, self.widget):
            self.assertEqual((bundle / 'Contents/Resources/bridge-token.txt').read_text(), 'private-developer-fixture\n')
        script = Path(__file__).resolve().parents[2] / 'Scripts/register-development-build.sh'
        subprocess.run(['bash', str(script)], env=dict(os.environ, SRCROOT=str(self.root), LUNELIO_PACKAGING='1'), check=True)
        self.assertFalse((self.root / 'ChromeExtension').exists())
        self.assertFalse((self.root / 'Lunelio.app').exists())

    def test_packaging_removes_only_staged_obsolete_executables(self):
        binaries = [('Contents/MacOS/SpotifyMini', 'Contents/MacOS/Lunelio'),
                    ('Contents/MacOS/SpotifyMiniBridge', 'Contents/MacOS/LunelioBridge'),
                    ('Contents/PlugIns/SpotifyMiniWidget.appex/Contents/MacOS/SpotifyMiniWidget',
                     'Contents/PlugIns/SpotifyMiniWidget.appex/Contents/MacOS/LunelioWidget')]
        for old, current in binaries:
            for name in (old, current):
                binary = self.source / name
                binary.parent.mkdir(parents=True, exist_ok=True)
                binary.write_bytes(name.encode())
        module.stage_app(self.source, self.target)
        for old, current in binaries:
            self.assertTrue((self.source / old).exists())
            self.assertFalse((self.target / old).exists())
            self.assertEqual((self.target / current).read_bytes(), current.encode())

    def test_mismatched_versions_and_external_links_are_rejected(self):
        bad_info = dict(self.info, CFBundleVersion='25')
        (self.widget / 'Contents/Info.plist').write_bytes(plistlib.dumps(bad_info))
        with self.assertRaisesRegex(ValueError, 'versions must match'):
            module.stage_app(self.source, self.target)
        self.assertFalse(self.target.exists())
        (self.widget / 'Contents/Info.plist').write_bytes(plistlib.dumps(self.info))
        (self.source / 'Contents/external').symlink_to(self.root)
        with self.assertRaisesRegex(ValueError, 'outside its bundle'):
            module.stage_app(self.source, self.target)
