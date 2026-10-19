#!/usr/bin/env python3
"""Refresh only the widget embedded in the rebuilt development app."""
import os
import signal
import subprocess
import sys
from pathlib import Path


def refresh(app: Path) -> None:
    widget = app / 'Contents/PlugIns/SpotifyMiniWidget.appex/Contents/MacOS/SpotifyMiniWidget'
    if not widget.is_file():
        return
    found = False
    for line in subprocess.check_output(['ps', '-axo', 'pid=,comm='], text=True).splitlines():
        fields = line.strip().split(None, 1)
        if len(fields) != 2:
            continue
        try:
            matches = os.path.samefile(fields[1], widget)
        except OSError:
            continue
        if matches:
            found = True
            try:
                os.kill(int(fields[0]), signal.SIGTERM)
            except ProcessLookupError:
                pass
    if found:
        subprocess.run(['/usr/bin/open', '-g', str(app)], check=True)


if __name__ == '__main__':
    refresh(Path(sys.argv[1]))
