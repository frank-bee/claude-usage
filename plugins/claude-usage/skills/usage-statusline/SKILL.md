---
name: usage-statusline
description: Set up or restyle the claude-usage status line - Claude subscription usage and spend in the Claude Code footer. Applies a named style directly, or guides the user through setup when the request is open-ended. Use when asked to show usage/spend/limits in the status line or footer, to change how it looks (bar, gauge, dot, colors, thresholds, format), to set warning or critical levels, when the footer shows nothing or looks stale, or after switching accounts. Triggers - show my usage in the statusline, add spend to my footer, make it a bar, change the warning threshold, usage statusline, /usage.
---

# usage-statusline

Resolve the plugin path first; it is version-pinned and moves on every update:

```bash
P=$(jq -r '.plugins["claude-usage@claude-usage"][0].installPath' ~/.claude/plugins/installed_plugins.json)
```

## Which mode you are in

**The user named a style or a setting** — "make it a bar", "warn me at 60", "no colours", "wider
bar", "ASCII only". Just do it: merge the key into `~/.claude/claude-usage.json` (table under
*Restyling*), re-run `usage.sh line`, show the new output. One or two lines back, no questions, no
wizard. This is the common case; do not turn it into an interview.

**The request is open-ended** — "set up usage in my status line", "show my spend in the footer",
or the footer is broken and they do not know why. Then walk the steps below.

Either way: never make them edit JSON by hand, and always show the resulting line.

---

## Guided setup

### Step 1 — look before touching anything

```bash
bash "$P/scripts/usage.sh" detect                    # their plan and what it meters
jq -r '.statusLine.command // "none"' ~/.claude/settings.json   # what they already have
```

Tell them in one line what their account meters — a credit pool on an Enterprise seat, 5h/weekly
windows on Pro or Max. This is what the segment will show, and it differs per plan, so say it
before they choose anything.

### Step 2 — show them the segment before installing

```bash
bash "$P/scripts/usage.sh" line
```

Paste the actual output. Do not describe it in the abstract.

### Step 3 — ask how it should fit in

**If they have no status line**, say so and offer the bundled one — branch, model, context bar,
usage — then apply it:

```json
"statusLine": { "type": "command", "command": "CLAUDE_PLUGIN_ROOT=\"<P>\" bash \"<P>/scripts/statusline.sh\"" }
```

**If they already have one, never replace it silently.** Show them their current command and ask
which they want (AskUserQuestion, this order):

1. **Keep mine, add usage to it** — suggest this first. Their command runs unchanged with the same
   stdin; the segment is appended to its last line. Multi-line status lines keep their shape, and
   either half still works if the other produces nothing.
   ```json
   "statusLine": { "type": "command", "command": "CLAUDE_PLUGIN_ROOT=\"<P>\" bash \"<P>/scripts/wrap.sh\" '<their existing command>'" }
   ```
   A second argument changes the ` | ` separator.
2. **Replace it** with the bundled `statusline.sh`.
3. **Just give me the snippet** — they wire it in themselves:
   ```bash
   usage=$(bash "<P>/scripts/usage.sh" line)
   ```

### Step 4 — apply, then prove it works

Back up `~/.claude/settings.json` first. After writing, render it without waiting for the footer:

```bash
echo '{"model":{"display_name":"Claude Opus 5"},"context_window":{"used_percentage":34},"cwd":"'$HOME'"}' \
  | bash -c "$(jq -r '.statusLine.command' ~/.claude/settings.json)"
```

Show them that line. If it is wrong, fix it now rather than leaving them to discover it.

## Restyling

Reached either from the guided flow (offer it at the end) or directly when the user names a style.
Merge into `~/.claude/claude-usage.json` — never overwrite it — and **show the new output** by
re-running `usage.sh line`.

| They say | You write |
|---|---|
| make it a bar | `{"style": "bar"}` |
| ASCII only / no unicode | `{"style": "bar-ascii"}` |
| just colour, no icon | `{"style": "plain"}` |
| warn at 60, red at 80 | `{"warn": 60, "crit": 80}` |
| no colours | `{"color": "never"}` |
| wider bar | `{"width": 20}` |
| just the percentage | `{"window": "{name} {pct}", "spend": "{pct}"}` |

Full key list: `style` (`dot`/`bar`/`bar-ascii`/`plain`), `warn`, `crit`, `color`
(`auto`/`always`/`never`), `width`, `separator`, `window`, `spend`. Tokens are `{gauge}` `{name}`
`{pct}` `{reset}` for windows and `{gauge}` `{used}` `{limit}` `{pct}` for spend. Severity drives
glyph *and* colour, so it still reads with colour off.

## Troubleshooting

Run `usage.sh detect` first — it prints the plan and everything the API reports.

| Symptom | Cause |
|---|---|
| No usage segment | The account reports no window and has no credits enabled. Normal; confirm with `detect`. |
| No output at all | No credentials. Check `jq -r '.claudeAiOauth.accessToken' ~/.claude/.credentials.json`. |
| `⚠︎3h` marker | Cache is hours old, usually an expired token. Re-login. |
| Stopped after a plugin update | The install path is version-pinned. Re-resolve `<P>` and rewrite the `statusLine` command. |

## Do not

Do not reintroduce a spend estimate derived from token counts. It cannot tell plan-covered usage
from credit-billed usage, so it disagrees with the real bill. These figures are Anthropic's own
accounting.
