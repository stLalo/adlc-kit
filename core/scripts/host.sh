#!/usr/bin/env bash
# host.sh <verb> [args...]
# The agent's way to talk to the code host (pull requests, issues, statuses), as the agent identity
# when one is configured. It works the same on every host adapter, so playbooks never name a host CLI.
#
# Only reads and ordinary writes are available here. Merging, posting statuses, tagging and clearing
# labels go through the gated scripts (agent-merge.sh, judge.sh, release-decision.sh, agent-deploy.sh).
#
#   host.sh check                                   is the host CLI installed and logged in?
#   host.sh repo_id                                 owner/name of this repo on the host
#   host.sh pr_for_branch <branch>                  "<number> <OPEN|MERGED|CLOSED>" or nothing
#   host.sh pr_info <pr>                            "<state> <head-sha> <branch> <is-fork>"
#   host.sh pr_head <pr> | pr_body <pr> | pr_diff <pr> | pr_labels <pr> | pr_checks <pr>
#   host.sh pr_create --base <b> --head <h> --title <t> --body-file <f>     prints the PR number
#   host.sh pr_edit_body <pr> <file>
#   host.sh pr_comment <pr> <file>
#   host.sh pr_comments <pr>                        comment bodies, newest last
#   host.sh issue_create --title <t> --body-file <f>                        prints the issue number
#   host.sh issue_state <n> | issue_body <n>
#   host.sh statuses <sha>                          "<context>\t<state>\t<description>" per line
#   host.sh status_get <sha> <context>              success|failure|pending, or nothing
source "$(dirname "$0")/lib.sh"

verb="${1:?usage: host.sh <verb> [args...]  (see the header of this file)}"; shift
case "$verb" in
  check|repo_id|pr_for_branch|pr_info|pr_head|pr_body|pr_diff|pr_labels|pr_checks|pr_create|pr_edit_body|\
  pr_comment|pr_comments|issue_create|issue_state|issue_body|statuses|status_get)
    "host_$verb" "$@" ;;
  *) die "'$verb' is not available through host.sh: merges, statuses, tags and label changes go through the gated kit scripts" ;;
esac
