#!/usr/bin/env bash
# usage.sh - Claude subscription usage, straight from Anthropic.
#
# Reads the same two endpoints the Claude apps use, with the account's own OAuth
# token:
#   /api/oauth/profile  what kind of subscription this is
#   /api/oauth/usage    what that subscription meters
#
# The subscription type decides what is even meaningful to show, so nothing is
# hardcoded per tier:
#
#   Enterprise (usage-based seat)  what binds is the extra-usage credit pool,
#                                  reported in `spend`. A 5h window is reported
#                                  too, but only while there is usage inside it.
#   Team / Pro / Max               `spend` is usually disabled; the 5h and weekly
#                                  windows are what bind.
#
# Nothing is keyed off the tier name: every window the account reports is
# rendered, whichever of the two response shapes carries it, so a tier with
# windows we have never seen still renders correctly.
#
#   usage.sh line     cached statusline segment, never blocks (default)
#   usage.sh detect   subscription type + what it meters, human readable
#   usage.sh json     raw usage response
#   usage.sh fetch    force a synchronous refresh, then print the segment
#
# Token resolution, in order:
#   1. $CLAUDE_USAGE_CREDENTIALS if set
#   2. ~/.claude/.credentials.json - Claude Code's own credential file
#   3. macOS Keychain item "Claude Code-credentials"
#
# Caches are keyed by refresh token, which survives access-token rotation, so
# two accounts never read each other's numbers.

set -uo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-usage"
USAGE_TTL="${CLAUDE_USAGE_TTL:-300}"      # usage figures: 5 min
PROFILE_TTL="${CLAUDE_PROFILE_TTL:-86400}" # subscription type: a day
STALE_WARN="${CLAUDE_USAGE_STALE_WARN:-1800}"
BASE="https://api.anthropic.com/api/oauth"

command -v jq >/dev/null 2>&1 || exit 0
mkdir -p "$STATE_DIR"

creds() {
  if [ -n "${CLAUDE_USAGE_CREDENTIALS:-}" ] && [ -r "$CLAUDE_USAGE_CREDENTIALS" ]; then
    cat "$CLAUDE_USAGE_CREDENTIALS"; return 0
  fi
  local f="$HOME/.claude/.credentials.json"
  [ -r "$f" ] && cat "$f" && return 0
  security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null
}

