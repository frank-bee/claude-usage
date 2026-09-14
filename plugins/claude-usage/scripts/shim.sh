#!/usr/bin/env bash
# claude-usage - stable entry point for the claude-usage plugin.
#
# The plugin's files live in a version-pinned cache directory that moves on
# every update (.../claude-usage/0.3.4/ -> .../0.3.5/), so anything pointing
# straight at them breaks the next time the plugin updates. This resolves the
# current install at call time, so callers keep one fixed path forever.
#
# Copy it once, then never address the plugin any other way:
#   install -m 755 "$P/scripts/shim.sh" ~/.claude/claude-usage
#
#   claude-usage line              the status line segment (default)
#   claude-usage detect            plan + what it meters
#   claude-usage json | fetch      raw response / forced refresh
#   claude-usage statusline        the bundled status line, for settings.json
#   claude-usage wrap '<cmd>' [s]  append the segment to an existing status line
#
# In a status line script you already have, one line is enough:
#   usage_part=$(bash "$HOME/.claude/claude-usage" line 2>/dev/null)

set -uo pipefail

REG="$HOME/.claude/plugins/installed_plugins.json"
P=$(jq -r '.plugins["claude-usage@claude-usage"][0].installPath // empty' "$REG" 2>/dev/null)

# Plugin missing or removed: print nothing rather than break the caller. The
# status line paths are fed stdin by Claude Code, so drain it before leaving.
if [ -z "$P" ] || [ ! -f "$P/scripts/usage.sh" ]; then
  [ -t 0 ] || cat >/dev/null
  exit 0
fi

export CLAUDE_PLUGIN_ROOT="$P"

case "${1:-line}" in
  statusline) exec bash "$P/scripts/statusline.sh" ;;
  wrap)       shift; exec bash "$P/scripts/wrap.sh" "$@" ;;
  *)          exec bash "$P/scripts/usage.sh" "$@" ;;
esac
