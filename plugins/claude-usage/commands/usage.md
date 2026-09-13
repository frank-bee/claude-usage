---
description: Show what this Claude subscription meters - plan type, rate-limit windows, credit spend
---

Run the plugin's usage script and report the result to the user:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/usage.sh" detect
```

Then present it plainly:

- **subscription** — `enterprise`, `team`, `pro`, `max`. This decides what the rest means.
- **rate limits** — the 5h / weekly windows this plan enforces. An account can legitimately report none: a window only appears once there is usage inside it, and an enterprise usage-based seat often has none at all.
- **credits** — the extra-usage pool, in dollars. Enabled on enterprise usage-based seats, normally disabled on Pro/Max.

Do not present a missing window as an error, and do not fall back to estimating spend from token counts — the numbers come from Anthropic's own accounting (`/api/oauth/usage`), and anything derived locally would be a guess.

If the user passed `$ARGUMENTS`, treat it as a sub-command of the script (`line`, `json`, `fetch`) and run that instead.
