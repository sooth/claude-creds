#!/usr/bin/env bash
# claude-creds.sh – save / restore multiple Claude CLI log-ins
#   backup  <profile>         → export current tokens to  $CREDS_DIR/<profile>.json
#   use     <profile>         → restore tokens from that profile
#   restore <profile>         → same as use
#   delete  <profile>         → delete a saved profile
#   switch                    → cycle to the next available profile
#   list                      → show available profiles
#   current                   → show current active profile
# Optional flags:
#   --service <keychain-name> → override Keychain "Service" label
#   CLAUDE_CREDS_DIR=…        → override storage directory

set -euo pipefail

# ---------------------------------------------------------------------------
# Tunables
DEFAULT_SERVICES=("Claude Code-credentials" "Claude Code")
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
CREDS_DIR="${CLAUDE_CREDS_DIR:-$HOME/.claude/cred_profiles}"
CURRENT_PROFILE_FILE="$CREDS_DIR/.current_profile"
mkdir -p "$CREDS_DIR"

# ---------------------------------------------------------------------------
# Helpers
die()  { printf >&2 "❌  %s\n" "$*"; exit 1; }
note() { printf      "💡  %s\n" "$*"; }

usage() {
  cat <<EOF
Usage: $0 [--service NAME] {backup|use|restore|delete|switch|list|current} [profile]

Commands:
  backup  <profile>  Export current tokens to profile
  use     <profile>  Restore tokens from profile
  restore <profile>  Same as use
  delete  <profile>  Delete a saved profile
  switch             Cycle to next available profile
  list               Show available profiles
  current            Show current active profile
EOF
  exit 1
}

json_get() {  # json_get FILE KEY → prints value
  /usr/bin/python3 - <<PY "$1" "$2"
import json, sys, pathlib
with open(sys.argv[1]) as f:
    print(json.load(f).get(sys.argv[2], ""))
PY
}

# ---------------------------------------------------------------------------
# Argument parsing (flags first, then command)
SERVICE_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --service) SERVICE_OVERRIDE=$2; shift 2 ;;
    -*        ) usage ;;
    *         ) CMD=$1; shift; break ;;
  esac
done
[[ -z "${CMD:-}" ]] && usage

# Determine which Keychain "service" name to use
if [[ -n $SERVICE_OVERRIDE ]]; then
  SERVICE="$SERVICE_OVERRIDE"
else
  SERVICE=""
  for s in "${DEFAULT_SERVICES[@]}"; do
    if security find-generic-password -s "$s" >/dev/null 2>&1; then
      SERVICE="$s"; break
    fi
  done
  [[ -n $SERVICE ]] || die "Claude credential not found. Run 'claude /login' first or use --service."
fi

# ---------------------------------------------------------------------------
# Commands
backup() {
  local profile=$1
  [[ $profile =~ ^[A-Za-z0-9_-]+$ ]] || die "Profile may contain letters, numbers, _ or - only"

  # Pull account field
  local account
  account=$(security find-generic-password -s "$SERVICE" -g 2>&1 |
            awk -F'"' '/"acct"<blob>/{print $4}')
  [[ -n $account ]] || die "Account field empty in Keychain item"

  # Read the password (may trigger Touch ID/Allow prompt)
  local pw
  if ! pw=$(security find-generic-password -s "$SERVICE" -w 2>/dev/null); then
    die "Keychain denied read access. Approve the prompt, then rerun."
  fi

  local file="$CREDS_DIR/$profile.json"
  # Use Python to properly create JSON with escaped values
  /usr/bin/python3 - <<PY >"$file"
import json
data = {"service": "$SERVICE", "account": "$account", "password": """$pw"""}
print(json.dumps(data))
PY
  chmod 600 "$file"
  echo "✅  Saved profile '$profile' → $file"
}

