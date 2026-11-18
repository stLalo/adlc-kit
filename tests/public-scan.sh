#!/usr/bin/env bash
# public-scan.sh: checks that nothing private or machine-specific is in the tracked files.
# Run by CI on every pull request. Exit 0 = clean.
#   - no symlinks (the kit must work as a plain copy)
#   - no home-directory paths, no secret-looking strings
#   - core/ names no host CLI, no agent CLI and no model (those belong in adapters/)
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
fail=0
report() { echo "FAIL $1"; shift; printf '     %s\n' "$@"; fail=1; }
files() { git ls-files -z -- . ':!tests/public-scan.sh'; }

links=$(git ls-files -s | awk '$1 == "120000" {print $4}')
[ -z "$links" ] || report "symlinks are not allowed" $links

hits=$(files | xargs -0 grep -nIE '(/home/[a-z][a-z0-9_-]+/|/Users/[A-Za-z][A-Za-z0-9_-]+/|C:\\Users\\)' 2>/dev/null || true)
[ -z "$hits" ] || report "home-directory paths" "$hits"

hits=$(files | xargs -0 grep -nIE '(gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|sk-[A-Za-z0-9_-]{24,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|op://[A-Za-z])' 2>/dev/null || true)
[ -z "$hits" ] || report "secret-looking strings" "$hits"

hits=$(git ls-files -z -- core | xargs -0 grep -nIwE '(gh|glab|codex|claude|copilot|cursor|opus|sonnet|haiku|gpt|gemini|openspec|github|gitlab|bitbucket)' 2>/dev/null \
       | grep -vE 'core/templates/(repo/config\.env|kit/kit\.env)' || true)
[ -z "$hits" ] || report "core/ must stay vendor-neutral (move this to an adapter)" "$hits"

[ "$fail" = 0 ] && echo "public scan: clean"
exit "$fail"
