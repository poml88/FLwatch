#!/bin/zsh

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage: ./scripts/testflight_internal.sh [--help]

Build a clean App Store archive and upload it for internal TestFlight testing.
Update fastlane/what_to_test/en-GB.txt and set a fresh build number in Xcode
before running; the lane does not increment the build number.

Uses your configured App Store Connect API key and uploads the testing notes.
Requests skipping the full build-processing wait and does not request external
distribution. This script starts immediately, without a confirmation prompt.
The default scheme is FLwatch; FASTLANE_SCHEME can override it.

--help prints this description and exits without running Fastlane.
HELP
  exit 0
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

cd "$repo_root"

bundle exec fastlane testflight_internal
