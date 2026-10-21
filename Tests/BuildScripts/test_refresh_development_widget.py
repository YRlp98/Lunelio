import importlib.util
import signal
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('refresh_widget', Path(__file__).resolve().parents[2] / 'Scripts/refresh-development-widget.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class RefreshDevelopmentWidgetTests(unittest.TestCase):
    def test_only_the_rebuilt_widget_is_stopped_including_compatibility_paths(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            app = root / 'My Project/Lunelio.app'
            widget = app / 'Contents/PlugIns/SpotifyMiniWidget.appex/Contents/MacOS/LunelioWidget'
            widget.parent.mkdir(parents=True)
            widget.touch()
            alias = root / 'Old Project'
            alias.symlink_to(app, target_is_directory=True)
            other = root / 'Another Build/LunelioWidget'
            other.parent.mkdir()
            other.touch()
            processes = f'101 {alias}/Contents/PlugIns/SpotifyMiniWidget.appex/Contents/MacOS/LunelioWidget\n102 {other}\n103 {root}/missing\n'
            for race in [False, True]:
                with self.subTest(exited_during_refresh=race), \
                        patch.object(module.subprocess, 'check_output', return_value=processes), \
                        patch.object(module.os, 'kill', side_effect=ProcessLookupError if race else None) as stop, \
                        patch.object(module.subprocess, 'run') as reopen:
                    module.refresh(app)
                    stop.assert_called_once_with(101, signal.SIGTERM)
                    reopen.assert_called_once_with(['/usr/bin/open', '-g', str(app)], check=True)

    def test_no_running_widget_does_not_launch_the_app(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary) / 'Lunelio.app'
            widget = app / 'Contents/PlugIns/SpotifyMiniWidget.appex/Contents/MacOS/LunelioWidget'
            widget.parent.mkdir(parents=True)
            widget.touch()
            with patch.object(module.subprocess, 'check_output', return_value=''), \
                    patch.object(module.os, 'kill') as stop, \
                    patch.object(module.subprocess, 'run') as reopen:
                module.refresh(app)
                stop.assert_not_called()
                reopen.assert_not_called()

    def test_renamed_widget_replaces_only_its_own_legacy_process(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            app = root / 'My Project/Lunelio.app'
            widget = app / 'Contents/PlugIns/SpotifyMiniWidget.appex/Contents/MacOS/LunelioWidget'
            widget.parent.mkdir(parents=True)
            widget.touch()
            alias = root / 'Old Project'
            alias.symlink_to(app, target_is_directory=True)
            legacy = 'Contents/PlugIns/SpotifyMiniWidget.appex/Contents/MacOS/SpotifyMiniWidget'
            processes = f'101 {alias}/{legacy}\n102 {root}/Another.app/{legacy}\n'
            self.assertFalse((app / legacy).exists())
            with patch.object(module.subprocess, 'check_output', return_value=processes), \
                    patch.object(module.os, 'kill') as stop, \
                    patch.object(module.subprocess, 'run') as reopen:
                module.refresh(app)
                stop.assert_called_once_with(101, signal.SIGTERM)
                reopen.assert_called_once_with(['/usr/bin/open', '-g', str(app)], check=True)
