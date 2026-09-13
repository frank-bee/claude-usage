# claude-usage

Your Claude subscription's real usage in the Claude Code status line — read from Anthropic's own
accounting, never estimated from token counts.

```
🟡 $120/$400 (30%)                  Enterprise seat — the credit pool
🟢 5h 12% ↻14:30 · 🟡 wk 74% ↻Sun   Pro / Max — the rate-limit windows
```

Plans meter different things, so the plugin asks your account which it is and shows only what
applies. **Enterprise seats are the point:** they have no 5h or weekly window, so every other
status line shows them `--`. This one shows the credit pool that actually binds.

## Install

```bash
claude plugin marketplace add frank-bee/claude-usage
claude plugin install claude-usage@claude-usage
```

Then ask Claude:

> add usage to my status line

It detects whether you already have one and asks before changing it — your existing status line is
kept and the segment appended, unless you say otherwise.

## Use

Ask Claude for what you want; it writes the config for you.

> make it a bar · warn me at 60 · drop the colours · just show the percentage

Or check the account directly:

```bash
/usage
```

## Requirements

macOS or Linux, `jq`, `curl`, a Claude Code login.

[Details, script API, troubleshooting →](plugins/claude-usage/README.md) · MIT
