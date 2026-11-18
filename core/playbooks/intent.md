# Define intent

> **First:** resolve the target repo: the repo named in the input, else the repo of the session or change id (look in each enabled repo's `docs/sessions/INDEX.md`), else the repo you were launched in, else ask. Work inside that repo; paths below are relative to it. `K` is the kit folder: the `ADLC_KIT` environment variable, or the path in `.adlc/kit-path`. Run `K/core/scripts/kit-info.sh [change-id]` once: it prints this repo's `change_dir`, `specs_dir`, spec-tool steps, role models and adapters, which the steps below refer to by those names.

Input: `<repo> "<what the owner wants, in their words>"` or `<repo> #<issue>`.

You are running a **define session**. It belongs to the planner model (`role_planner` in `kit-info.sh`). If that names a model and you are not it, tell the owner to switch and stop.

## 1. Capture the raw words
- The first word is the target repo (a repo with `.adlc/config.env`). Missing → ask which repo.
- If the rest is `#<n>`, read that issue's body as the raw request (`K/core/scripts/host.sh issue_body <n>`): a child of a multi-repo initiative.
- Otherwise the input is the raw request. If it is empty, ask for it.
- Keep it verbatim. It goes, unchanged, at the bottom of intent.md.

## 2. Orient (read-only, quick)
`git status`, list `specs_dir` and `changes_dir`, README, and any existing spec the request touches. Note which repos the request touches. Do not explore beyond what the questions need.

## 3. Interview
Find the gaps against the template `K/core/templates/spec/intent.md`: problem, outcome, what good looks like (checkable), not doing, constraints, risks and rollback, repos affected, merge/tag/deploy policy, release version.
Ask the owner, max 4 questions per round, max 3 rounds. Offer concrete options with your recommendation first. Ask only what you can't answer from the repo.
Propose the policy yourself from risk: default `merge: auto`, `tag: rc`, `deploy: uat`. Recommend `deploy: prod` only when a UAT suite exists (`uat_suite: configured`). Recommend `merge: human` for auth/IAM, data migrations, infra, public API contracts, secrets.

## 4. Draft intent.md
Write it so the owner would sign it as their own:
- Short sentences. Plain words. Their terms, not yours.
- No filler: no "leverage", "robust", "seamless", "comprehensive", "ensure", no em-dash asides.
- Prose for problem and outcome; numbered lines only for "what good looks like".
- Every "what good looks like" line must be checkable by a test or command.
- One repo per intent. `change:` is kebab-case, verb first.

## 5. Critique
Run the `intent-critic` role on the draft (in a fresh context: a subagent or a separate session, so it has not seen your reasoning). If the work spans repos, risk is high, or deploy is prod, also run `intent-critic-deep` after it.
Fix blocking issues by asking the owner, never by guessing. Repeat at most twice.

## 6. Multi-repo?
If the request spans repos, it is an **initiative**:
- Draft a parent issue: title, the problem/outcome in 3–5 sentences, and the ordered list of per-repo pieces with blocked-by.
- Write the intent for **this** repo only. Each other repo gets its own child issue (created in that repo) whose body is its draft intent; later run `/intent <other-repo> #<child>`. You can read the other repos now to make the split accurate, but don't write to them in this session.

## 7. Approval
Show the final intent (and parent/child issue drafts). Summarize the critic verdicts in 3 lines. Wait for "approve". Iterate on comments.

## 8. On approval
1. Branch `define/<change-id>` from the up-to-date main branch.
2. Create `<change_dir>/intent.md`.
3. Create issues with `K/core/scripts/host.sh issue_create --title <t> --body-file <f>` (parent first if any; children reference the parent). Put the issue numbers into intent.md front matter.
4. Open the define session: `docs/sessions/<YYYY-MM-DD>-<change-id>-define/` from `K/core/templates/sessions/` (SESSION.md kind: define, status: active, change, issue; STATE.md; DECISIONS.md). Add the INDEX.md row. Record the key choices made in the interview as D-lines.
5. Commit: `docs(intent): <change-id>`.
6. Tell the owner to name this conversation `<session-id>`, then the next steps: write the spec (`spec_propose` from `kit-info.sh`), then `/handoff`.

When the spec is written in this repo, follow these conventions:
- The proposal's "Why": one or two lines plus a link to `intent.md`. Don't restate it.
- Acceptance criteria in the spec = the intent's "what good looks like", made precise.
- design.md includes **Risks and rollback**.
- Every task in tasks.md ends with `proof: <command or test>`.
