---
id:            # YYYY-MM-DD-<change-id>
kind: build    # define (planner) | build (builder)
status: active # queued | active | in-review | complete | rolled-over | abandoned
change:        # change id
issue:         # issue on the host
brief:         # file this session starts from (BUILD_PROMPT.md or a previous NEXT_SESSION.md)
branch:
worktree:
pr:
opened:
closed:
rolled_from:
rolled_to:
---

<!-- Front matter changes only at open, ship and close. Progress lives in STATE.md. -->

## Goal
<One sentence. For build sessions: "Implement <change-id> until /ship passes the gates its intent allows.">
