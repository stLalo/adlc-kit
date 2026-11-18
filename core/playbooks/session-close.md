# Close a session

> **First:** resolve the target repo: the repo named in the input, else the repo of the session or change id (look in each enabled repo's `docs/sessions/INDEX.md`), else the repo you were launched in, else ask. Work inside that repo; paths below are relative to it. `K` is the kit folder: the `ADLC_KIT` environment variable, or the path in `.adlc/kit-path`. Run `K/core/scripts/kit-info.sh [change-id]` once: it prints this repo's `change_dir`, `specs_dir`, spec-tool steps, role models and adapters, which the steps below refer to by those names.

Input: a mode: `complete`, `rollover`, `in-review` or `abandon`.
If empty: compare tasks.md and the acceptance criteria with the last STATE.md entry, recommend a mode, and wait for confirmation.
(Define sessions normally close through `/handoff`; build sessions through `/ship`.)

## 1. Clean up
1. Identify the active session for the current branch.
2. `git status`: list uncommitted changes; ask commit, stash or leave. Wait for the answer.
3. Run the `verifier` role if this is a build session and code changed since the last checkpoint.
4. Append a final checkpoint.

## 2. Mode
**in-review**: the work is waiting on the owner (merge: human, needs-human, failed UAT). Don't write RECAP yet. Set `status: in-review`, update INDEX.md, and save with `K/core/scripts/session-save.sh <id>` (not a commit on the PR branch). Notify the owner. Done; `/session-start` resumes it later.

**complete / rollover / abandon**: write RECAP.md from `K/core/templates/sessions/RECAP.md` (max 60 lines; once; if it exists, stop and ask). Fill the release trail from the pull request, statuses and tags. Put leftovers under "Left over → next intent".

**rollover** additionally:
1. NEXT_SESSION.md in this folder from the template: self-contained engineered prompt with only leftover work, decisions still in force, traps. If the problem is the spec itself, the next session is `kind: define` (planner); otherwise `kind: build`.
2. Propose the next ID (`<YYYY-MM-DD>-<change-id>-<define|build>`, add `-2` etc. if taken). Wait for OK.
3. Create that folder: SESSION.md (status queued, kind, change, issue, brief: this folder's NEXT_SESSION.md, rolled_from), empty STATE.md and DECISIONS.md. INDEX.md row.

**abandon**: one-line reason from the owner into RECAP's Outcome.

## 3. Freeze (order matters: the folder is frozen when status changes)
1. SESSION.md: `closed:` date, `rolled_to:` if any.
2. SESSION.md `status:` complete | rolled-over | abandoned: the last edit in this folder.
3. INDEX.md row.

## 4. Land it
If the branch's code is already merged, put the close on `chore/close-<id>` (restore the logs with `session-save.sh --restore <id>` if this worktree lacks them), open a pull request whose body has `adlc-change: <change-id>`, merge with `K/core/scripts/agent-merge.sh <pr> --docs`, then `session-save.sh --drop <id>`. If no pull request is open yet, commit to the feature branch so it merges with the code. If a pull request is open and unmerged, save with `session-save.sh <id>` and land the close after the merge.

## 5. Reply (max 4 lines)
Outcome, recap path, and for a rollover: open a **new conversation** on the right model (planner for define, builder for build), then `/session-start <new-id>`.
