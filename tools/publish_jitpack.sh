#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec bash "$repo_root/demos/android/gradlew" --no-daemon -p "$repo_root/publisher" \
  publishSdkPublicationToMavenLocal \
  "-PpublicationGroup=${GROUP:-com.github.qmy1990}" \
  "-PpublicationArtifact=${ARTIFACT:-MediaVision}" \
  "-PpublicationVersion=${VERSION:-0.4.1}" "$@"
