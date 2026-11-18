#!/usr/bin/env bash
# session-save.sh <session-id>                    save docs/sessions/<id>/ (+ INDEX.md) to branch session/<id>
# session-save.sh --restore [--force] <session-id> copy docs/sessions/<id>/ from origin/session/<id> into the
#                                                  worktree (INDEX.md is not restored; refuses to overwrite
#                                                  local differences unless --force)
# session-save.sh --drop <session-id>              delete branch session/<id> on origin (after the close PR merged)
#
# Once a PR is open, checkpoints must not be committed to the PR branch: a new commit moves the head,
# drops the sha-bound judge/final-check statuses and reruns CI. This script commits the session logs
# from the working tree to a side branch instead, without touching the current branch, index or HEAD.
# The close PR (/session-close, /ship stage 8) lands the logs on main.
source "$(dirname "$0")/lib.sh"

mode=save force=0
case "${1:-}" in --restore|--drop) mode="${1#--}"; shift ;; esac
[ "${1:-}" = "--force" ] && { force=1; shift; }
id="${1:?usage: session-save.sh [--restore [--force]|--drop] <session-id>}"
[[ "$id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ && "$id" != *..* ]] || die "invalid session id '$id'"
dir="docs/sessions/$id"
ref="session/$id"

# remote_tip → sha of origin's session/<id>, or empty if it doesn't exist (fetch into FETCH_HEAD only).
# Exit 2 = the fetch failed for another reason (network, auth): never treated as "branch absent".
remote_tip() {
  if git ls-remote --exit-code origin "refs/heads/$ref" >/dev/null 2>&1; then
    git fetch --quiet origin "refs/heads/$ref" && git rev-parse FETCH_HEAD
  else
    local rc=$?; [ "$rc" = 2 ] && return 0; die "cannot reach origin (git ls-remote exit $rc)"
  fi
}

case "$mode" in
restore)
  tip=$(remote_tip) || exit 1; [ -n "$tip" ] || die "no origin/$ref to restore from"
  if [ -n "$(git ls-tree -r "$tip" -- "$dir" | awk '$1 != "100644"')" ]; then
    die "origin/$ref holds non-regular files under $dir; refusing to restore"
  fi
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  git archive "$tip" -- "$dir" | tar -xf - -C "$tmp"
  # Overwriting is safe when every local file is unchanged from HEAD or equals a version already saved
  # on the side branch (an older checkpoint). Anything else is unsaved work: refuse unless --force.
  if [ -d "$dir" ] && [ "$force" = 0 ]; then
    unsaved=""
    while IFS= read -r -d '' f; do
      cmp -s "$f" "$tmp/$f" && continue
      blob=$(git hash-object -- "$f")
      [ "$(git rev-parse -q --verify "HEAD:$f" 2>/dev/null)" = "$blob" ] && continue
      saved=$(git log --format=%H "$tip" -- "$f" | while read -r c; do git rev-parse -q --verify "$c:$f" || true; done)
      grep -qxF "$blob" <<<"$saved" && continue
      unsaved+="$f"$'\n'
    done < <(find "$dir" -type f -print0)
    [ -z "$unsaved" ] || die "unsaved local changes would be overwritten (rerun with --force):"$'\n'"$unsaved"
  fi
  mkdir -p "$dir" && cp -R "$tmp/$dir/." "$dir/"
  info "restored $dir from origin/$ref (working tree only; INDEX.md untouched)"
  exit 0 ;;
drop)
  if host_branch_delete "$ref" >/dev/null 2>&1; then info "deleted origin/$ref"
  else
    tip=$(remote_tip) || exit 1          # remote_tip already printed why
    [ -z "$tip" ] || die "could not delete origin/$ref"
    info "origin/$ref already gone"
  fi
  git branch -D "$ref" >/dev/null 2>&1 || true
  exit 0 ;;
esac

[ -d "$dir" ] || die "$dir not found"
ignored=$(git ls-files --others --ignored --exclude-standard -- "$dir")
[ -z "$ignored" ] || die "ignored files under $dir; move them out (session logs never carry them):"$'\n'"$ignored"
odd=$(find "$dir" \( ! -type f ! -type d \) -o \( -type f \( -perm -u+x -o -perm -g+x -o -perm -o+x \) \))
[ -z "$odd" ] || die "only plain files belong in $dir (no symlinks or executables):"$'\n'"$odd"
nonmd=$(git ls-files --others --cached --exclude-standard -- "$dir" | grep -v '\.md$' || true)
[ -z "$nonmd" ] || die "only markdown belongs in $dir:"$'\n'"$nonmd"
paths=("$dir"); [ -f docs/sessions/INDEX.md ] && paths+=(docs/sessions/INDEX.md)

remote=$(remote_tip) || exit 1
parent=$remote
[ -z "$parent" ] && git show-ref --verify --quiet "refs/heads/$ref" && parent=$(git rev-parse "refs/heads/$ref")

idx=$(mktemp); trap 'rm -f "$idx"' EXIT; rm -f "$idx"
tree=$(GIT_INDEX_FILE="$idx" bash -c 'git add -- "$@" && git write-tree' _ "${paths[@]}")

if [ -n "$parent" ] && [ "$(git rev-parse "$parent^{tree}")" = "$tree" ]; then
  commit=$parent
else
  commit=$(git commit-tree "$tree" ${parent:+-p "$parent"} -m "chore(session): $id save $(date -u +%Y-%m-%dT%H:%MZ)")
fi
git update-ref "refs/heads/$ref" "$commit"
if [ "$commit" = "$remote" ]; then info "nothing new to save for $id"; exit 0; fi
"$SCRIPT_DIR/agent-push.sh" --quiet "refs/heads/$ref:refs/heads/$ref"
info "saved $dir to $ref (${commit:0:7})"
