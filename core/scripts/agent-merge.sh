#!/usr/bin/env bash
# agent-merge.sh <pr-number> [--docs]
#
# Code PR: merges only if intent (as merged on the main branch) says merge: auto, adlc/judge and
# adlc/final-check are success on the exact head commit, local tests pass on that commit, and the PR
# is mergeable. The merge is pinned to that commit (the host refuses it if the head moved) and uses
# MERGE_METHOD (default merge). Then, if intent says tag: rc, creates and pushes vX.Y.Z-rc.N on the
# merge commit.
#
# Safe to rerun: an already merged PR (whose head still carries both statuses) skips to tagging, and
# a merge commit that already carries an rc tag for the release prints that tag instead.
#
# --docs: for define/close PRs (intent, spec, plan, session logs). Allowed only if every changed file,
# including the old path of a rename, is under one of DOCS_PATHS. A PR that adds or changes an
# intent.md also needs an approving review from a repo admin (the owner): intent carries the merge and
# deploy policy, so the agent cannot approve it for itself.
source "$(dirname "$0")/lib.sh"
load_config

pr="${1:?usage: agent-merge.sh <pr-number> [--docs]}"
mode="${2:-code}"
prinfo=$(host_pr_info "$pr") || die "cannot read PR $pr"
read -r state sha branch cross <<<"$prinfo"
merge_sha=""

# merge_pr <sha>: pinned merge through the host (no local checkout, works from any worktree).
merge_pr() {
  [ "$(host_pr_head "$pr")" = "$1" ] || die "PR $pr head moved after the checks; rerun"
  merge_sha=$(host_pr_merge_pinned "$pr" "$1" "$MERGE_METHOD") \
    || die "the host refused the merge of PR $pr at ${1:0:7} (head moved, checks missing, or conflicts)"
  is_protected_branch "$branch" && return
  [ "$cross" = "true" ] && return
  host_branch_delete "$branch" >/dev/null 2>&1 || info "branch $branch not deleted (already gone or protected)"
}

if [ "$mode" = "--docs" ]; then
  [ "$state" = "MERGED" ] && { info "docs PR $pr already merged"; exit 0; }
  [ "$state" = "OPEN" ] || die "PR $pr is $state"
  # host_pr_files fails when the host truncates the list: a short list could hide non-doc files.
  filesjson=$(host_pr_files "$pr") || die "cannot list all files of PR $pr"
  files=$(printf '%s\n' "$filesjson" | cut -f1,2 | tr '\t' '\n' | grep -v '^$' || true)
  [ -n "$files" ] || die "PR $pr lists no files"
  # Only the archive move of the same change (<changes>/<id>/ → <changes>/<archive prefix><id>/,
  # content unchanged) leaves intent untouched; any other add, edit or rename needs approval.
  intent_changed=$(printf '%s\n' "$filesjson" | python3 -c '
import re, sys
changes, archive = re.escape(sys.argv[1]), sys.argv[2]
for line in sys.stdin:
    f = line.rstrip("\n").split("\t")
    if len(f) < 4 or not any(re.search(r"(^|/)intent\.md$", p) for p in f[:2]):
        continue
    new = re.fullmatch(changes + "/(?:" + archive + ")([^/]+)/intent\\.md", f[0]) if archive else None
    old = re.fullmatch(changes + "/([^/]+)/intent\\.md", f[1])
    if f[2] == "renamed" and f[3] == "0" and new and old and new.group(1) == old.group(1):
        continue
    print(f[0])' "$SPEC_CHANGES_DIR" "$SPEC_ARCHIVE_RE")
  docs_re="^($(printf '%s' "$DOCS_PATHS" | tr -s ' ' '|'))/"
  bad=$(printf '%s\n' "$files" | grep -Ev "$docs_re" || true)
  [ -z "$bad" ] || die "docs merge refused; files outside $DOCS_PATHS changed:"$'\n'"$bad"
  if [ -n "$intent_changed" ]; then
    approvers=$(host_pr_approvers_at "$pr" "$sha") || die "cannot read reviews"
    ok=""
    for u in $approvers; do host_user_is_admin "$u" && ok=$u && break; done
    [ -n "$ok" ] || die "PR $pr changes intent.md: needs an approving review from a repo admin on ${sha:0:7}"
    info "intent approved by $ok"
  fi
  merge_pr "$sha"
  info "docs PR $pr merged as ${merge_sha:0:7}"
  exit 0
fi

change=$(pr_change "$pr")
# The PR body names the change whose intent sets the policy; bind it to the branch so a PR can't
# borrow another change's merge: auto.
[ "$branch" = "feat/$change" ] || die "PR $pr branch '$branch' is not feat/$change (from its adlc-change line)"
# A fork's branch can share a name with a change; its author is not bound by this repo's rules.
[ "$cross" = "false" ] || die "PR $pr comes from a fork: the owner merges this one"
intent=$(intent_path "$change")
[ "$(intent_field "$intent" merge)" = "auto" ] || die "intent says merge: $(intent_field "$intent" merge) — the owner merges this one"
require_status "$sha" adlc/judge
require_status "$sha" adlc/final-check

if [ "$state" = "MERGED" ]; then
  info "PR $pr already merged; continuing with tagging"
  merge_sha=$(host_pr_merge_commit "$pr")
else
  [ "$state" = "OPEN" ] || die "PR $pr is $state"
  host_pr_mergeable "$pr" || die "PR $pr is not mergeable"
  require_clean_head "$sha"
  [ -n "$TEST_CMD" ] || die "TEST_CMD is empty in .adlc/config.env: no merge without tests"
  info "running tests: $TEST_CMD"
  # PR code runs here: it gets no agent token.
  run_untrusted "$TEST_CMD" || die "tests failed on ${sha:0:7}"
  agent_identity fresh      # re-mint: the tests may outlast a short-lived token
  intent=$(intent_path "$change")   # read again from the main branch: PR code just ran and could have rewritten the copy
  [ "$(intent_field "$intent" merge)" = "auto" ] || die "intent no longer says merge: auto"
  merge_pr "$sha"
fi
[ -n "$merge_sha" ] || die "PR $pr has no merge commit"
info "merged PR $pr as ${merge_sha:0:7}"

if [ "$(intent_field "$intent" tag)" = "rc" ]; then
  ver=$(intent_field "$intent" release)
  [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "intent 'release:' must be X.Y.Z to tag (got '$ver')"
  git fetch --tags --quiet origin
  git fetch --quiet origin "$MAIN_BRANCH:refs/remotes/origin/$MAIN_BRANCH"
  existing=$(git tag --points-at "$merge_sha" --list "v$ver-rc.*" | head -1)
  if [ -n "$existing" ]; then
    git ls-remote --exit-code --tags origin "refs/tags/$existing" >/dev/null \
      || "$SCRIPT_DIR/agent-push.sh" --quiet "refs/tags/$existing"
    info "already tagged $existing"; echo "$existing"; exit 0
  fi
  n=$(git tag --list "v$ver-rc.*" | sed "s/^v$ver-rc\.//" | sort -n | tail -1)
  tag="v$ver-rc.$(( ${n:-0} + 1 ))"
  git tag -a "$tag" "$merge_sha" -m "$tag (PR $pr, change $change)"
  "$SCRIPT_DIR/agent-push.sh" --quiet "refs/tags/$tag"
  info "tagged $tag"
  echo "$tag"
fi
