# The server-side gate

The one control an agent cannot reach around. Set it on your code host for every repo where the kit may merge.

## What to require on the main branch

1. **Changes only through a pull request.** No direct pushes, for everyone, admins included if your host allows that.
2. **One required check that comes from CI.** A single job that runs your tests (the same thing as `TEST_CMD`). One stable name is easier to require than many; `ci/gate` is the convention used here.
3. **No force pushes, no deletion** of the main branch.
4. **Tags `v*` protected** if your host supports it: only the agent identity and owners may create them.
5. **Who can bypass:** people, deliberately and rarely. Never the agent identity.

Do **not** make `adlc/judge` or `adlc/final-check` required on the host: the agent's identity posts them, so the host cannot tell them from a self-post. `agent-merge.sh` enforces them. See [security-model.md](security-model.md).

If you use an agent identity (a bot), give it: read and write on code and pull requests, write on commit statuses, and nothing on repository administration.

## GitHub (tested)

A repository ruleset on the default branch:

- Restrict deletions; block force pushes.
- Require a pull request before merging (0 required approvals is fine if you rely on the judge; raise it if you want a person on every change).
- Require status checks to pass: add the CI job's check name (for example `ci/gate`). Pick it from the list after it has run once.
- Bypass list: repository admins only, or nobody.
- Allowed merge methods must include the kit's `MERGE_METHOD`.

A minimal workflow that produces the check:

```yaml
name: ci
on: { pull_request: {} }
permissions: { contents: read }
jobs:
  gate:
    name: ci/gate
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make test        # the same command as TEST_CMD
```

With a GitHub App as the agent identity: permissions Contents (read and write), Pull requests (read and write), Issues (read and write), Commit statuses (read and write), Metadata (read). No Administration.

## Other hosts (not verified by maintainers)

The same four requirements exist under other names. These pointers are a starting place; check them against your host's documentation and tell us what worked.

| Host | Pull request required | Required CI check | Notes |
|---|---|---|---|
| GitLab | Protected branches: nobody allowed to push | Merge requests: pipelines must succeed | Protected tags for `v*`. A project access token can be the agent identity. |
| Bitbucket | Branch restrictions: prevent direct pushes | Merge checks: minimum number of successful builds | Enforcing merge checks may depend on your plan. |
| Azure DevOps | Branch policies: require a pull request | Build validation policy | |
| Gitea / Forgejo | Branch protection: disable push | Status checks required | |

Pinned merges (merge only if the head is still commit X) differ by host. If yours cannot do it server-side, the host adapter re-reads the head just before merging and must say so.

## Check it

From a clone, as yourself and as the agent identity:

```bash
git push origin HEAD:main          # must be rejected by the server
```

Then open a pull request with a failing test: the merge button, and `agent-merge.sh`, must both refuse.
