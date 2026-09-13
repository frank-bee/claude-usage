# claude-usage

Shows what your Claude subscription actually meters, in the Claude Code status line — read straight from Anthropic, never estimated.

```
⎇ main | @w | Opus 5 | ▓▓▓░░░░░░░ 34% ctx | 🟡 $120/$400 (30%)     # Enterprise
⎇ main | @p | Opus 5 | ▓▓▓░░░░░░░ 34% ctx | 🟢 5h 12% ↻14:30 · 🟡 wk 74% ↻Sun   # Pro
```

## Why it detects the plan

What is worth showing differs per subscription, so the plugin asks the account rather than assuming:

| Plan | What binds | What renders |
|---|---|---|
| Enterprise, usage-based seat | the extra-usage credit pool | `$used/$limit (pct)` |
| Pro / Max | 5h and weekly rate-limit windows | one segment per window |
| Team | whichever of the two the seat enforces | whatever is reported |

`/api/oauth/profile` gives the plan (`organization.organization_type`, `seat_tier`); `/api/oauth/usage` gives the numbers. Windows arrive in two shapes — the generic `limits[]` array and the named `five_hour` / `seven_day*` fields — and either can be empty at a given moment, so both are normalised and deduped. Nothing is keyed off the plan name, so a window type this plugin has never seen still renders.

An account can correctly report no window at all: a window appears only once there is usage inside it.

## Commands

```bash
usage.sh line     # statusline segment from cache, never blocks  (default)
usage.sh detect   # plan + every window + credits, human readable
usage.sh json     # raw API response
usage.sh fetch    # force a synchronous refresh, then print
```

`/usage` runs `detect` and explains the result.

## Install the status line

Ask Claude to "install the usage statusline" — the `usage-statusline` skill writes the `statusLine` key into `~/.claude/settings.json`. Plugins cannot declare a status line themselves.

## Behaviour

- Usage cached 5 min, plan cached 24 h, both under `~/.local/state/claude-usage/`, keyed by refresh token so accounts never mix.
- `line` prints the cached value immediately and refreshes in the background behind a lock — it never blocks a render. Measured ~100 ms per render, nearly all of it `jq`.
- A cache older than 30 min is marked `⚠︎Nh` rather than shown as current.
- Credentials come from `~/.claude/.credentials.json` (Claude Code's own path, which clauth symlinks when it manages the account), else the macOS Keychain. `CLAUDE_USAGE_CREDENTIALS` overrides for testing another account.
- clauth is optional. Without it the `@profile` label is simply omitted; everything else is unchanged.

## Not included, deliberately

No locally computed spend estimate. Deriving dollars from token counts cannot tell plan-covered usage from credit-billed usage, so it disagrees with the real bill — which is exactly why this plugin exists.
