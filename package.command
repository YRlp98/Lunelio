#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
# Packaging must not replace the launch path used by existing development widgets.
LUNELIO_PACKAGING=1 ./build.command Release
python3 Scripts/package-release.py
