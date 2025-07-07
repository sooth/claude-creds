#!/usr/bin/env bash
# claude-creds.sh – save / restore multiple Claude CLI log-ins
#   backup  <profile>         → export current tokens to  $CREDS_DIR/<profile>.json
#   switch  <profile>         → restore tokens from that file (alias for restore)
#   restore <profile>         → same as switch
#   list                      → show available profiles
# Optional flags:
#   --service <keychain-name> → override Keychain “Service” label
#   CLAUDE_CREDS_DIR=…        → override storage directory

set -euo pipefail

# ---------------------------------------------------------------------------
# Tunables
DEFAULT_SERVICES=("Claude Code-credentials" "Claude Code")
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
CREDS_DIR="${CLAUDE_CREDS_DIR:-$HOME/.claude/cred_profiles}"
mkdir -p "$CREDS_DIR"

# ---------------------------------------------------------------------------
# Helpers
die()  { printf >&2 "❌  %s\n" "$*"; exit 1; }
note() { printf      "💡  %s\n" "$*"; }

usage() {
  cat <<EOF
Usage: $0 [--service NAME] {backup|switch|restore|list} [profile]
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

# Determine which Keychain “service” name to use
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
  echo "✅  Restored Claude credentials for profile '$profile'"
}

list_profiles() {
  shopt -s nullglob
  local files=("$CREDS_DIR"/*.json)
  if (( ${#files[@]} == 0 )); then
    note "No profiles saved yet. Run '$0 backup <name>' first."
  else
    echo "📂  Saved profiles:"
    for f in "${files[@]}"; do basename "$f" .json; done | sort
  fi
}

# ---------------------------------------------------------------------------
# Dispatch
case $CMD in
  backup)
    [[ $# -eq 1 ]] || die "backup requires a profile name"
    backup "$1"
    ;;
  switch|restore)
    [[ $# -eq 1 ]] || die "$CMD requires a profile name"
    restore "$1"
    ;;
  list)
    list_profiles
    ;;
  *)
    usage
    ;;
esac

