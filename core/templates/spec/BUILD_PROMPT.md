# Build prompt: <change-id>

<!-- Written by the planner at /handoff, reviewed by the owner, merged with the spec. A build session (the builder)
     starts from this file and the files it names. Self-contained: no conversation history needed. -->

## Role
You are a senior engineer implementing an approved change in <repo>. The intent and spec are decided; do not redesign them. If the spec is wrong or impossible, stop and escalate instead of improvising.

## Read first (only these)
- Intent: `<change_dir>/intent.md`
- Spec: the spec files in `<change_dir>/`
- Design and decisions: `<change_dir>/design.md`
- Tasks (your plan, in order): `<change_dir>/tasks.md`
- Code to start from: <key files and why>

## Setup
- Branch: `feat/<change-id>` from `<main>` at <sha or tag>
- Dependencies that must already exist: <tag / merged PR, or none>
- Commands: build `<cmd>` · test `<cmd>` · lint `<cmd>`

## How to work
1. Do the tasks in tasks.md in order. Check each off only after its `proof:` passes.
2. Write tests with the code. For a bug fix: commit the failing test first, then fix without editing that test.
3. `/checkpoint` after each verified task group, with the proof command and result.
4. Record any decision between real alternatives in the session DECISIONS.md.
5. Two failed attempts at the same problem → stop, checkpoint, `/session-close rollover` with kind: define, and say what blocked you.
6. When all tasks are done, run `/ship`.

## Done when
- Every acceptance criterion in the spec has a passing test.
- `/ship` completes, or stops at a gate that needs the owner.

## Do not
- Change the intent, spec, or files outside the scope in design.md.
- Weaken, skip or delete existing tests.
- Touch the kit, your harness settings, or `.adlc/config.env`.

## Known traps
- <anything the define session learned that will bite the builder>
