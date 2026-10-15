#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
python3 -m unittest discover -s Tests/BuildScripts
xcodebuild -project Lunelio.xcodeproj -scheme Lunelio -destination 'platform=macOS' -derivedDataPath build/DerivedData test
