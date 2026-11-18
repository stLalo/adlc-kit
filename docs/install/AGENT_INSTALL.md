# Agent install guide

You are a coding agent. A user asked you to install the ADLC kit in their repository. This guide tells you how to fit the kit to their environment instead of forcing a default on them.

**Your goal:** the user ends with a working kit, adapted to the tools they actually use, and a written plan they approved.

**Ground rules**
- Phases 1 and 2 change nothing except creating one file, `ADLC_ADAPTATION_PLAN.md`.
- Stop after phase 2 and wait for the user's approval. Do not install first and ask later.
- Never read, print or send secrets. You need to know *which* secret manager exists, not what is in it.
- Never weaken a gate silently. If something cannot be enforced in their setup, write it in the plan and say what covers it instead.
- Guide, do not limit. If the user's setup is not supported yet, the answer is an adapter or an honest "skip", not "you cannot use this".
- Ask the user only what you cannot find out yourself. Batch your questions.
- `KIT` below is your clone of this repository. `REPO` is the user's repository.

## Phase 1: discover (read-only)

Find out each item. Record the evidence (a command and its output, or a file path) for the plan.

| # | Question | How to find out |
|---|---|---|
| 1 | **Code host.** Which host and CLI? | `git -C REPO remote -v`. Then `gh --version`, `glab --version`, or the host's own CLI. Is the CLI logged in? (`gh auth status`; do not print tokens.) |
| 2 | **Main branch and protection.** | Default branch name. Is it protected? Is a pull request required? Which checks are required? Who can change that? Ask the user if you cannot read the settings. |
| 3 | **CI.** | Look for `.github/workflows`, `.gitlab-ci.yml`, `bitbucket-pipelines.yml`, `Jenkinsfile`, `azure-pipelines.yml`, others. Which job is the one that must pass? |
| 4 | **Coding agents.** Which agents does the user have, and which one are you? | Check for `claude`, `codex`, `cursor-agent`, `copilot` / `gh copilot`, `gemini`, others on PATH and for their config folders in REPO. Ask which ones the user is licensed to use at work. |
| 5 | **Models.** Which models can each agent use? | Ask. You need: a strong model for planning, a model for building, and whether a *different* model or vendor is available as the judge. |
| 6 | **Hooks.** Can your harness run a program before a shell command or file edit, and at session start? | Your own documentation. If you are not sure, say "unknown" and plan for the git-hook floor. |
| 7 | **Spec tool.** | `openspec/` folder or CLI? Another tool? ADRs or RFC folders? None? |
| 8 | **Tests.** One command that must pass before a merge. | `Makefile`, `package.json`, `pyproject.toml`, CI config. Run it once if it is cheap and safe. |
| 9 | **Deploys.** Is there a UAT or staging environment? A rollback command? | Deploy scripts, CD config. Ask. No UAT suite means the kit keeps prod blocked: that is intended. |
| 10 | **Secrets.** Which secret manager, if any? | Presence of a CLI (`op`, `vault`, `aws`, `gcloud`, `az`, `pass`) and what the user says. Do not query it. |
| 11 | **Agent identity.** Can the user create a bot for the agent (GitHub App, project access token, service account)? | Ask. Optional: the kit works with the user's own login. |
| 12 | **Constraints.** | Ask once: anything their employer forbids or requires? (Approved tools only, no outbound calls, mandatory human review, signed commits, change tickets.) |
| 13 | **Scope.** One repo or several? Who is "the owner" who approves intents and merges? | Ask. |
| 14 | **Platform.** | `uname -s`, `bash --version`, `git --version`, `python3 --version`. The kit needs bash 3.2+, git 2.23+, Python 3.8+. |

Then run the kit's self-test, which is offline and touches nothing in REPO:

```bash
bash KIT/tests/run.sh
```

Report its last line. If it fails on this machine, stop and tell the user: that is a kit bug worth an issue.

## Phase 2: write the plan

