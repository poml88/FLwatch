#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

cd "$repo_root"

bundle exec fastlane testflight_internal
