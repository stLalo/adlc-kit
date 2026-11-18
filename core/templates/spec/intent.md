---
change: <change-id>           # kebab-case, verb first: add-csv-export
repo: <owner/repo>            # exactly one repo
issue: <#number>              # issue for this intent; parent issue below if multi-repo
parent: <#number or none>     # initiative issue when this is one repo of several
blocked-by: <#issue / tag or none>
merge: auto                   # auto | human
tag: rc                       # none | rc
deploy: uat                   # none | uat | prod
release: <X.Y.Z or none>      # version the rc/final tags use
risk: low                     # low | medium | high  (high = auth/IAM, data migration, infra, public API, secrets)
---

# <Plain title a person would say out loud>

## The problem
<Two to four sentences. Who has the problem, what happens today, why it matters now. No solution here.>

## What we want instead
<The outcome, in plain words. What is different for the user or system when this is done.>

## What good looks like
<Each line must be checkable by a test or a command. These become the spec's acceptance criteria.>
1.
2.
3.

## Not doing
- <explicit non-goals, so nobody "helpfully" adds them>

## Constraints
- <tech, compatibility, performance, cost, timeline>

## Risks and rollback
<What could go wrong in UAT or prod, and how we undo it. Required if risk is medium or high, or deploy is prod.>

## Open questions
- <anything still undecided; must be empty before the spec is written>

<details><summary>Original request (verbatim)</summary>

<The owner's own words, pasted unchanged.>

</details>
