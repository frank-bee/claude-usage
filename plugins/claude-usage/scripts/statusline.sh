#!/usr/bin/env bash
# statusline.sh - branch | account | model | context | usage
#
# Reads Claude Code's statusline JSON on stdin and appends whatever the account's
# subscription actually meters, via usage.sh.

input=$(cat)

if command -v jq >/dev/null 2>&1; then
  model=$(echo "$input" | jq -r '.model.display_name // ""')
  used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
  cwd=$(echo "$input" | jq -r '.cwd // ""')
else
  model=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('model',{}).get('display_name',''))" 2>/dev/null)
  used_pct=$(echo "$input" | python3 -c "import sys,json; v=json.load(sys.stdin).get('context_window',{}).get('used_percentage'); print(v if v is not None else '')" 2>/dev/null)
  cwd=$(echo "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null)
fi

branch=""
if [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
  [ ${#branch} -gt 20 ] && branch="${branch:0:20}..."
fi

short_model=$(echo "$model" | sed 's/^Claude //')

# Context window as a 10-char bar
ctx_part="ctx n/a"
if [ -n "$used_pct" ]; then
  pct_int=${used_pct%.*}
  filled=$(( pct_int * 10 / 100 )); [ $filled -gt 10 ] && filled=10
  bar=""
  for _ in $(seq 1 $filled);            do bar="${bar}▓"; done
  for _ in $(seq 1 $(( 10 - filled ))); do bar="${bar}░"; done
  ctx_part="${bar} ${pct_int}% ctx"
fi

# Account label, only when clauth manages the credentials - it names which of
# several accounts this pane burns. Absent without clauth, which is fine.
profile=$(clauth which 2>/dev/null)

usage_part=$(bash "${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}/scripts/usage.sh" line 2>/dev/null)

parts=()
[ -n "$branch" ]      && parts+=("⎇ ${branch}")
[ -n "$profile" ]     && parts+=("@${profile}")
[ -n "$short_model" ] && parts+=("${short_model}")
parts+=("${ctx_part}")
[ -n "$usage_part" ]  && parts+=("${usage_part}")

result=""
for part in "${parts[@]}"; do
  [ -z "$result" ] && result="$part" || result="${result} | ${part}"
done
echo "$result"