restore() {
  local profile=$1
  local file="$CREDS_DIR/$profile.json"
  [[ -r $file ]] || die "Profile '$profile' not found in $CREDS_DIR"

  local svc acct pw
  svc=$( json_get "$file" service  )
  acct=$(json_get "$file" account )
  pw=$(  json_get "$file" password)

  security add-generic-password -U \
           -a "$acct" -s "$svc" -w "$pw" "$KEYCHAIN" >/dev/null
  echo "$profile" > "$CURRENT_PROFILE_FILE"
  echo "✅  Restored Claude credentials for profile '$profile'"
}

list_profiles() {
  shopt -s nullglob
  local files=("$CREDS_DIR"/*.json)
  if (( ${#files[@]} == 0 )); then
    note "No profiles saved yet. Run '$0 backup <name>' first."
  else
    local current=""
    [[ -r "$CURRENT_PROFILE_FILE" ]] && current=$(<"$CURRENT_PROFILE_FILE")
    echo "📂  Saved profiles:"
    for f in "${files[@]}"; do
      local name
      name=$(basename "$f" .json)
      if [[ "$name" == "$current" ]]; then
        echo "→ $name (current)"
      else
        echo "  $name"
      fi
    done | sort
  fi
}

delete() {
  local profile=$1
  local file="$CREDS_DIR/$profile.json"
  [[ -r $file ]] || die "Profile '$profile' not found"
  
  # Check if this is the current profile
  local current=""
  [[ -r "$CURRENT_PROFILE_FILE" ]] && current=$(<"$CURRENT_PROFILE_FILE")
  
  rm -f "$file"
  echo "🗑️  Deleted profile '$profile'"
  
  # Clear current profile if we deleted it
  if [[ "$profile" == "$current" ]]; then
    rm -f "$CURRENT_PROFILE_FILE"
    note "Current profile was deleted. Use 'switch' or 'use' to select another."
  fi
}

current_profile() {
  if [[ -r "$CURRENT_PROFILE_FILE" ]]; then
    local current=$(<"$CURRENT_PROFILE_FILE")
    echo "🔵  Current profile: $current"
  else
    echo "⚪  No current profile set"
  fi
}

switch_next() {
  shopt -s nullglob
  local files=("$CREDS_DIR"/*.json)
  
  if (( ${#files[@]} == 0 )); then
    die "No profiles saved yet. Run '$0 backup <name>' first."
  elif (( ${#files[@]} == 1 )); then
    local only_profile
    only_profile=$(basename "${files[0]}" .json)
    restore "$only_profile"
    return
  fi
  
  # Get sorted list of profiles
  local profiles=()
  for f in "${files[@]}"; do
    profiles+=($(basename "$f" .json))
  done
  IFS=$'\n' profiles=($(sort <<<"${profiles[*]}"))
  unset IFS
  
  # Find current profile index
  local current=""
  local current_idx=-1
  [[ -r "$CURRENT_PROFILE_FILE" ]] && current=$(<"$CURRENT_PROFILE_FILE")
  
  for i in "${!profiles[@]}"; do
    if [[ "${profiles[$i]}" == "$current" ]]; then
      current_idx=$i
      break
    fi
  done
  
  # Calculate next index (wrap around)
  local next_idx=$(( (current_idx + 1) % ${#profiles[@]} ))
  local next_profile="${profiles[$next_idx]}"
  
  echo "🔄  Switching from '$current' to '$next_profile'"
  restore "$next_profile"
}

# ---------------------------------------------------------------------------
# Dispatch
case $CMD in
  backup)
    [[ $# -eq 1 ]] || die "backup requires a profile name"
    backup "$1"
    ;;
  use|restore)
    [[ $# -eq 1 ]] || die "$CMD requires a profile name"
    restore "$1"
    ;;
  delete)
    [[ $# -eq 1 ]] || die "delete requires a profile name"
    delete "$1"
    ;;
  switch)
    [[ $# -eq 0 ]] || die "switch takes no arguments"
    switch_next
    ;;
  list)
    list_profiles
    ;;
  current)
    current_profile
    ;;
  *)
    usage
    ;;
esac