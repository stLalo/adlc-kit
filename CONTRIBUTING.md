# Contributing

Thank you for helping. This kit can only be as wide as the people who use it: maintainers test GitHub, Claude Code and Codex. Every other host and agent arrives through you.

## The four contributions we want most

| Kind | Example | Start here |
|---|---|---|
| **Compatibility report** | "Ran it with Cursor on GitLab; here is what worked and what did not." | the Compatibility report issue form |
| **Adapter** | a GitLab host adapter, a Copilot harness, a judge for your model gateway | `docs/adapting.md`, the adapter's `CONTRACT.md` |
| **Core fix** | a gate that can be bypassed, a script that breaks on macOS | an issue first, unless it is small |
| **Docs** | anything you had to work out yourself | a pull request |

New features in `core/` (new stages, new gates, new commands): open an issue before writing code. The core is deliberately small.

## What a good pull request looks like

1. **One concern.** An adapter, or a fix, or a doc change. Not a mix.
2. **It explains why.** What problem, for whom. Link the issue.
3. **It is proven.** The description contains the commands you ran and their result lines:
   ```
   bash tests/run.sh          → ---- 154/154 passed
   bash tests/public-scan.sh  → public scan: clean
   ```
   "Should work" is not evidence.
4. **It adds tests** for what it changes (see below).
5. **It updates the docs it makes wrong**, in the same pull request: `docs/compatibility.md`, the contract, `CHANGELOG.md` under "Unreleased".
6. **It is signed off** (`git commit -s`, see DCO below).
7. **It contains nothing private.** No company names, internal hostnames, real repository names, tokens, or paths from your machine. CI scans for the obvious ones; you are responsible for the rest.

## Rules by area

### Core (`core/`)

- Names no vendor: no host CLI, no agent CLI, no model name. `tests/public-scan.sh` enforces it. If you need one, the code belongs in an adapter, or the contract needs a new function.
- Scripts stay bash 3.2 compatible and work with BSD and GNU tools (macOS and Linux). No `mapfile`, no associative arrays, no `sed -i` without a suffix, no `readlink -f`, no `grep -P`, no `date -d`.
- Python is standard library only, 3.8+.
- Playbooks and role briefs use neutral words: "the owner", "the planner", "run the role". Harness-specific wording goes in the harness adapter's `NOTES.md`.

### Guard and gates (`core/guard/`, `core/scripts/agent-merge.sh`, `agent-deploy.sh`, `judge.sh`, `release-decision.sh`, `lib.sh`)

- Every rule change adds cases to `tests/guard_cases.tsv`: at least one that must be blocked and one similar command that must stay allowed. False positives matter as much as misses.
- A change that **tightens** a gate needs a test.
- A change that **loosens** a gate, adds a bypass, or widens what an agent may do needs a decision record in `docs/decisions/` and explicit maintainer approval. Expect questions.
- Never make a gate depend on something the pull request under review controls. Policy is read from the main branch.

### Adapters (`adapters/`)

An adapter pull request must:

- Implement the **whole** contract. If your tool cannot do something, the function fails with a clear message, and the adapter's header says so.
- Pass the tests for its kind:
  - host: `tests/host-conformance.sh <name>` against a real scratch repository. Paste the last line.
  - host: a `<name>_rules.py` guard pack with cases in `tests/guard_cases.tsv`.
  - judge: one real verdict on a sample change (paste the verdict line, not your code).
  - harness: the install is safe to re-run; state the enforcement level.
- Add a row to `docs/compatibility.md` at the tier it earned: **Community** with evidence and your name as the contact, otherwise **Experimental**.
- Add no dependency beyond the tool it adapts.

Maintainers cannot run most adapters. We review them against the contract and your evidence, and we rely on you for issues about them. An adapter whose contact stops answering moves to Experimental.

### Docs

Short sentences, plain words, one idea per bullet. Say what is tested and what is not. Diagrams in mermaid.

## Development setup

```bash
git clone https://github.com/stLalo/adlc-kit && cd adlc-kit
bash tests/run.sh           # offline, about 30 s; needs bash, git, python3, openssl
bash tests/public-scan.sh
shellcheck -x core/scripts/*.sh adapters/*/*.sh adapters/harness/*/install.sh tests/*.sh   # if installed
```

The suite copies the kit to a temp folder and uses a fake host CLI. It never touches your repositories or your git config.

Working on the kit with a coding agent: point it at [AGENTS.md](AGENTS.md).

## Commits and versions

- Conventional commits: `feat(host): ...`, `fix(guard): ...`, `docs: ...`, `test: ...`.
- Semantic versioning. Before 1.0, a minor version may change config keys or contracts; the changelog says how to migrate.
- A contract change bumps the minor version and updates every shipped adapter in the same pull request.

## Developer Certificate of Origin

We use the [DCO](https://developercertificate.org/) instead of a contributor license agreement. Add a sign-off line to each commit:

```bash
git commit -s -m "feat(host): add gitlab adapter"
```

It certifies that you wrote the change or have the right to submit it under the project's Apache-2.0 license. If your employer owns your work, check that you may contribute before you do.

## Review

- A maintainer answers within about a week. Small, proven pull requests go first.
- CI must pass. Changes under `core/guard/` and `core/scripts/` need a maintainer who owns that code (`.github/CODEOWNERS`).
- We may ask you to split a pull request. We may say no to a feature that widens the core; an adapter or a doc is often the better home.

## Security

Found a way around a gate? Do not open a public issue. See [SECURITY.md](SECURITY.md).

## Conduct

Be kind, be specific, assume good faith. [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
