#!/bin/zsh

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage: ./scripts/upload_descriptions.sh [--help]

Validate and upload all ten localized app descriptions under
fastlane/app_descriptions/ to the existing editable App Store version.
This lane does not build, upload a binary, or submit the app for review.

Update the descriptions before running. The script waits for Enter
(Ctrl-C cancels) and uses your configured App Store Connect API key.

--help prints this description and exits without running Fastlane.
HELP
  exit 0
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
descriptions_dir="$repo_root/fastlane/app_descriptions"

cd "$repo_root"

printf 'Reminder: did you update all localized descriptions in %s?\n' "$descriptions_dir"
read '?Press Enter to continue or Ctrl-C to cancel. '

bundle exec fastlane upload_descriptions
