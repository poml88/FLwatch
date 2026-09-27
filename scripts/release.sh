#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
whats_new_file="$repo_root/fastlane/whats_new/en-GB/release_notes.txt"
localized="0"

if [[ "${1:-}" == "--localized" ]]; then
  localized="1"
  shift
fi

if [[ $# -gt 0 ]]; then
  printf 'Usage: %s [--localized]\n' "$0" >&2
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
