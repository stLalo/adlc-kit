# Governance

Small project, simple rules.

## Roles

- **Maintainer**: [@stLalo](https://github.com/stLalo). Decides what merges, cuts releases, owns the core and the security model.
- **Adapter contacts**: the people named in `docs/compatibility.md` for Community adapters. They are asked about issues in their adapter.
- **Contributors**: everyone who opens an issue or a pull request.

More maintainers are welcome once someone has carried an area for a while. It is by invitation from the existing maintainers.

## How decisions are made

- Day-to-day: review on the pull request.
- Anything that changes a contract, a gate, or the security model: a decision record in `docs/decisions/` (context, decision, why, rejected alternatives), merged with the change.
- Disagreement: the maintainer decides and writes down why.

## What stays true

These are the project's commitments. A change to any of them needs a decision record.

1. The core names no vendor.
2. Nothing is called "tested" that a maintainer does not run.
3. The kit never claims more enforcement than a setup can deliver.
4. No gate depends on input the change under review controls.
5. The repository holds no secrets, no private data, and no symlinks.

## Releases

Tagged from `main` when the suite is green on Linux and macOS. `CHANGELOG.md` lists what changed and how to migrate.
