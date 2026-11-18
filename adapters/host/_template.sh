# shellcheck shell=bash
# Host adapter template. Copy to adapters/host/<name>.sh, fill in every function, then run
#   bash tests/host-conformance.sh <name>
# against a throwaway repo on your host. The meaning of each function is in adapters/host/CONTRACT.md.
# Also add adapters/host/<name>_rules.py (see github_rules.py) so the guard blocks direct merges,
# status posts and approvals through your host's CLI.
#
# Helpers available here: die "<message>", info "<message>". $ADLC_HOST_TOKEN holds the agent token
# when an identity adapter provides one.

# shellcheck disable=SC2034  # read by core/scripts/lib.sh, which sources this file
HOST_TOKEN_VARS=""            # env var names that carry a credential for this host, space separated

_todo() { die "host adapter '$HOST_ADAPTER': ${FUNCNAME[1]} is not implemented"; }

host_use_token() { _todo; }        # <token>: make the host CLI use this token from now on
host_check() { _todo; }            # die unless the host CLI is installed and logged in
host_repo_id() { _todo; }          # → repo id on the host, e.g. group/project

host_pr_info() { _todo; }          # <pr> → "<OPEN|MERGED|CLOSED> <head-sha> <head-branch> <true|false: fork>"
host_pr_head() { _todo; }          # <pr> → head commit sha
host_pr_body() { _todo; }          # <pr> → description text
host_pr_diff() { _todo; }          # <pr> → unified diff
host_pr_labels() { _todo; }        # <pr> → one label per line
host_pr_checks() { _todo; }        # <pr> → "<check name>\t<state>" per line
host_pr_comments() { _todo; }      # <pr> → comment bodies, oldest first
host_pr_mergeable() { _todo; }     # <pr> → exit 0 only if it can merge without conflicts
host_pr_merge_commit() { _todo; }  # <pr> → merge commit sha of a merged PR
host_pr_for_branch() { _todo; }    # <branch> → "<number> <OPEN|MERGED|CLOSED>" or nothing
host_pr_files() { _todo; }         # <pr> → "<path>\t<old path>\t<added|modified|removed|renamed>\t<changed lines>"; FAIL if the list is incomplete
host_pr_approvers_at() { _todo; }  # <pr> <sha> → users whose latest review approves exactly <sha>
host_user_is_admin() { _todo; }    # <user> → exit 0 only for repo admins / maintainers who own the policy

host_pr_create() { _todo; }        # --base <b> --head <h> --title <t> --body-file <f> → PR number
host_pr_edit_body() { _todo; }     # <pr> <file>
host_pr_comment() { _todo; }       # <pr> <file>
host_pr_label_add() { _todo; }     # <pr> <label>
host_label_ensure() { _todo; }     # <label> <description>: create if missing
host_issue_create() { _todo; }     # --title <t> --body-file <f> → issue number
host_issue_state() { _todo; }      # <n> → OPEN|CLOSED
host_issue_body() { _todo; }       # <n> → description text

host_pr_merge_pinned() { _todo; }  # <pr> <sha> <merge|squash> → merge commit sha; MUST fail if the head is no longer <sha>
host_branch_delete() { _todo; }    # <branch>
host_status_post() { _todo; }      # <sha> <context> <success|failure|pending> <description>
host_status_get() { _todo; }       # <sha> <context> → success|failure|pending, or nothing
host_statuses() { _todo; }         # <sha> → "<context>\t<state>\t<description>" per line
host_push() { _todo; }             # <git push args...>: push to origin's repo using $ADLC_HOST_TOKEN, token never in argv
