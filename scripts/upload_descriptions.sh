#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
descriptions_dir="$repo_root/fastlane/app_descriptions"

cd "$repo_root"

printf 'Reminder: did you update all localized descriptions in %s?\n' "$descriptions_dir"
read '?Press Enter to continue or Ctrl-C to cancel. '

bundle exec fastlane upload_descriptions
