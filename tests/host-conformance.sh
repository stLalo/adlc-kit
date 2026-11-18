#!/usr/bin/env bash
# host-conformance.sh <adapter>
# Checks that a host adapter does what adapters/host/CONTRACT.md says, by driving one real pull request
# from creation to a pinned merge. Run it against a THROWAWAY repo on your host:
#
#   git clone <url of a scratch repo you can push to and merge in> /tmp/adlc-conf
#   CONFORMANCE_REPO=/tmp/adlc-conf bash tests/host-conformance.sh <adapter>
#
# It pushes one branch, opens and merges one pull request into CONFORMANCE_BASE (default: main), posts
# one commit status, one comment, one label and one issue. Branch protection on the scratch repo must
# allow that. With ADLC_HOST_TOKEN set it also checks host_push. Exit 0 = every check passed.
# The kit's own suite (tests/run.sh) runs this offline against a fake host CLI.
set -uo pipefail
KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
adapter="${1:?usage: host-conformance.sh <adapter>}"
repo="${CONFORMANCE_REPO:?set CONFORMANCE_REPO to a clone of a throwaway repo on your host}"
base="${CONFORMANCE_BASE:-main}"
cd "$repo" || exit 1
mkdir -p .adlc
[ -f .adlc/config.env ] || { printf 'MAIN_BRANCH="%s"\nHOST_ADAPTER="%s"\n' "$base" "$adapter" > .adlc/config.env
                             echo ".adlc/" >> "$(git rev-parse --git-dir)/info/exclude"; }
grep -q "^HOST_ADAPTER=\"$adapter\"" .adlc/config.env || { echo "this repo's .adlc/config.env names another host adapter"; exit 1; }
# shellcheck disable=SC1091
source "$KIT/core/scripts/lib.sh"
set +e

pass=0 fail=0
ok()  { pass=$((pass+1)); echo "ok   $*"; }
bad() { fail=$((fail+1)); echo "FAIL $*"; }
is()  { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected '$3', got '$2')"; fi; }     # is <name> <got> <want>
has() { if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1 (no '$3' in output)"; fi; }
run() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi; }
no()  { local name="$1"; shift; if "$@" >/dev/null 2>&1; then bad "$name (should have failed)"; else ok "$name"; fi; }

id="adlc-conf-$(date +%s)-$$"; work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
run "host_check" host_check
rid=$(host_repo_id 2>/dev/null); [ -n "$rid" ] && ok "host_repo_id → $rid" || bad "host_repo_id is empty"

git fetch --quiet origin "$base" && git switch --quiet -c "$id" "origin/$base" || { echo "cannot branch from origin/$base"; exit 1; }
mkdir -p conformance && echo "$id" > "conformance/$id.md" && git add "conformance/$id.md" \
  && git -c user.name="${GIT_AUTHOR_NAME:-adlc-conformance}" -c user.email="${GIT_AUTHOR_EMAIL:-adlc@example.invalid}" commit --quiet -m "test: $id"
sha=$(git rev-parse HEAD)
git push --quiet origin "$id" || { echo "cannot push $id"; exit 1; }
if [ -n "${ADLC_HOST_TOKEN:-}" ]; then run "host_push with the agent token" host_push --quiet "$id:refs/heads/$id-token"; host_branch_delete "$id-token" >/dev/null 2>&1; fi