Read these before you write: `KIT/docs/concepts.md`, `KIT/docs/adapting.md`, `KIT/docs/security-model.md`, `KIT/docs/compatibility.md`, and the `CONTRACT.md` of any adapter you may need to write.

Create `REPO/ADLC_ADAPTATION_PLAN.md` with exactly these sections:

1. **What I found.** The table from phase 1 with your evidence. Mark anything you guessed.
2. **Decision per part.** One row each for: host, harness, judge, spec, identity, secrets. For every row choose one:
   - **Use shipped**: name the adapter (`KIT/adapters/<part>/`).
   - **Write an adapter**: name it, list the functions or files from the contract, and how you will prove it (for a host: `tests/host-conformance.sh` against a scratch repo the user provides).
   - **Skip**: say exactly what the user loses and what covers the gap.
3. **Roles.** Which model plans, builds, judges and releases. If only one model exists, say so and recommend `JUDGE_ADAPTER="human"` or a same-vendor judge with `merge: human` for risky changes.
4. **Enforcement level.** Hooked, git-hook floor, or instructions only (see `KIT/adapters/harness/CONTRACT.md`), and what that means for this user in one or two sentences.
5. **Server-side gate.** The exact branch protection to set on their host (`KIT/docs/server-gate.md`), and who has the permission to set it.
6. **Config values.** The proposed `.adlc/config.env`: `MAIN_BRANCH`, adapters, `TEST_CMD`, judge model, roles, UAT and prod commands, deploy block patterns. Leave unknowns empty and list them as questions.
7. **Install steps.** The commands you will run, in order, and the files each one creates.
8. **Open questions.** Everything you need the user to decide.
9. **Risks and limits.** What is untested in their combination. Be specific.

Keep it under two pages. Then **stop** and tell the user: the plan is ready, here are the open questions, nothing has been installed.

## Phase 3: after approval, install

1. Write any adapters the plan calls for, in `KIT/adapters/`, from the `_template` files. Keep them small. Run their tests.
2. Run the installer:
   ```bash
   KIT/core/scripts/install-repo.sh REPO --harness <names> --spec <name> --judge <name> --host <name>
   ```
3. Fill `REPO/.adlc/config.env` and `KIT/.adlc/kit.env` from the plan. Once the kit's guard is active in your session it will block you from editing `.adlc/config.env`: that is by design. Edit it now, or hand the values to the user.
4. Put the install on a branch and open a pull request for the user: `.adlc/config.env`, `docs/sessions/INDEX.md`, `AGENTS.md`, `.gitignore`, harness files. Do not merge it yourself. The kit reads its config from the main branch, so it starts working when this pull request is merged.
5. Walk the user through the server-side gate from the plan. They click; you explain.

## Phase 4: prove it

- `bash KIT/tests/run.sh` still passes.
- `KIT/core/scripts/kit-info.sh` in REPO prints the adapters and folders from the plan.
- New host adapter: `tests/host-conformance.sh <name>` passes against the scratch repo. Paste the last line into the plan.
- Hooked harness: show one blocked action. For example, ask yourself to run a push to the main branch and report the block message.
- After the install pull request is merged: run `/sessions`, then offer a first small `/intent` so the user sees the flow end to end.

## Phase 5: give back (optional, ask first)

If you wrote an adapter or found a problem, offer to open an issue or pull request on the kit: `KIT/CONTRIBUTING.md`. Share only the adapter and a compatibility report. Never include the user's repository names, hostnames, employer, or any output that contains private data. Show the user the exact text before anything leaves their machine.

## If you get stuck

- A tool the plan relies on is missing or not logged in: stop and tell the user the exact command to fix it.
- Their policy forbids something the kit does (for example an agent that merges): set `merge: human` as the default in every intent and say so in the plan. The kit is still useful: intent, spec, judge and the session log do not need auto-merge.
- You cannot tell whether something is safe: do not do it. Write it under "Open questions".
