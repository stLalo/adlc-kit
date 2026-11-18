# Security model

What stops an agent from merging its own unreviewed work, and what does not. Read this before you trust `merge: auto`.

## The threat

Not a hostile outsider. The threat is a helpful agent that takes a shortcut: merges directly because the script complained, edits a test until it passes, marks its own work approved, pushes to the main branch to "fix it quickly". The second threat is a pull request that changes the rules it is judged by.

## Layers, weakest to strongest

| Layer | Stops | Does not stop |
|---|---|---|
| **1. Instructions** (`AGENTS.md`, playbooks) | An agent that follows instructions. | An agent that ignores or forgets them. |
| **2. Guard** (hooked harnesses; git pre-push hook everywhere) | The common direct routes before they run: host merge commands and APIs, status posts, tags, pushes to protected branches, approvals, edits to the kit, to config and to closed sessions, running the identity adapter. | Code written to a file and run later. A harness without hooks. It is best effort by design. |
| **3. Gated scripts** (`agent-merge.sh`, `agent-deploy.sh`) | Merging without `adlc/judge` and `adlc/final-check` on the exact head commit; a pull request that grants itself `merge: auto` or changes config (both are read from the main branch); failing tests; a moved head (the merge is pinned to the judged commit); prod without UAT evidence and a rollback command. Tests and deploy commands run without the agent's host token. | An agent that does not use the scripts and has another way to merge. |
| **4. Server-side gate** (branch protection on your host) | Any direct push or merge to the main branch, by anyone, with any tool, unless a pull request exists and the required CI check passed. | Whatever your branch protection does not require. |

Layer 4 is the only one the agent cannot reach around. **Set it up**: [server-gate.md](server-gate.md). Without it, treat every other layer as advisory.

## What the server can and cannot verify

The `adlc/*` statuses are posted by the agent's identity. Your host cannot tell an honest `adlc/judge = success` from one the agent posted itself. So:

- Require a check that comes from **CI**, an identity the agent does not control, as the hard gate.
- Do not rely on `adlc/judge` as a required check on the host. It is enforced by `agent-merge.sh` (layer 3), which is as strong as the agent's willingness to use it plus the guard.

## The known residual

Anything the agent can read, it can use. If the agent's session can reach the credentials of the agent identity (the secret manager entry, the kit's `kit.env` refs), code it writes could mint a token and post `adlc/judge` itself. The guard blocks the obvious ways; it cannot block every way.

This is accepted, with eyes open, because the fix has a real cost: running the judge inside CI, where the agent has no access, which means CI minutes and a model API key stored as a CI secret. If your risk needs it, do that: make the judge a CI job and require its check on the host. The `judge.sh` prompt and schema work the same there. See [decisions/0002-judge-gate-residual.md](decisions/0002-judge-gate-residual.md).

What keeps the residual small in practice:
- The CI check is required by the server and cannot be faked.
- Intents that add or change policy need a human approving review from a repo admin.
- `merge: human` for risky changes puts a person at the last step.
- With an agent identity, every action the agent takes is attributed to the bot, not to you.

## Recommendations by setup

| Your setup | Do this |
|---|---|
| Hooked harness, second vendor as judge, agent identity, server gate | `merge: auto` is reasonable for low-risk changes. |
| One vendor, two models | Same, and use `merge: human` for medium risk and up. |
| One model only | `JUDGE_ADAPTER="human"`, or same-model judge with `merge: human` everywhere. |
| No hooks (git-hook floor or instructions only) | Server gate is mandatory. Default to `merge: human`. |
| Regulated environment | `merge: human`, judge in CI, agent identity with the least privilege your host allows, and your normal change control on top. |

## Secrets

- The kit stores no secrets. `kit.env` holds references, a secrets adapter resolves them at run time.
- Tokens are passed through environment variables and credential helpers, never command arguments.
- Repo-controlled commands (`TEST_CMD`, deploy and UAT commands) and the judge run with the agent's token removed from their environment. That is all that is removed: they still run as you, so with the `own-login` identity your host CLI login and credential helper stay within their reach. Use a bot identity and `merge: human` where that matters.
- After a repo-controlled command, the kit refuses to continue if the repo's git config or hooks changed, and reads the intent from the main branch again.
- The judge reads the pull request's checkout. Instruction files in it can try to steer the judge, like the diff itself can. The Claude judge adapter ignores the checkout's settings and hooks; treat the judge as a strong reviewer, not a hard boundary.
- Pull requests from forks are never merged by the agent.
- Session logs are markdown only; `session-save.sh` refuses anything else.

## Reporting a bypass

A way around a gate is a security issue. Report it privately: [SECURITY.md](../SECURITY.md).
