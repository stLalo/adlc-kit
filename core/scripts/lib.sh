#!/usr/bin/env bash
# Shared helpers for core/scripts/*. Source it; don't run it.
# The kit can live anywhere. Scripts act on the repo you run them from:
#   (cd <repo> && "$ADLC_KIT/core/scripts/<script>.sh" ...)
set -euo pipefail

die()  { printf '✗ %s\n' "$*" >&2; exit 1; }
info() { echo "→ $*" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export ADLC_KIT="$KIT"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || die "not inside a git repo: run as (cd <repo> && \$ADLC_KIT/core/scripts/$(basename "$0") ...)"
[ "$REPO_ROOT" != "$KIT" ] || die "you are in the kit itself; cd into the target repo first"
cd "$REPO_ROOT"

valid_name() { [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "invalid adapter name '$1'"; }
# data_value <file> <KEY> → value of a KEY="value" line, read as data (the file is never executed)
data_value() { sed -n "s/^$2=\"\([^\"]*\)\".*/\1/p" "$1" 2>/dev/null | head -1; }

# Machine-local settings come only from the kit's own kit.env, never from the caller's environment:
# a command line cannot pick a weaker identity or a different list of protected branches.
unset IDENTITY_ADAPTER SECRETS_ADAPTER SECRET_CMD ADLC_PROTECTED_BRANCHES NOTIFY_CMD
# shellcheck disable=SC1091
[ -f "$KIT/.adlc/kit.env" ] && source "$KIT/.adlc/kit.env"
: "${IDENTITY_ADAPTER:=own-login}" "${ADLC_PROTECTED_BRANCHES:=main master develop}"
export SECRETS_ADAPTER="${SECRETS_ADAPTER:-env}" SECRET_CMD="${SECRET_CMD:-}"
valid_name "$IDENTITY_ADAPTER"

# The host adapter name is read as data from the working tree. Adapters are loaded only from the kit,
# so a branch can at most name another shipped adapter; load_config then checks it against main.
# shellcheck disable=SC1091
source "$KIT/adapters/defaults.env"
HOST_ADAPTER="$(data_value .adlc/config.env HOST_ADAPTER)"; : "${HOST_ADAPTER:=$DEFAULT_HOST_ADAPTER}"
valid_name "$HOST_ADAPTER"
[ -f "$KIT/adapters/host/$HOST_ADAPTER.sh" ] || die "no host adapter '$HOST_ADAPTER' in $KIT/adapters/host/"
# shellcheck disable=SC1090
source "$KIT/adapters/host/$HOST_ADAPTER.sh"

# Act as the agent's own identity (a bot) when kit.env names an identity adapter that provides one.
# Identity adapters print a token (exit 0), say "not configured, use the user's login" (exit 1), or
# fail (anything else: the script stops instead of silently acting as the user).
# Tokens can be short-lived: call `agent_identity fresh` before writes that follow long steps.
agent_identity() {
  local tok rc=0
  [ "${1:-}" = fresh ] && unset ADLC_HOST_TOKEN
  if [ -n "${ADLC_HOST_TOKEN:-}" ]; then host_use_token "$ADLC_HOST_TOKEN"; return; fi
  tok=$("$KIT/adapters/identity/$IDENTITY_ADAPTER.sh") || rc=$?
  if [ "$rc" -eq 0 ]; then export ADLC_HOST_TOKEN="$tok"; host_use_token "$tok"
  elif [ "$rc" -ne 1 ]; then die "agent identity '$IDENTITY_ADAPTER' failed; not acting as you"; fi
}
agent_identity

# run_untrusted <shell command> [arg0 args...]: runs repo-controlled commands (tests, deploys) without the agent token.
# The kit runs git with the token afterwards (tag, push), so the command must not have changed where
# git sends it or what git runs: the repo's git config and hooks are compared before and after.
run_untrusted() {
  local v rc=0 before unset_args=(-u ADLC_HOST_TOKEN)
  for v in ${HOST_TOKEN_VARS:-}; do unset_args+=(-u "$v"); done
  before=$(_git_wiring)
  env "${unset_args[@]}" bash -c "$1" "${@:2}" || rc=$?
  [ "$(_git_wiring)" = "$before" ] \
    || die "the command changed this repo's git config or hooks (.git/config, .git/hooks); refusing to continue. Inspect them before running the kit here again."
  return "$rc"
}
# _git_wiring → one hash over the repo's local git config and every file in its hooks folder.
_git_wiring() {
  python3 - "$(git rev-parse --git-common-dir)" <<'PY'
import hashlib, os, sys
g, h = sys.argv[1], hashlib.sha256()
paths = [os.path.join(g, "config"), os.path.join(g, "config.worktree")]
for root, _, names in os.walk(os.path.join(g, "hooks")):
    paths += [os.path.join(root, n) for n in names]
for p in sorted(paths):
    h.update(p.encode())
    try:
        h.update(open(p, "rb").read())
    except OSError:
        h.update(b"<missing>")
print(h.hexdigest())
PY
}

is_protected_branch() { local b; for b in $ADLC_PROTECTED_BRANCHES; do [ "$b" = "$1" ] && return 0; done; return 1; }

load_config() {
  [ -f .adlc/config.env ] || die "$REPO_ROOT/.adlc/config.env missing (run install-repo.sh)"
  # Never execute the branch's copy: a PR could change its own merge policy, tests or deploy commands,
  # or run code while the agent token is in the environment. Read MAIN_BRANCH as data, then source the
  # copy merged on that branch (config changes are the owner's PRs). Only branches the machine-local
  # kit.env lists as protected count, so a branch cannot name itself as the main branch.
  MAIN_BRANCH="$(data_value .adlc/config.env MAIN_BRANCH)"; : "${MAIN_BRANCH:=main}"
  is_protected_branch "$MAIN_BRANCH" || die "MAIN_BRANCH '$MAIN_BRANCH' is not in ADLC_PROTECTED_BRANCHES ($ADLC_PROTECTED_BRANCHES)"
  git fetch --quiet origin "$MAIN_BRANCH:refs/remotes/origin/$MAIN_BRANCH" || die "cannot fetch origin/$MAIN_BRANCH"
  # Only this branch's own edits count (merge-base → worktree); a branch that predates a config PR is
  # fine, because the copy sourced below is the one on origin/$MAIN_BRANCH anyway.
  local base; base=$(git merge-base HEAD "origin/$MAIN_BRANCH") || die "no merge-base with origin/$MAIN_BRANCH"
  git diff --quiet "$base" -- .adlc/config.env \
    || die ".adlc/config.env is changed on this branch; config changes are the owner's PRs"
  local cfg want_host="$HOST_ADAPTER" want_main="$MAIN_BRANCH"
  cfg="$(git rev-parse --git-dir)/adlc-config.env"
  git show "origin/$MAIN_BRANCH:.adlc/config.env" > "$cfg" || die "cannot read origin/$MAIN_BRANCH:.adlc/config.env"
  # shellcheck disable=SC1090
  source "$cfg"
  [ "${MAIN_BRANCH:-main}" = "$want_main" ] || die "MAIN_BRANCH differs between this branch and origin/$want_main"
  [ "${HOST_ADAPTER:-$DEFAULT_HOST_ADAPTER}" = "$want_host" ] || die "HOST_ADAPTER differs between this branch and origin/$MAIN_BRANCH"
  : "${MAX_JUDGE_ROUNDS:=3}" "${MERGE_METHOD:=merge}" "${JUDGE_ADAPTER:=$DEFAULT_JUDGE_ADAPTER}" "${SPEC_ADAPTER:=$DEFAULT_SPEC_ADAPTER}"
  : "${JUDGE_MODEL:=}" "${JUDGE_FALLBACK_MODEL:=}" "${TEST_CMD:=}"
  case "$MERGE_METHOD" in merge|squash) ;; *) die "MERGE_METHOD must be merge or squash (got '$MERGE_METHOD')" ;; esac
  valid_name "$JUDGE_ADAPTER"; valid_name "$SPEC_ADAPTER"
  [ -f "$KIT/adapters/spec/$SPEC_ADAPTER.env" ] || die "no spec adapter '$SPEC_ADAPTER' in $KIT/adapters/spec/"
  # shellcheck disable=SC1090
  source "$KIT/adapters/spec/$SPEC_ADAPTER.env"
  : "${SPEC_CHANGES_DIR:?spec adapter must set SPEC_CHANGES_DIR}" "${DOCS_PATHS:?spec adapter must set DOCS_PATHS}"
  : "${SPEC_ARCHIVE_RE:=}" "${SPEC_SPECS_DIR:=}"
}

