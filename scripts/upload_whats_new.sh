#!/bin/zsh

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage: ./scripts/upload_whats_new.sh [--localized] [--help]

Upload What's New text to the existing editable App Store version.
This lane does not build, upload a binary, or submit the app for review.

By default, uploads fastlane/whats_new/en-GB/release_notes.txt.
With --localized, validates and uploads all ten language files under
fastlane/whats_new/.

Update the notes before running. The script waits for Enter (Ctrl-C cancels)
and uses your configured App Store Connect API key for the upload.

--help prints this description and exits without running Fastlane.
HELP
  exit 0
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
whats_new_file="$repo_root/fastlane/whats_new/en-GB/release_notes.txt"
localized="0"

if [[ "${1:-}" == "--localized" ]]; then
  localized="1"
  shift
fi

if [[ $# -gt 0 ]]; then
  printf 'Usage: %s [--localized] [--help]\n' "$0" >&2
  exit 1
fi

if [[ "$localized" == "1" ]]; then
  whats_new_file="$repo_root/fastlane/whats_new/"
fi

cd "$repo_root"

printf 'Reminder: did you update %s?\n' "$whats_new_file"
read '?Press Enter to continue or Ctrl-C to cancel. '

if [[ "$localized" == "1" ]]; then
  bundle exec fastlane upload_whats_new localized:true
else
  bundle exec fastlane upload_whats_new
fi
