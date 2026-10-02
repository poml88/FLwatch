#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
whats_new_file="$repo_root/fastlane/whats_new/en-GB/release_notes.txt"

submit="0"
auto_release="0"
build_number=""
localized="0"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/release_existing_build.sh [--submit] [--auto-release] [--build BUILD_NUMBER] [--localized]

Prepare an App Store release using an already uploaded, processed build.
This lane does not build or upload a binary. It updates What's New on the
existing editable App Store version using English for every locale by default,
or all ten language files under fastlane/whats_new/ with --localized.

Update the notes before running. The script waits for Enter (Ctrl-C cancels)
and uses your configured App Store Connect API key. Submission and automatic
release are off unless the corresponding options below are supplied.

Options:
  --submit          Submit the selected build for App Store review
  --auto-release    Automatically release after approval
  --build NUMBER    Use a specific processed App Store Connect build number
  --localized       Upload all localized What's New files instead of using English for every locale
  --help            Show this help

Examples:
  ./scripts/release_existing_build.sh --submit --build 150
  ./scripts/release_existing_build.sh --submit --auto-release --build 150
  ./scripts/release_existing_build.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --submit)
      submit="1"
      shift
      ;;
    --auto-release)
      auto_release="1"
      shift
      ;;
    --build)
      if [[ $# -lt 2 ]]; then
        printf 'Error: --build requires a value.\n' >&2
        usage
        exit 1
      fi
      build_number="$2"
      shift 2
      ;;
    --localized)
      localized="1"
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Error: unknown option %s\n' "$1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -n "$build_number" && ! "$build_number" =~ ^[0-9]+$ ]]; then
  printf 'Error: build number must be numeric.\n' >&2
  exit 1
fi

if [[ "$localized" == "1" ]]; then
  whats_new_file="$repo_root/fastlane/whats_new/"
fi

cd "$repo_root"

export SUBMIT_FOR_REVIEW="$submit"
export AUTO_RELEASE="$auto_release"

if [[ -n "$build_number" ]]; then
  export APP_STORE_BUILD_NUMBER="$build_number"
else
  unset APP_STORE_BUILD_NUMBER 2>/dev/null || true
fi

printf 'Reminder: did you update %s?\n' "$whats_new_file"
read '?Press Enter to continue or Ctrl-C to cancel. '

printf 'Running release_existing_build'
if [[ "$submit" == "1" ]]; then
  printf ' with submit_for_review'
fi
if [[ "$auto_release" == "1" ]]; then
  printf ' with automatic_release'
fi
if [[ -n "$build_number" ]]; then
  printf ' for build %s' "$build_number"
fi
printf '\n'

if [[ "$localized" == "1" ]]; then
  bundle exec fastlane release_existing_build localized:true
else
  bundle exec fastlane release_existing_build
fi
