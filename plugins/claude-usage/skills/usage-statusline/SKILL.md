---
name: usage-statusline
description: Install, remove or troubleshoot the claude-usage status line, which shows what the current Claude subscription meters - 5h/weekly windows on Pro, Team and Max, or dollar credit spend on an Enterprise usage-based seat. Use when asked to show usage or spend in the footer/status line, when the footer shows no usage, when the numbers look stale or wrong, or after switching accounts. Triggers - usage in statusline, show my spend, footer shows nothing, install usage statusline, /usage.
---

# usage-statusline

Wires `scripts/statusline.sh` into the user's `statusLine` setting. Claude Code plugins cannot declare a status line themselves — `statusLine` is a settings key — so this skill does that half.

## Install

1. Read the current setting:
   ```bash
   jq -r '.statusLine // "none"' ~/.claude/settings.json
   ```
2. If one already exists, show it and ask before replacing — the user may have a status line they care about.
3. Write the plugin's script in:
   ```bash
   jq '.statusLine = {"type":"command","command":"bash \"$CLAUDE_PLUGIN_ROOT/scripts/statusline.sh\""}' \
     ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json
   ```
   `$CLAUDE_PLUGIN_ROOT` is not expanded in settings.json, so substitute the real plugin path before writing.
4. Verify without waiting for a render:
   ```bash
   echo '{"model":{"display_name":"Claude Opus 5"},"context_window":{"used_percentage":34},"cwd":"'$HOME'"}' \
     | bash <plugin>/scripts/statusline.sh
   ```

## What each plan shows

| Plan | Segment | Why |
|---|---|---|
| Enterprise (usage-based seat) | `🟡 $120/$400 (30%)` | The credit pool is what binds. Windows are usually absent. |
| Pro / Max | `🟢 5h 12% ↻14:30 · 🟡 wk 74% ↻Sun` | Rate-limit windows bind; credits are disabled. |
| Team | whichever windows the plan reports, plus credits if enabled | Nothing is hardcoded — every reported window renders. |

## Troubleshooting

Run `bash <plugin>/scripts/usage.sh detect` first; it prints the plan and everything the API reports.

- **Footer shows no usage segment.** Expected when the account reports no window and has no credits enabled. Confirm with `detect`.
- **No output at all.** No credentials found. The script reads `~/.claude/.credentials.json`, then the macOS Keychain item `Claude Code-credentials`. Check `jq -r '.claudeAiOauth.accessToken' ~/.claude/.credentials.json` returns a token.
- **`⚠︎3h` marker.** The cache has not refreshed for hours — usually an expired access token. Re-login and check again.
- **Switched accounts and the number did not change.** Caches are keyed by refresh token, so each account has its own file under `~/.local/state/claude-usage/`. A stale figure means that account's own cache is old, not that it read the wrong one.

## Do not

Do not reintroduce a locally computed spend estimate (ccusage token counts × prices). It cannot distinguish plan-covered usage from credit-billed usage, so it disagrees with the real bill. The endpoint's figure is Anthropic's own accounting, in minor units.