pr_sha() { host_pr_head "$1"; }

# The PR body must contain a line:  adlc-change: <change-id>
pr_change() {
  local id
  id=$(host_pr_body "$1" | sed -n 's/^adlc-change:[[:space:]]*\([A-Za-z0-9._-]*\).*/\1/p' | head -1)
  [ -n "$id" ] || die "PR $1 body has no 'adlc-change: <id>' line"
  echo "$id"
}

# intent_path <change-id> → a temp copy of intent.md as merged on origin/$MAIN_BRANCH (the approved
# policy). The PR's own copy is never trusted: a branch cannot grant itself merge: auto or deploy: prod.
intent_path() {
  local id="$1" ref="origin/$MAIN_BRANCH" p out
  p=$(git ls-tree -r --name-only "$ref" -- "$SPEC_CHANGES_DIR" \
        | grep -E "^$SPEC_CHANGES_DIR/($SPEC_ARCHIVE_RE)?$id/intent\.md$" | tail -1 || true)
  [ -n "$p" ] || die "intent.md for change '$id' is not on $ref (the define PR merges it first)"
  out="$(git rev-parse --git-dir)/adlc-intent-$id.md"     # inside .git: untracked, overwritten per call
  git show "$ref:$p" > "$out" || die "cannot read $ref:$p"
  echo "$out"
}

