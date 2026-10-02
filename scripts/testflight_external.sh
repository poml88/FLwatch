#!/bin/zsh

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage: ./scripts/testflight_external.sh [--help]

Build and upload a new archive for external TestFlight testers.

Before running:
  - Update fastlane/what_to_test/en-GB.txt with the testing notes.
  - Set a fresh build number in Xcode; the lane does not increment it.
  - Ensure your App Store Connect API key is configured.

Workflow:
  1. Reminds you about the testing notes and waits for Enter (Ctrl-C cancels).
  2. Creates a clean App Store archive.
  3. Uploads it to TestFlight using your configured API key.
  4. Waits for Apple's build processing.
  5. Requests external distribution to TESTFLIGHT_EXTERNAL_GROUPS
     (default: External), with tester notifications enabled.

Each run builds a new archive. Testing notes come from the What to Test
file above, not the App Store What's New notes. External availability
remains subject to Apple's beta review requirements.

Configuration loads from .env.fastlane.local and fastlane/.env.
The default scheme is FLwatch; FASTLANE_SCHEME can override it.

--help prints this description and exits without running Fastlane.
HELP
  exit 0
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
what_to_test_file="$repo_root/fastlane/what_to_test/en-GB.txt"

cd "$repo_root"

printf 'Reminder: did you update %s?\n' "$what_to_test_file"
read '?Press Enter to continue or Ctrl-C to cancel. '

bundle exec fastlane testflight_external
