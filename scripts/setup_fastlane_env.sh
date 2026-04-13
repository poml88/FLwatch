#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
env_file="$repo_root/.env.fastlane.local"

prompt() {
  local label="$1"
  local current_value="${2-}"
  local value

  if [[ -n "$current_value" ]]; then
    read "?$label [$current_value]: " value
    printf '%s\n' "${value:-$current_value}"
  else
    read "?$label: " value
    printf '%s\n' "$value"
  fi
}

normalize_path() {
  local path_value="$1"

  if [[ -z "$path_value" ]]; then
    return
  fi

  if [[ "$path_value" == ~* ]]; then
    path_value="${path_value/#\~/$HOME}"
  fi

  if [[ "$path_value" != /* ]]; then
    path_value="$(cd "$(dirname "$path_value")" 2>/dev/null && pwd)/$(basename "$path_value")"
  fi

  printf '%s\n' "$path_value"
}

escape_env() {
  printf '%s' "$1" | sed "s/'/'\\\\''/g"
}

existing_key_id=""
existing_issuer_id=""
existing_key_path=""
existing_groups="External"

if [[ -f "$env_file" ]]; then
  existing_key_id="$(sed -n -e 's/^FASTLANE_APP_STORE_CONNECT_API_KEY_ID=//p' -e 's/^APP_STORE_CONNECT_API_KEY_ID=//p' "$env_file" | tail -n 1)"
  existing_issuer_id="$(sed -n -e 's/^FASTLANE_APP_STORE_CONNECT_API_KEY_ISSUER_ID=//p' -e 's/^FASTLANE_APP_STORE_CONNECT_ISSUER_ID=//p' -e 's/^APP_STORE_CONNECT_ISSUER_ID=//p' "$env_file" | tail -n 1)"
  existing_key_path="$(sed -n -e 's/^FASTLANE_APP_STORE_CONNECT_API_KEY_PATH=//p' -e 's/^APP_STORE_CONNECT_API_KEY_PATH=//p' "$env_file" | tail -n 1)"
  existing_groups="$(sed -n 's/^TESTFLIGHT_EXTERNAL_GROUPS=//p' "$env_file" | tail -n 1)"
fi

printf 'Fastlane env setup for LibreWrist\n'
printf 'This writes local secrets to %s\n\n' "$env_file"

key_id="$(prompt 'App Store Connect API key id' "$existing_key_id")"
issuer_id="$(prompt 'App Store Connect issuer id' "$existing_issuer_id")"
key_path_raw="$(prompt 'Path to the downloaded .p8 key file' "$existing_key_path")"
groups="$(prompt 'External TestFlight groups (comma-separated)' "$existing_groups")"

key_path="$(normalize_path "$key_path_raw")"

if [[ -z "$key_id" || -z "$issuer_id" || -z "$key_path" ]]; then
  printf '\nError: key id, issuer id, and key path are required.\n' >&2
  exit 1
fi

if [[ ! -f "$key_path" ]]; then
  printf '\nError: key file not found at %s\n' "$key_path" >&2
  exit 1
fi

cat > "$env_file" <<EOF
FASTLANE_APP_STORE_CONNECT_API_KEY_ID='$(escape_env "$key_id")'
FASTLANE_APP_STORE_CONNECT_API_KEY_ISSUER_ID='$(escape_env "$issuer_id")'
FASTLANE_APP_STORE_CONNECT_API_KEY_PATH='$(escape_env "$key_path")'
TESTFLIGHT_EXTERNAL_GROUPS='$(escape_env "$groups")'
EOF

printf '\nSaved %s\n' "$env_file"
printf 'You can now run:\n'
printf '  bundle exec fastlane testflight_internal\n'
