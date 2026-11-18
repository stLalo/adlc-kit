#!/usr/bin/env bash
# install-repo.sh <repo-path> [--harness <a,b,...>] [--spec <name>] [--host <name>] [--judge <name>]
# Enables the kit in one repo. Run by the owner (it writes files the guard protects).
#   --harness  adapters in adapters/harness/ to install, comma separated (default: git-hooks)
#   --spec     spec adapter for a new config   (names: adapters/spec/*.env)
#   --host     host adapter for a new config   (names: adapters/host/*.sh)
#   --judge    judge adapter for a new config  (names: adapters/judge/*.sh, or "human")
# Defaults for the last three come from adapters/defaults.env.
# Creates .adlc/config.env, docs/sessions/INDEX.md, the kit block in AGENTS.md, the needs-human label,
# and machine-local pointers (.adlc/kit-path in the repo, the repo in the kit's .adlc/repos).
# Never overwrites existing config; safe to re-run.
set -euo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO="$(cd "${1:?usage: install-repo.sh <repo-path> [--harness a,b] [--spec name] [--host name] [--judge name]}" && pwd)"; shift
# shellcheck disable=SC1091
source "$KIT/adapters/defaults.env"
harness="git-hooks" spec="$DEFAULT_SPEC_ADAPTER" host="$DEFAULT_HOST_ADAPTER" judge="$DEFAULT_JUDGE_ADAPTER"
while [ $# -gt 0 ]; do
  case "$1" in
    --harness) harness="$2"; shift 2 ;; --spec) spec="$2"; shift 2 ;;
    --host) host="$2"; shift 2 ;; --judge) judge="$2"; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
git -C "$REPO" rev-parse --show-toplevel >/dev/null 2>&1 || { echo "$REPO is not a git repo"; exit 1; }
[ "$REPO" != "$KIT" ] || { echo "that is the kit itself; give the path of the repo to enable"; exit 1; }
[ -f "$KIT/adapters/spec/$spec.env" ] || { echo "no spec adapter '$spec'"; exit 1; }
[ -f "$KIT/adapters/host/$host.sh" ] || { echo "no host adapter '$host' (write one from adapters/host/_template.sh)"; exit 1; }
name="$(basename "$REPO")"
echo "Enabling the ADLC kit in $name"

mkdir -p "$KIT/.adlc" "$REPO/.adlc"
[ -f "$KIT/.adlc/kit.env" ] || { cp "$KIT/core/templates/kit/kit.env" "$KIT/.adlc/kit.env"; echo "  created $KIT/.adlc/kit.env (machine-local settings)"; }
touch "$KIT/.adlc/repos"; grep -qxF "$REPO" "$KIT/.adlc/repos" || echo "$REPO" >> "$KIT/.adlc/repos"
printf '%s\n' "$KIT" > "$REPO/.adlc/kit-path"

if [ ! -f "$REPO/.adlc/config.env" ]; then
  sed -e "s/^HOST_ADAPTER=.*/HOST_ADAPTER=\"$host\"/" -e "s/^SPEC_ADAPTER=.*/SPEC_ADAPTER=\"$spec\"/" \
      -e "s/^JUDGE_ADAPTER=.*/JUDGE_ADAPTER=\"$judge\"/" "$KIT/core/templates/repo/config.env" > "$REPO/.adlc/config.env"
  echo "  created .adlc/config.env  ← edit TEST_CMD, the judge, roles and UAT/prod commands"
else
  echo "  .adlc/config.env exists (kept)"
fi

mkdir -p "$REPO/docs/sessions"
[ -f "$REPO/docs/sessions/INDEX.md" ] || { cp "$KIT/core/templates/sessions/INDEX.md" "$REPO/docs/sessions/INDEX.md"; echo "  created docs/sessions/INDEX.md"; }

touch "$REPO/.gitignore"
for line in ".adlc/reports/" ".adlc/kit-path"; do
  grep -qxF "$line" "$REPO/.gitignore" || { echo "$line" >> "$REPO/.gitignore"; echo "  .gitignore += $line"; }
done

# The kit block in AGENTS.md: replaced in place on re-run, everything else in the file is kept.
python3 - "$REPO/AGENTS.md" "$KIT/core/templates/repo/AGENTS.adlc.md" <<'PY'
import os, re, sys
path, block = sys.argv[1], open(sys.argv[2], encoding="utf-8").read().strip()
text = open(path, encoding="utf-8").read() if os.path.isfile(path) else ""
begin, end = "<!-- adlc-kit:begin -->", "<!-- adlc-kit:end -->"
new = f"{begin}\n{block}\n{end}"
if begin in text and end in text:
    text = re.sub(re.escape(begin) + r".*?" + re.escape(end), lambda _: new, text, flags=re.S)
else:
    text = (text.rstrip("\n") + "\n\n" if text.strip() else "") + new + "\n"
open(path, "w", encoding="utf-8").write(text)
print("  AGENTS.md: kit block written")
PY

specdir="$(sed -n 's/^SPEC_CHANGES_DIR="\([^"]*\)".*/\1/p' "$KIT/adapters/spec/$spec.env")"
[ -d "$REPO/$specdir" ] || echo "  ⚠ no $specdir/ folder yet: $(sed -n 's/^SPEC_INIT_HINT="\([^"]*\)".*/\1/p' "$KIT/adapters/spec/$spec.env")"

if (cd "$REPO" && bash -c 'source "$1/core/scripts/lib.sh" && host_check && host_label_ensure needs-human "ADLC pipeline needs the owner"' _ "$KIT") >/dev/null 2>&1; then
  echo "  label needs-human is present on the host"
else
  echo "  ⚠ could not reach the host ($host): create the label 'needs-human' later"
fi

IFS=',' read -r -a hs <<<"$harness"
for h in "${hs[@]}"; do
  [ -x "$KIT/adapters/harness/$h/install.sh" ] || { echo "  ⚠ no harness adapter '$h' (see adapters/harness/CONTRACT.md)"; continue; }
  echo "  harness: $h"; "$KIT/adapters/harness/$h/install.sh" "$REPO"
done
echo "  next: commit .adlc/config.env, docs/sessions/INDEX.md, AGENTS.md and .gitignore in $name through a PR"
echo "        then protect the main branch on the host (docs/server-gate.md)"
