import importlib.util
import json
import os
import tempfile
import subprocess
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('prepare_resources', Path(__file__).resolve().parents[2] / 'Scripts/prepare-resources.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
token_spec = importlib.util.spec_from_file_location('local_token', Path(__file__).resolve().parents[2] / 'Scripts/prepare-local-token.py')
token_module = importlib.util.module_from_spec(token_spec)
token_spec.loader.exec_module(token_module)


class PrepareResourcesTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / 'Config').mkdir()
        self.version('0.0.2', '0.0.2-beta')
        source = self.root / 'BrowserExtension'
        (source / 'icons').mkdir(parents=True)
        (source / 'manifest.template.json').write_text(json.dumps({'key': 'preserved-extension-key', 'manifest_version': 3}))
        for name in ['player.js', 'content-tail.js', 'worker.js', 'popup.html', 'popup.js']:
            (source / name).write_text(name)
        (source / 'icons/icon16.png').write_bytes(b'icon-fixture')

    def version(self, number, display):
        (self.root / 'Config/Version.xcconfig').write_text(f'MARKETING_VERSION = {number}\nLUNELIO_DISPLAY_VERSION = {display}\n')

    def test_shared_version_and_existing_token_survive_rebuild(self):
        token_module.prepare_token(self.root)
        module.prepare(self.root)
        token = (self.root / '.local/bridge-token.txt').read_bytes()
        self.version('0.0.3', '0.0.3-beta')
        token_module.prepare_token(self.root)
        module.prepare(self.root)
        manifest = json.loads((self.root / 'build/ChromeExtension/manifest.json').read_text())
        self.assertEqual((manifest['version'], manifest['version_name']), ('0.0.3', '0.0.3-beta'))
        self.assertEqual(manifest['key'], 'preserved-extension-key')
        self.assertEqual((self.root / '.local/bridge-token.txt').read_bytes(), token)
        content = (self.root / 'build/ChromeExtension/content.js').read_text()
        self.assertIn('player.js\n);\ncontent-tail.js', content)
        self.assertEqual((self.root / 'build/ChromeExtension/icons/icon16.png').read_bytes(), b'icon-fixture')

    def test_original_connector_path_survives_reload_and_rebuild(self):
        script = Path(__file__).resolve().parents[2] / 'Scripts/register-development-build.sh'
        environment = dict(os.environ, SRCROOT=str(self.root))
        alias = self.root / 'ChromeExtension'
        # The link also survives a missing build output, as during Xcode Clean.
        subprocess.run(['bash', str(script)], env=environment, check=True)
        self.assertTrue(alias.is_symlink())
        self.assertEqual(os.readlink(alias), 'build/ChromeExtension')
        module.prepare(self.root)
        original = (alias / 'manifest.json').read_bytes()
        subprocess.run(['bash', str(script)], env=environment, check=True)
        self.assertEqual((alias / 'manifest.json').read_bytes(), original)
        alias.unlink()
        alias.mkdir()
        sentinel = alias / 'keep.txt'
        sentinel.write_text('existing files')
        result = subprocess.run(['bash', str(script)], env=environment, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(sentinel.read_text(), 'existing files')

    def test_token_is_not_a_cleanable_resource_phase_output(self):
        path = Path(__file__).resolve().parents[2] / 'Lunelio.xcodeproj/project.pbxproj'
        project = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))
        phases = [o for o in project['objects'].values() if o.get('isa') == 'PBXShellScriptBuildPhase']
        for phase in phases:
            self.assertFalse(any('.local' in path for path in phase.get('outputPaths', [])))

    def test_native_project_has_valid_source_file_references(self):
        root = Path(__file__).resolve().parents[2]
        project = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(root / 'Lunelio.xcodeproj/project.pbxproj')]))
        for value in project['objects'].values():
            if value.get('isa') == 'PBXFileReference' and value.get('sourceTree') == 'SOURCE_ROOT':
                path = value['path']
                if not path.startswith(('build/', '.local/')):
                    self.assertTrue((root / path).exists(), path)

    def test_invalid_or_mismatched_versions_are_rejected(self):
        for version, display in [('0.0.0', '0.0.0-beta'), ('0.00.2', '0.00.2-beta'), ('65536.0.1', '65536.0.1'), ('0.0.2-beta', '0.0.2-beta'), ('0.0.2', '0.0.3-beta')]:
            with self.subTest(version=version, display=display):
                self.version(version, display)
                with self.assertRaises(ValueError):
                    module.prepare(self.root)
