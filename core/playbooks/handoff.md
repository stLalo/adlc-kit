# Hand off to a build session

> **First:** resolve the target repo: the repo named in the input, else the repo of the session or change id (look in each enabled repo's `docs/sessions/INDEX.md`), else the repo you were launched in, else ask. Work inside that repo; paths below are relative to it. `K` is the kit folder: the `ADLC_KIT` environment variable, or the path in `.adlc/kit-path`. Run `K/core/scripts/kit-info.sh [change-id]` once: it prints this repo's `change_dir`, `specs_dir`, spec-tool steps, role models and adapters, which the steps below refer to by those names.

Input: a change id (default: the change of the active define session on this branch).

## 1. Validate the change folder
`<change_dir>` must have intent.md, the proposal, the spec with acceptance criteria, design.md and tasks.md.
- Run `spec_validate` from `kit-info.sh` if it is not empty and the tool is installed.
- intent.md "Open questions" is empty.
- Every acceptance criterion traces to an intent "what good looks like" line, and back.
- Every task in tasks.md ends with `proof:`. Tasks are ordered and small (each one verifiable on its own).
- design.md has Risks and rollback.
- Size check: one pull request, roughly a day of agent work. If bigger, stop and propose a split (two changes, two intents).
Report problems and fix them with the owner before continuing.

## 2. Write BUILD_PROMPT.md
From `K/core/templates/spec/BUILD_PROMPT.md` into the change folder. It must stand alone: a builder session with no history can start from it. Include the exact build/test/lint commands, the starting branch/tag, dependencies (blocked-by), and traps learned in this session.

## 3. Approval
Show the owner: the acceptance criteria, the task list, the policy (merge/tag/deploy), and the BUILD_PROMPT "Known traps". Wait for "approve". Iterate on comments.

## 4. Queue the build session and close this one
1. Create `docs/sessions/<YYYY-MM-DD>-<id>-build/` with SESSION.md (kind: build, status: queued, change, issue, brief: `<change_dir>/BUILD_PROMPT.md`, rolled_from: this session) plus empty STATE.md and DECISIONS.md. INDEX.md row.
2. Close this define session, in this order (the folder is frozen the moment status changes): final checkpoint → RECAP.md (Outcome: complete; "Left over" empty unless the split created another intent) → SESSION.md `rolled_to:` the build session and `closed:` date → SESSION.md `status: complete` last. Update INDEX.md.
3. Commit, push with `K/core/scripts/agent-push.sh -u define/<id>`, and open the docs pull request with `K/core/scripts/host.sh pr_create`. The body must include the line `adlc-change: <id>` and a reference to the issue.
4. Ask the owner to approve the pull request on the host (it carries intent.md, which sets the merge and deploy policy, so the agent can't approve it for itself). Then merge it: `K/core/scripts/agent-merge.sh <pr> --docs`. It refuses if any file outside `docs_paths` changed, or if intent.md changed without an approving review from a repo admin on the current head.

## 5. Tell the owner (max 4 lines)
- Spec merged: PR link.
- Next, in a **new conversation** on the builder model (`role_builder`): `/session-start <build-session-id>`.
