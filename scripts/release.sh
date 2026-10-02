#!/bin/zsh

set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
  cat <<'HELP'
Usage: ./scripts/release.sh [--localized] [--help]

Build a clean App Store archive and upload it with release notes.
Set a fresh build number in Xcode; the lane does not increment it.

By default, uses fastlane/whats_new/en-GB/release_notes.txt for every locale.
With --localized, validates and uses all ten language files under
fastlane/whats_new/. Notes are copied into fastlane/metadata/ for upload.

Update the notes before running. The script waits for Enter (Ctrl-C cancels)
and uses your configured App Store Connect API key.

Set SUBMIT_FOR_REVIEW=1 to submit for App Store review and AUTO_RELEASE=1
to release automatically after approval. Otherwise, these options are off.
The default scheme is FLwatch; FASTLANE_SCHEME can override it.

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
  bundle exec fastlane release localized:true
else
  bundle exec fastlane release
fi
