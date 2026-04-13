#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
whats_new_file="$repo_root/fastlane/whats_new/en-GB.txt"

cd "$repo_root"

printf 'Reminder: did you update %s?\n' "$whats_new_file"
read '?Press Enter to continue or Ctrl-C to cancel. '

bundle exec fastlane release
