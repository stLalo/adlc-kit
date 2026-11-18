# Promote to prod

> **First:** resolve the target repo: the repo named in the input, else the repo of the session or change id (look in each enabled repo's `docs/sessions/INDEX.md`), else the repo you were launched in, else ask. Work inside that repo; paths below are relative to it. `K` is the kit folder: the `ADLC_KIT` environment variable, or the path in `.adlc/kit-path`. Run `K/core/scripts/kit-info.sh [change-id]` once: it prints this repo's `change_dir`, `specs_dir`, spec-tool steps, role models and adapters, which the steps below refer to by those names.

Input: `<change-id> [tag-or-sha]`.

1. Resolve the release: the given ref, or the newest `v<release>-rc.*` tag from intent.md `release:`. Get its sha with `git rev-list -n1 <ref>`.
2. Preconditions (stop and explain if any fail; don't try to work around them):
   - intent.md says `deploy: prod`.
   - `adlc/uat-deploy` and `adlc/uat-tests` are success on that sha (`K/core/scripts/host.sh statuses <sha>`).
   - `.adlc/config.env` has `PROD_DEPLOY_CMD` and `ROLLBACK_CMD`.
3. Run the `release-gate` role with context **prod-approval**, the sha and the change id. It reads the UAT report, maps tests to acceptance criteria and regression paths, and posts `adlc/prod-approval`.
4. Rejected → report its list of missing evidence and the smallest tests to add. Notify the owner. Stop. (Adding the UAT tests is a new change: suggest `/intent`.)
5. Approved → `K/core/scripts/agent-deploy.sh prod <ref> <change-id>`. It tags vX.Y.Z, deploys, runs the smoke check, and rolls back automatically on failure.
6. Append a checkpoint if a session is active. Notify the owner either way: deployed tag, or failure + rollback result.