printf 'Conformance run %s\n\nadlc-change: conformance\n' "$id" > "$work/body.md"
pr=$(host_pr_create --base "$base" --head "$id" --title "ADLC conformance $id" --body-file "$work/body.md" 2>/dev/null)
[[ "$pr" =~ ^[0-9]+$ ]] && ok "host_pr_create → $pr" || { bad "host_pr_create must print the PR number (got '$pr')"; echo "---- $pass passed, $fail failed"; exit 1; }
is  "host_pr_for_branch" "$(host_pr_for_branch "$id")" "$pr OPEN"
is  "host_pr_info" "$(host_pr_info "$pr")" "OPEN $sha $id false"
is  "host_pr_head" "$(host_pr_head "$pr")" "$sha"
has "host_pr_body" "$(host_pr_body "$pr")" "adlc-change: conformance"
echo "edited $id" >> "$work/body.md"; run "host_pr_edit_body" host_pr_edit_body "$pr" "$work/body.md"
has "host_pr_body after edit" "$(host_pr_body "$pr")" "edited $id"
is  "host_pr_files" "$(host_pr_files "$pr" | cut -f1,3)" "conformance/$id.md"$'\t'"added"
has "host_pr_diff" "$(host_pr_diff "$pr")" "conformance/$id.md"
echo "<!-- adlc-conformance $id -->" > "$work/c.md"; run "host_pr_comment" host_pr_comment "$pr" "$work/c.md"
has "host_pr_comments" "$(host_pr_comments "$pr")" "<!-- adlc-conformance $id -->"
run "host_label_ensure" host_label_ensure needs-human "ADLC pipeline needs the owner"
run "host_label_ensure again (already there)" host_label_ensure needs-human "ADLC pipeline needs the owner"
run "host_pr_label_add" host_pr_label_add "$pr" needs-human
has "host_pr_labels" "$(host_pr_labels "$pr")" "needs-human"
run "host_pr_checks" host_pr_checks "$pr"
is  "host_status_get before any status" "$(host_status_get "$sha" adlc/conformance)" ""
run "host_status_post pending" host_status_post "$sha" adlc/conformance pending "running"
is  "host_status_get pending" "$(host_status_get "$sha" adlc/conformance)" "pending"
run "host_status_post success" host_status_post "$sha" adlc/conformance success "done $id"
is  "host_status_get latest wins" "$(host_status_get "$sha" adlc/conformance)" "success"
has "host_statuses" "$(host_statuses "$sha")" "adlc/conformance"$'\t'"success"
run "host_pr_approvers_at (may be empty)" host_pr_approvers_at "$pr" "$sha"
no  "host_user_is_admin rejects an unknown user" host_user_is_admin "adlc-no-such-user-$$"
m=1; for _ in 1 2 3 4 5 6 7 8 9 10; do host_pr_mergeable "$pr" 2>/dev/null && m=0 && break; sleep "${CONFORMANCE_WAIT:-3}"; done
is  "host_pr_mergeable" "$m" "0"
no  "host_pr_merge_pinned refuses a wrong sha" host_pr_merge_pinned "$pr" 0000000000000000000000000000000000000000 merge
is  "PR still open after the refused merge" "$(host_pr_info "$pr" | cut -d' ' -f1)" "OPEN"
msha=$(host_pr_merge_pinned "$pr" "$sha" merge 2>/dev/null)
[[ "$msha" =~ ^[0-9a-f]{40}$ ]] && ok "host_pr_merge_pinned → ${msha:0:7}" || bad "host_pr_merge_pinned must print the merge commit sha (got '$msha')"
is  "host_pr_info after merge" "$(host_pr_info "$pr" | cut -d' ' -f1)" "MERGED"
is  "host_pr_merge_commit" "$(host_pr_merge_commit "$pr")" "$msha"
git fetch --quiet origin "$base"; run "the merge commit is on $base" git merge-base --is-ancestor "$msha" "origin/$base"
run "host_branch_delete" host_branch_delete "$id"
no  "the branch is gone on the host" git ls-remote --exit-code origin "refs/heads/$id"
echo "body $id" > "$work/i.md"
issue=$(host_issue_create --title "ADLC conformance $id" --body-file "$work/i.md" 2>/dev/null)
[[ "$issue" =~ ^[0-9]+$ ]] && ok "host_issue_create → $issue" || bad "host_issue_create must print the issue number (got '$issue')"
is  "host_issue_state" "$(host_issue_state "$issue")" "OPEN"
has "host_issue_body" "$(host_issue_body "$issue")" "body $id"
git switch --quiet --detach "origin/$base" 2>/dev/null; git branch -D "$id" >/dev/null 2>&1

echo "---- host adapter '$adapter': $pass passed, $fail failed"
[ "$fail" = 0 ]
