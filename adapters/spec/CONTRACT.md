# Spec adapter contract

A spec adapter tells the kit where a repo keeps its change folders and specs, and which steps your spec tool uses. It is one file of `KEY="value"` lines, `adapters/spec/<name>.env`, chosen by `SPEC_ADAPTER` in `.adlc/config.env`.

| Key | Required | Meaning |
|---|---|---|
| `SPEC_CHANGES_DIR` | yes | Folder that holds one folder per change: `<dir>/<change-id>/`. Each change folder has an `intent.md`. |
| `DOCS_PATHS` | yes | Space-separated top-level folders a docs-only pull request may touch. Must include the changes folder's top level and `docs` (session logs live in `docs/sessions/`). |
| `SPEC_ARCHIVE_RE` | no | Regex for the prefix of an archived change folder, relative to `SPEC_CHANGES_DIR`, for example `archive/[0-9]{4}-[0-9]{2}-[0-9]{2}-`. Moving a change there without editing its intent needs no new approval. |
| `SPEC_SPECS_DIR` | no | Folder with the current, accepted specs. The judge reads it. |
| `SPEC_INIT_HINT` | no | How to create the folders in a new repo. |
| `SPEC_PROPOSE_HINT` | no | How to write the proposal, spec, design and tasks for `{change}`. |
| `SPEC_VALIDATE_CMD` | no | Command that validates `{change}`. Empty = no tool check. |
| `SPEC_ARCHIVE_HINT` | no | How to archive `{change}` and sync the accepted specs. |

What the kit needs from any spec tool:
- An `intent.md` per change, with the front matter in `core/templates/spec/intent.md` (`merge`, `tag`, `deploy`, `release`). The merge and deploy policy is read from there, from the main branch.
- Acceptance criteria the judge can check.
- A `tasks.md` whose tasks each end with `proof: <command or test>`.

Shipped: `openspec` and `plain` (markdown only, no tool).
