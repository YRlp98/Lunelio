#!/bin/bash
set -euo pipefail
[ "${LUNELIO_PACKAGING:-0}" = "1" ] && exit 0
# Existing desktop widgets retain the original launch path across project moves.
project_dir="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
# Chrome retains the unpacked extension path through reloads and restarts.
connector="$project_dir/ChromeExtension"
if [ -e "$connector" ] && [ ! -L "$connector" ]; then
    printf 'Refusing to replace a real connector folder at %s\n' "$connector" >&2
    exit 1
fi
ln -sfn 'build/ChromeExtension' "$connector"
configuration="${CONFIGURATION:-Debug}"
app="$project_dir/build/$configuration/Lunelio.app"
# Scheme post-actions also run after Clean, when no product remains.
[ -d "$app" ] || exit 0
alias="$project_dir/Lunelio.app"
if [ -e "$alias" ] && [ ! -L "$alias" ]; then
    printf 'Refusing to replace a real app at %s\n' "$alias" >&2
    exit 1
fi
ln -sfn "build/$configuration/Lunelio.app" "$alias"
if [ ! -e "$project_dir/Spotify Mini.app" ] && [ ! -L "$project_dir/Spotify Mini.app" ]; then
    ln -s 'Lunelio.app' "$project_dir/Spotify Mini.app"
fi
env -u SWIFT_DEBUG_INFORMATION_FORMAT -u SWIFT_DEBUG_INFORMATION_VERSION /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app"
