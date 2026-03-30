#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
what_to_test_file="$repo_root/fastlane/what_to_test/en-US.txt"

cd "$repo_root"

printf 'Reminder: did you update %s?\n' "$what_to_test_file"
read '?Press Enter to continue or Ctrl-C to cancel. '

bundle exec fastlane testflight_external
