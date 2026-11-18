# shellcheck shell=bash
# Host adapter: GitHub (github.com and GitHub Enterprise), through the `gh` CLI.
# Sourced by core/scripts/lib.sh. Implements adapters/host/CONTRACT.md. Status: tested by maintainers.

# Environment variables that carry a host credential; core strips them before running repo code.
# shellcheck disable=SC2034  # read by core/scripts/lib.sh, which sources this file
HOST_TOKEN_VARS="GH_TOKEN GITHUB_TOKEN GH_ENTERPRISE_TOKEN GITHUB_ENTERPRISE_TOKEN"

host_use_token() { export GH_TOKEN="$1"; }
host_check() {
  command -v gh >/dev/null || die "gh CLI not found (https://cli.github.com)"
  gh auth status >/dev/null 2>&1 || [ -n "${GH_TOKEN:-}" ] || die "gh is not logged in: run 'gh auth login'"
}

host_repo_id() { gh repo view --json nameWithOwner -q .nameWithOwner; }
_gh_slug() { [ -n "${_GH_SLUG:-}" ] || _GH_SLUG=$(host_repo_id) || die "cannot resolve the repo on GitHub"; echo "$_GH_SLUG"; }

# ---- pull requests: read
host_pr_info() {   # → "<OPEN|MERGED|CLOSED> <head-sha> <head-branch> <true|false: from a fork>"
  gh pr view "$1" --json state,headRefOid,headRefName,isCrossRepository \
    -q '"\(.state) \(.headRefOid) \(.headRefName) \(.isCrossRepository)"'
}
host_pr_head() { gh pr view "$1" --json headRefOid -q .headRefOid; }
host_pr_body() { gh pr view "$1" --json body -q .body; }
host_pr_diff() { gh pr diff "$1"; }
host_pr_labels() { gh pr view "$1" --json labels -q '.labels[].name'; }
host_pr_checks() { gh pr view "$1" --json statusCheckRollup -q '.statusCheckRollup[] | [(.name // .context), (.conclusion // .state // "")] | @tsv'; }
host_pr_comments() { gh pr view "$1" --json comments -q '.comments[].body'; }
# GitHub computes mergeability in the background: right after a push it answers UNKNOWN for a few seconds.
host_pr_mergeable() {
  local m i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    m=$(gh pr view "$1" --json mergeable -q .mergeable) || return 1
    [ "$m" = UNKNOWN ] || break
    sleep "${ADLC_HOST_WAIT:-3}"
  done
  [ "$m" = MERGEABLE ]
}
host_pr_merge_commit() { gh pr view "$1" --json mergeCommit -q .mergeCommit.oid; }
host_pr_for_branch() {
  gh pr list --head "$1" --state all --limit 1 --json number,state -q '.[] | "\(.number) \(.state)"'
}

# → "<path>\t<previous path or empty>\t<added|modified|removed|renamed>\t<changed lines>" per file.
# Fails if GitHub truncated the list (the files API stops at 3000 entries).
host_pr_files() {
  local out want
  out=$(gh api --paginate "repos/$(_gh_slug)/pulls/$1/files" \
        -q '.[] | [.filename, (.previous_filename // ""), .status, .changes] | @tsv') || return 1
  want=$(gh pr view "$1" --json changedFiles -q .changedFiles) || return 1
  [ "$(printf '%s\n' "$out" | grep -c .)" = "$want" ] || { echo "file list of PR $1 is truncated" >&2; return 1; }
  printf '%s\n' "$out"
}

# → logins whose latest decisive review is an approval of exactly <sha>.
# A later "changes requested" or a dismissal withdraws an approval.
host_pr_approvers_at() {
  gh api --paginate "repos/$(_gh_slug)/pulls/$1/reviews" \
    -q '.[] | select(.state=="APPROVED" or .state=="CHANGES_REQUESTED" or .state=="DISMISSED") | "\(.user.login) \(.state) \(.commit_id)"' \
    | awk -v sha="$2" '{last[$1]=$2" "$3} END {for (u in last) {split(last[u], a, " "); if (a[1]=="APPROVED" && a[2]==sha) print u}}'
}
host_user_is_admin() { [ "$(gh api "repos/$(_gh_slug)/collaborators/$1/permission" -q .permission 2>/dev/null)" = admin ]; }

# ---- pull requests and issues: write
host_pr_create() {     # --base <b> --head <h> --title <t> --body-file <f>  → PR number
  gh pr create "$@" | sed -n 's#.*/pull/\([0-9][0-9]*\).*#\1#p' | tail -1
}
# Edits and labels go through the REST API: `gh pr edit` fails on older gh versions (it queries
# classic projects, which GitHub removed).
host_pr_edit_body() { gh api -X PATCH "repos/$(_gh_slug)/pulls/$1" -F "body=@$2" >/dev/null; }
host_pr_comment() { gh pr comment "$1" --body-file "$2" >/dev/null; }
host_pr_label_add() { gh api -X POST "repos/$(_gh_slug)/issues/$1/labels" -f "labels[]=$2" >/dev/null; }
host_label_ensure() {      # <name> <description>: create the label unless it exists
  local slug; slug=$(_gh_slug)
  gh api "repos/$slug/labels/$1" >/dev/null 2>&1 \
    || gh api -X POST "repos/$slug/labels" -f name="$1" -f color=B60205 -f description="$2" >/dev/null
}
host_issue_create() {  # --title <t> --body-file <f>  → issue number
  gh issue create "$@" | sed -n 's#.*/issues/\([0-9][0-9]*\).*#\1#p' | tail -1
}
host_issue_state() { gh issue view "$1" --json state -q .state; }
host_issue_body() { gh issue view "$1" --json body -q .body; }

# ---- gated writes (core scripts only)
host_pr_merge_pinned() {   # <pr> <sha> <merge|squash> → merge commit sha; the host must refuse if the head moved
  gh api -X PUT "repos/$(_gh_slug)/pulls/$1/merge" -f sha="$2" -f merge_method="$3" -q .sha
}
host_branch_delete() { gh api -X DELETE "repos/$(_gh_slug)/git/refs/heads/$1" >/dev/null; }
host_status_post() {       # <sha> <context> <success|failure|pending> <description>
  gh api "repos/$(_gh_slug)/statuses/$1" -f state="$3" -f context="$2" -f description="$4" >/dev/null
}
host_status_get() {        # <sha> <context> → latest state, or nothing
  gh api "repos/$(_gh_slug)/commits/$1/status" --jq ".statuses[] | select(.context==\"$2\") | .state" | head -1
}
host_statuses() { gh api "repos/$(_gh_slug)/commits/$1/status" --jq '.statuses[] | [.context, .state, .description] | @tsv'; }

# host_push <git push args...>: push to origin's repo over HTTPS with $ADLC_HOST_TOKEN.
# The token reaches git through a one-off credential helper, never argv.
host_push() {
  local hostpath
  hostpath=$(git remote get-url origin | sed -E 's#^(ssh://)?git@##; s#^https://([^@/]*@)?##; s#^([^/:]+):#\1/#; s#\.git$##')
  git -c credential.helper= \
    -c 'credential.helper=!f() { echo username=x-access-token; echo "password=$ADLC_HOST_TOKEN"; }; f' \
    push "https://$hostpath.git" "$@"
}