c=$(creds)
[ -z "$c" ] && exit 0
token=$(printf '%s' "$c" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
[ -z "$token" ] && exit 0

key=$(printf '%s' "$c" | jq -r '.claudeAiOauth.refreshToken // .claudeAiOauth.accessToken' 2>/dev/null \
        | shasum -a 256 | cut -c1-16)
USAGE_CACHE="$STATE_DIR/$key.usage.json"
PROFILE_CACHE="$STATE_DIR/$key.profile.json"

age_of() {
  [ -f "$1" ] || { echo 999999; return; }
  echo $(( $(date +%s) - $(jq -r '._fetched_at // 0' "$1" 2>/dev/null || echo 0) ))
}

# $1 = endpoint, $2 = cache file, $3 = jq guard that must hold for a valid body
get() {
  local out
  out=$(curl -sS --max-time 8 "$BASE/$1" \
          -H "Authorization: Bearer $token" \
          -H "anthropic-beta: oauth-2025-04-20" 2>/dev/null) || return 1
  printf '%s' "$out" | jq -e "$3" >/dev/null 2>&1 || return 1
  printf '%s' "$out" | jq --argjson t "$(date +%s)" '. + {_fetched_at: $t}' > "$2.tmp" \
    && mv "$2.tmp" "$2"
}

fetch_usage()   { get usage   "$USAGE_CACHE"   'has("limits") or has("spend")'; }
fetch_profile() { get profile "$PROFILE_CACHE" 'has("organization") or has("account")'; }

# Subscription type, as a single lowercase word: enterprise | team | max | pro |
# free | unknown. organization_type is authoritative where present; the account
# flags are the fallback for a personal login with no org.
tier() {
  [ -f "$PROFILE_CACHE" ] || return 0
  jq -r '
    (.organization.organization_type // "") as $o
    | if   $o | test("enterprise") then "enterprise"
      elif $o | test("team")       then "team"
      elif $o | test("max")        then "max"
      elif $o | test("pro")        then "pro"
      elif .account.has_claude_max then "max"
      elif .account.has_claude_pro then "pro"
      elif $o != ""                then $o
      else "unknown" end
  ' "$PROFILE_CACHE" 2>/dev/null
}

# One statusline segment per thing this subscription actually meters.
#
# Two shapes carry the same windows and either may be empty at any moment:
# `limits[]` (generic, forward-compatible) and the named `five_hour` /
# `seven_day` / `seven_day_*` fields. Enterprise in particular reports []
# in limits while still populating five_hour once a window is live, so both
# are normalised into one list and deduped by kind.
WINDOWS_JQ='
  def norm:
    [ ( (.limits // [])[]
        | select(.percent != null)
        | {kind: .kind, percent: .percent, resets_at: .resets_at} ),
      ( {session: .five_hour, weekly_all: .seven_day,
         weekly_opus: .seven_day_opus, weekly_sonnet: .seven_day_sonnet}
        | to_entries[]
        | select(.value != null and .value.utilization != null)
        | {kind: .key, percent: .value.utilization, resets_at: .value.resets_at} ) ]
    | group_by(.kind) | map(.[0]);
'
render() {
  [ -f "$USAGE_CACHE" ] || return 0
  jq -r --argjson age "$(age_of "$USAGE_CACHE")" --argjson warn "$STALE_WARN" "
    $WINDOWS_JQ"'
    def dot($p): if $p >= 90 then "🔴" elif $p >= 70 then "🟡" else "🟢" end;
    def at($t; $fmt): ($t | sub("\\.[0-9]+";"") | sub("\\+00:00$";"Z")
                          | fromdateiso8601 | strflocaltime($fmt));
    # a session window resets today, so a clock reads best; anything weekly
    # resets days out, where the weekday is the useful part
    def wname($k):
      if   $k == "session"    then {name: "5h",   fmt: "%H:%M"}
      elif $k == "weekly_all" then {name: "wk",   fmt: "%a"}
      elif $k | startswith("weekly_")
           then {name: ($k | ltrimstr("weekly_")), fmt: "%a"}
      else {name: $k, fmt: "%a"} end;

    [ ( norm[]
        | wname(.kind) as $l
        | dot(.percent) + " " + $l.name + " " + (.percent | floor | tostring) + "%"
          + (if .resets_at then " ↻" + at(.resets_at; $l.fmt) else "" end) ),

      ( if (.spend.enabled == true) and ((.spend.limit.amount_minor // 0) > 0)
        then (.spend.percent // 0) as $p
          | dot($p)
            + " $" + ((.spend.used.amount_minor / 100) | floor | tostring)
            + "/$" + ((.spend.limit.amount_minor / 100) | floor | tostring)
            + " (" + ($p | floor | tostring) + "%)"
        else empty end )
    ]
    | join(" · ")
    | if . == "" then empty
      elif $age > $warn then . + " ⚠︎" + (($age / 3600) | floor | tostring) + "h"
      else . end
  ' "$USAGE_CACHE" 2>/dev/null
}

refresh_if_stale() {
  [ "$(age_of "$PROFILE_CACHE")" -ge "$PROFILE_TTL" ] && fetch_profile
  [ "$(age_of "$USAGE_CACHE")" -ge "$USAGE_TTL" ] && fetch_usage
  return 0
}

case "${1:-line}" in
  line)
    # Print what we have immediately; refresh in the background for next render.
    # The lock stops a burst of statusline renders firing parallel curls.
    if [ "$(age_of "$USAGE_CACHE")" -ge "$USAGE_TTL" ]; then
      lock="$STATE_DIR/.fetch.lock"
      if mkdir "$lock" 2>/dev/null; then
        ( trap 'rmdir "$lock" 2>/dev/null' EXIT; refresh_if_stale ) >/dev/null 2>&1 &
        disown 2>/dev/null
      elif [ -d "$lock" ] && [ $(( $(date +%s) - $(stat -f %m "$lock" 2>/dev/null || echo 0) )) -gt 60 ]; then
        rmdir "$lock" 2>/dev/null   # clear a lock left behind by a killed fetch
      fi
    fi
    render
    ;;

  fetch)
    fetch_profile >/dev/null 2>&1
    fetch_usage && render
    ;;

  json)
    refresh_if_stale
    cat "$USAGE_CACHE" 2>/dev/null
    ;;

  detect)
    refresh_if_stale
    t=$(tier)
    [ -z "$t" ] && { echo "No subscription info - not logged in, or the token is expired."; exit 1; }

    jq -r --arg t "$t" '
      "subscription  " + $t
        + (if .organization.name then "  (" + .organization.name + ")" else "" end)
        + (if .organization.seat_tier then "\nseat          " + .organization.seat_tier else "" end)
        + (if .organization.subscription_status
           then "\nstatus        " + .organization.subscription_status else "" end)
    ' "$PROFILE_CACHE" 2>/dev/null

    jq -r "$WINDOWS_JQ"'
      def at($t): ($t | sub("\\.[0-9]+";"") | sub("\\+00:00$";"Z")
                      | fromdateiso8601 | strflocaltime("%a %H:%M"));
      norm as $w
      | "",
      (if ($w | length) == 0
       then "rate limits   none reported right now\n              (a window is reported once there is usage inside it)"
       else "rate limits   " + (($w | length) | tostring) + " window(s)" end),
      ($w[]
        | "  " + (.kind) + "  " + (.percent | floor | tostring) + "%"
          + (if .resets_at then "  resets " + at(.resets_at) else "" end)),
      "",
      (if .spend.enabled == true
       then "credits       $" + ((.spend.used.amount_minor / 100) | tostring)
              + " of $" + ((.spend.limit.amount_minor / 100) | tostring)
              + "  (" + ((.spend.percent // 0) | floor | tostring) + "%, "
              + (.spend.severity // "normal") + ")"
       else "credits       not enabled on this account" end)
    ' "$USAGE_CACHE" 2>/dev/null
    ;;

  *)
    echo "usage: usage.sh [line|detect|json|fetch]" >&2
    exit 2
    ;;
esac
