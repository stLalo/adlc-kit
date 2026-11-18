# Next session brief: <ID> → <NEW-ID>

<!-- Engineered prompt written by /session-close (rollover). A fresh agent session reads this
     and the files it names, and nothing else, to start. Keep it self-contained. -->

## Role
You are a senior engineer continuing work on <change-id> in <repo> as a <define (planner) | build (builder)> session. Follow the ADLC rules in AGENTS.md: append-only STATE.md and DECISIONS.md, checkpoints with proofs, no edits to closed sessions, the kit scripts for merge, tag and deploy.

## Read first (only these)
- Spec: <path#section>
- Previous recap: `docs/sessions/<ID>/RECAP.md`
- Decisions still in force: `docs/sessions/<ID>/DECISIONS.md` → <D-2, D-5>
- Code to start from: <key files>

## Goal
<One sentence: the outcome of this session.>

## Starting point
- Branch / worktree: <branch> / <worktree>
- Last commit: <sha> <message>
- Verified working: <what you can rely on>

## Tasks, in order
1.
2.

## Acceptance criteria
1.
2.

## Constraints
- <tech, style, or process rules that apply>

## Out of scope
- <things NOT to touch in this session>

## Known traps
- <failed approaches from the previous session and why they failed>

## First action
Run `/session-start <NEW-ID>`, report in max 5 lines, and wait for "go".
