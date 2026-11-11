#!/usr/bin/env bash
# wrap.sh - add the usage segment to a status line you already have.
#
#   wrap.sh '<your existing command>' [separator]
#
# Runs your command with the same stdin Claude Code gave us, then appends the
# usage segment to its last line. Your status line keeps working exactly as
# before; if it fails or prints nothing, the usage segment stands alone, and if
# the usage segment is empty your line is passed through untouched.
#
# In ~/.claude/settings.json:
#   "statusLine": {
#     "type": "command",
#     "command": "bash /path/to/wrap.sh '~/.claude/my-statusline.sh'"
#   }

set -uo pipefail

CMD=${1:-}
SEP=${2:- | }
[ -z "$CMD" ] && { echo "usage: wrap.sh '<command>' [separator]" >&2; exit 2; }

input=$(cat)

# Give the wrapped command the untouched stdin payload.
existing=$(printf '%s' "$input" | eval "$CMD" 2>/dev/null)

# Session cost rides on the same stdin; usage.sh shows it only if configured.
if command -v jq >/dev/null 2>&1; then
  cost=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // empty' 2>/dev/null)
else
  cost=$(printf '%s' "$input" | python3 -c "import sys,json; v=json.load(sys.stdin).get('cost',{}).get('total_cost_usd'); print(v if v is not None else '')" 2>/dev/null)
fi

segment=$(CLAUDE_USAGE_SESSION_COST="$cost" bash "${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/scripts/usage.sh" line 2>/dev/null)

if [ -z "$segment" ]; then
  printf '%s\n' "$existing"
elif [ -z "$existing" ]; then
  printf '%s\n' "$segment"
else
  # Append to the LAST line only, so a multi-line status line keeps its shape.
  last=$(printf '%s' "$existing" | tail -n 1)
  rest=$(printf '%s' "$existing" | sed '$d')
  [ -n "$rest" ] && printf '%s\n' "$rest"
  printf '%s%s%s\n' "$last" "$SEP" "$segment"
fi
