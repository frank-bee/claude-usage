# claude-usage

Your Claude subscription's real usage in the Claude Code status line — read from Anthropic's own
accounting, never estimated from token counts.

```
🟢 $120/$400 (30%)                  Enterprise seat — the credit pool
🟢 5h 12% ↻14:30 · 🟡 wk 74% ↻Sun   Pro / Max — the rate-limit windows
```

Plans meter different things, so the plugin asks your account which it is and shows only what
applies.

**Enterprise seats are the point.** They have no 5h or weekly window, so every other status line
shows them `--` or nothing. This one shows the credit pool that actually binds.

---

## Install

```bash
claude plugin marketplace add frank-bee/claude-usage
claude plugin install claude-usage@claude-usage
```

Then ask Claude:

> add usage to my status line

It checks what you already have and asks before changing anything. If you already run a status
line, the default is to **keep it and append the segment** — see [Combining with an existing status
line](#combining-with-an-existing-status-line).

Requirements: macOS or Linux, `jq` (1.6+, what Debian stable and Ubuntu jammy ship), `curl`, a Claude Code login.

---

## What it shows

**Enterprise** (usage-based seat) — no 5h or weekly window exists, so the credit pool is the only
thing that binds:

```
🟢 $120/$400 (30%)
```

**Pro / Max** — no credit pool; the rate-limit windows bind:

```
🟢 5h 12% ↻14:30 · 🟡 wk 74% ↻Sun
```

**Team** — whichever the seat enforces. A standard seat looks like Pro; a seat with extra-usage
credits reports both, and both are shown. Team seats can also carry **per-model weekly limits**
(`weekly_scoped`), which are labelled by model:

```
🟢 5h 45% ↻14:30 · 🟢 wk 62% ↻Sun · 🟢 $36/$200 (18%)
🟢 5h 12% ↻14:30 · 🟢 wk 40% ↻Sun · 🟡 Opus 88% ↻Sun · 🟢 Sonnet 21% ↻Sun
```

The Team samples are rendered from constructed responses — I had no Team seat to read from — but
the per-model shape is taken from a project that reads it in production.

`/api/oauth/profile` gives the plan, `/api/oauth/usage` the numbers. Windows arrive in two shapes —
the generic `limits[]` array and the named `five_hour` / `seven_day*` fields — and either can be
empty at any moment, so both are merged and deduped. Nothing is keyed off the plan name, so a
window type this plugin has never seen still renders.

An account can legitimately report no window at all: one appears only once there is usage inside
it. `usage.sh detect` tells you which case you are in.

---

## Styles

Ask Claude — *"make it a bar"*, *"ASCII only"*, *"drop the icons"*. Each block shows the same style
across the kinds of account.

Every sample is real rendered output. The Enterprise and Pro lines come from live accounts; the
Team line is rendered from a constructed response, since I had no Team seat to read.

**`dot`** — the default. Traffic light, readable without colour.

```
Enterprise      🟢 $120/$400 (30%)
Pro / Max       🟢 5h 12% ↻14:30 · 🟡 wk 74% ↻Sun
Team + credits  🟢 5h 45% ↻14:30 · 🟢 wk 62% ↻Sun · 🟢 $36/$200 (18%)
```

**`bar`** — a gauge, like the context-window bar.

```
Enterprise      ▓▓▓░░░░░░░ $120/$400 (30%)
Pro / Max       ▓░░░░░░░░░ 5h 12% ↻14:30 · ▓▓▓▓▓▓▓░░░ wk 74% ↻Sun
Team + credits  ▓▓▓▓░░░░░░ 5h 45% ↻14:30 · ▓▓▓▓▓▓░░░░ wk 62% ↻Sun · ▓░░░░░░░░░ $36/$200 (18%)
```

**`bar-ascii`** — same, for terminals without the block glyphs.

```
Enterprise      ===------- $120/$400 (30%)
Pro / Max       =--------- 5h 12% ↻14:30 · =======--- wk 74% ↻Sun
```

**`plain`** — text only; colour alone carries severity.

```
Enterprise      $120/$400 (30%)
Pro / Max       5h 12% ↻14:30 · wk 74% ↻Sun
```

### Thresholds

`warn` (default 70) and `crit` (default 90) set where the segment turns amber and red. They drive
**both the glyph and the colour**, so severity still reads with colour switched off.

```
🟢 5h 12% ↻14:30 · 🟡 wk 74% ↻Sun     defaults
🟡 5h 12% ↻14:30 · 🔴 wk 74% ↻Sun     {"warn": 10, "crit": 70}
```

### Shaping the text

```
▓▓░░░░░░░░░░░░░░░░░░ 5h 12% ↻14:30 · …     {"style": "bar", "width": 20}
5h 12% · wk 74%                             {"window": "{name} {pct}", "spend": "{pct}"}
▓░░░░░░░░░ 5h  ▓▓▓▓▓▓▓░░░ wk                {"window": "{gauge} {name}", "separator": "  "}
```

---

## Configuration

You should not need to touch this file — ask Claude and it writes it. It lives at
`~/.claude/claude-usage.json`. Every key is optional, and a missing or malformed file falls back to
the defaults rather than printing nothing.

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

| Key | Default | Meaning |
|---|---|---|
| `style` | `dot` | `dot` · `bar` · `bar-ascii` · `plain` |
| `warn` / `crit` | `70` / `90` | percent at which the segment turns amber / red |
| `color` | `auto` | `auto` · `always` · `never` |
| `width` | `10` | bar width in characters |
| `separator` | ` · ` | between segments |
| `window` | `{gauge} {name} {pct}{reset}` | layout of a rate-limit window |
| `spend` | `{gauge} {used}/{limit} ({pct})` | layout of the credit pool |

Tokens — windows: `{gauge}` `{name}` `{pct}` `{reset}`. Spend: `{gauge}` `{used}` `{limit}`
`{pct}`.

`color: auto` respects `NO_COLOR`, `FORCE_COLOR`, `TERM` and `COLORTERM`. The status line is never
a tty (Claude Code captures the output), so env vars are the only signal available.

---

## Combining with an existing status line

`usage.sh line` prints one segment and nothing else. That is the whole integration surface — it has
no opinion about the rest of your line.

### Wrap what you already have

Point your `statusLine` at `wrap.sh` with your existing command as its argument:

```json
"statusLine": {
  "type": "command",
  "command": "bash /path/to/wrap.sh '~/.claude/my-statusline.sh'"
}
```

Your command runs with the same stdin Claude Code gave it, and the segment is appended to its last
line:

```
my line: Opus 5 | 🟢 $120/$400 (30%)
```

A second argument changes the ` | ` separator. Behaviour worth knowing:

- **Multi-line status lines keep their shape** — only the last line gets the segment.
- **If your command fails or prints nothing**, the segment stands alone.
- **If the segment is empty** (an account with nothing to report), your line passes through
  untouched.

### Or call it from your own script

```bash
usage=$(bash /path/to/usage.sh line)
echo "⎇ $branch | $model | $usage"
```

### Or use the bundled example

`statusline.sh` is one **example** of composing it — branch, model, context bar, then the segment.
Nothing in `usage.sh` depends on it; swap it out whenever you like.

```
⎇ main | Opus 5 | ▓▓▓░░░░░░░ 34% ctx | 🟢 $120/$400 (30%)
  └─ statusline.sh ────────────────┘   └─ usage.sh line ─┘
```

---

## Commands

```bash
usage.sh line     # the segment, from cache, never blocks   (default)
usage.sh detect   # plan + every window + credits, explained
usage.sh json     # raw API response
usage.sh fetch    # force a refresh, then print
```

`/usage` runs `detect` and explains the result:

```
subscription  enterprise  (acme-corp)
seat          enterprise_usage_based
status        active

rate limits   none reported right now
              (a window is reported once there is usage inside it)

credits       $120.0 of $400  (30%, normal)
```

---

## Behaviour

- Usage cached 5 min, plan 24 h, under `~/.local/state/claude-usage/`, keyed by refresh token so
  two accounts never read each other's numbers.
- `line` prints from cache and refreshes in the background behind a lock — it never blocks a
  render (~100 ms, nearly all of it `jq`).
- A cache older than 30 min is marked `⚠︎Nh` rather than shown as current.
- Sends `User-Agent: claude-code/<version>`. Anthropic rate-limits unidentified clients on this
  endpoint hard, and several tools have hit persistent 429s without it.
- Credentials: `~/.claude/.credentials.json`, else the macOS Keychain item
  `Claude Code-credentials`. `CLAUDE_USAGE_CREDENTIALS` overrides both.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| No usage segment | The account reports no window and has no credits enabled. Normal — confirm with `detect`. |
| No output at all | No credentials found. Check `jq -r '.claudeAiOauth.accessToken' ~/.claude/.credentials.json`. |
| `⚠︎3h` marker | The cache has not refreshed in hours, usually an expired token. Re-login. |
| `⚠︎ claude-usage: …` marker | The render program failed. The message is truncated to fit the line; the full one is in `${XDG_STATE_HOME:-~/.local/state}/claude-usage/error.log`. |
| Stopped after a plugin update | The install path is version-pinned and moves on every update. Re-resolve it from `~/.claude/plugins/installed_plugins.json` and rewrite the `statusLine` command. |

---

## Not included, deliberately

No spend estimate derived from local token counts. That approach cannot tell plan-covered usage
from credit-billed usage, so it disagrees with the real bill — which is why this exists.

MIT
