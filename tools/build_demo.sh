#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
case "${1:-}" in
  android)
    shift
    "$ROOT/demos/android/gradlew" -p "$ROOT/demos/android" :app:assembleDebug "$@"
    ;;
  ios)
    shift
    xcodebuild -project "$ROOT/demos/ios/MediaVisionDemo.xcodeproj" \
      -scheme MediaVisionDemo -configuration Release -sdk iphoneos \
      -destination 'generic/platform=iOS' -derivedDataPath "$ROOT/build/ios-demo" \
      CODE_SIGNING_ALLOWED=NO "$@" build
    ;;
  cpp)
    shift
    cmake -S "$ROOT" -B "$ROOT/build/demo" "$@"
    cmake --build "$ROOT/build/demo" --config Release
    ;;
  *) echo 'Usage: tools/build_demo.sh android|ios|cpp [build arguments]' >&2; exit 2 ;;
esac