# intent_field <intent.md> <key>  → value from YAML front matter (empty if missing)
intent_field() {
  python3 - "$1" "$2" <<'PY'
import sys, re
text = open(sys.argv[1], encoding="utf-8").read()
m = re.match(r"^---\n(.*?)\n---", text, re.S)
if m:
    for line in m.group(1).splitlines():
        k, _, v = line.partition(":")
        if k.strip() == sys.argv[2]:
            print(v.split("#")[0].strip()); break
PY
}

# post_status <sha> <context> <success|failure|pending> <description>
post_status() {
  host_status_post "$1" "$2" "$3" "${4:0:139}"
  info "status $2 = $3 on ${1:0:7}"
}

# status_of <sha> <context>  → success|failure|pending|missing (latest status for that context)
status_of() { local s; s=$(host_status_get "$1" "$2"); echo "${s:-missing}"; }

require_status() {
  local st; st=$(status_of "$1" "$2")
  [ "$st" = "success" ] || die "$2 is '$st' on ${1:0:7} (needs success)"
}

# Session logs (docs/sessions/**/*.md) may be dirty: once a PR is open they are saved with
# session-save.sh, never committed to the PR branch, so checkpoints do not move the judged head.
# Anything else, including non-markdown files under docs/sessions/, must be clean.
require_clean_head() {
  [ -z "$(git status --porcelain --untracked-files=all -- . ':(exclude,glob)docs/sessions/**/*.md')" ] \
    || die "working tree not clean (only docs/sessions/**/*.md may differ)"
  [ "$(git rev-parse HEAD)" = "$1" ] || die "local HEAD $(git rev-parse --short HEAD) != PR head ${1:0:7}; checkout and pull first"
}

# notify <message>: tells the owner. Set NOTIFY_CMD in kit.env to a command that takes the message as
# its only argument; without it the message is only logged and the agent relays it.
notify() {
  info "NOTIFY: $*"
  [ -z "${NOTIFY_CMD:-}" ] || run_untrusted "$NOTIFY_CMD \"\$1\"" _ "$*" >/dev/null 2>&1 || true
}
