# claude-usage

## What it shows

| Plan | Binds on | Segment |
|---|---|---|
| Enterprise, usage-based seat | the extra-usage credit pool | `🟡 $120/$400 (30%)` |
| Pro / Max | 5h and weekly rate-limit windows | `🟢 5h 12% ↻14:30 · 🟡 wk 74% ↻Sun` |
| Team | whichever the seat enforces | whatever is reported |

`/api/oauth/profile` gives the plan, `/api/oauth/usage` the numbers. Windows arrive in two shapes —
the generic `limits[]` array and the named `five_hour` / `seven_day*` fields — and either can be
empty at any moment, so both are merged and deduped. Nothing is keyed off the plan name, so a
window type this plugin has never seen still renders.

An account can legitimately report no window: one appears only once there is usage inside it.

## Scripts

```bash
usage.sh line     # the segment, from cache, never blocks   (default)
usage.sh detect   # plan + every window + credits, explained
usage.sh json     # raw API response
usage.sh fetch    # force a refresh, then print
```

`usage.sh line` is the building block — one line of output, independent of everything else. Two
ways to use it:

```bash
# in your own status line
usage=$(bash scripts/usage.sh line)

# or wrap a status line you already have; appends to its last line
bash scripts/wrap.sh '<your existing command>' [separator]
```

`statusline.sh` is bundled as one **example** of composing it — branch, model, context bar, then
the usage segment. Nothing in `usage.sh` depends on it.

## Configuration

`~/.claude/claude-usage.json`, or just ask Claude ("make it a bar", "warn me at 60"). All keys
optional; a missing or malformed file falls back to defaults rather than printing nothing.

```json
{
  "style": "dot",
  "warn": 70,
  "crit": 90,
  "color": "auto",
  "width": 10,
  "separator": " · ",
  "window": "{gauge} {name} {pct}{reset}",
  "spend": "{gauge} {used}/{limit} ({pct})"
}
```

- **style** — `dot` 🟢🟡🔴 · `bar` `▓▓▓▓▓▓▓░░░` · `bar-ascii` `=======---` · `plain` (colour only)
- **color** — `auto` respects `NO_COLOR`, `FORCE_COLOR`, `TERM`, `COLORTERM`. Severity drives glyph
  *and* colour, so it still reads with colour off.
- **tokens** — `{gauge}` `{name}` `{pct}` `{reset}` for windows; `{gauge}` `{used}` `{limit}`
  `{pct}` for spend.

## Behaviour

- Usage cached 5 min, plan 24 h, under `~/.local/state/claude-usage/`, keyed by refresh token so
  accounts never mix.
- `line` prints from cache and refreshes in the background behind a lock — it never blocks a
  render (~100 ms, nearly all of it `jq`).
- A cache older than 30 min is marked `⚠︎Nh` rather than shown as current.
- Sends `User-Agent: claude-code/<version>`; Anthropic rate-limits unidentified clients hard.
- Credentials: `~/.claude/.credentials.json`, else the macOS Keychain item
  `Claude Code-credentials`. `CLAUDE_USAGE_CREDENTIALS` overrides both.

## Not included, deliberately

No spend estimate derived from token counts. It cannot tell plan-covered usage from credit-billed
usage, so it disagrees with the real bill — which is why this exists.
