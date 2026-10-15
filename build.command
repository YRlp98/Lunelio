#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
xcodebuild -project Lunelio.xcodeproj -scheme Lunelio -configuration "${1:-Debug}" -destination 'platform=macOS' -derivedDataPath build/DerivedData build
