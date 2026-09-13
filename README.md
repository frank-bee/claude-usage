# claude-usage

A Claude Code plugin that shows what your Claude subscription actually meters — read straight from Anthropic's own usage endpoint, never estimated from token counts.

```
⎇ main | Opus 5 | ▓▓▓░░░░░░░ 34% ctx | 🟡 $120/$400 (30%)                  # Enterprise seat
⎇ main | Opus 5 | ▓▓▓░░░░░░░ 34% ctx | 🟢 5h 12% ↻14:30 · 🟡 wk 74% ↻Sun   # Pro / Max
```

Different plans meter different things, so the plugin asks the account instead of assuming: an Enterprise usage-based seat is bounded by a dollar credit pool, while Pro and Max are bounded by 5h and weekly rate-limit windows. Whatever your plan reports is what you see.

## Install

```bash
claude plugin marketplace add frank-bee/claude-usage
claude plugin install claude-usage@claude-usage
```

Then ask Claude to "install the usage statusline" — the bundled skill writes the `statusLine` key into your settings. (Plugins cannot declare a status line themselves.)

## Use

```bash
/usage          # plan, every window, credits — explained
```

See [plugins/claude-usage/README.md](plugins/claude-usage/README.md) for the script API, caching behaviour and troubleshooting.

## Requirements

macOS or Linux, `jq`, `curl`, and a Claude Code login. [clauth](https://github.com/uwuclxdy/clauth) is optional — it only adds an account label.

## License

MIT
