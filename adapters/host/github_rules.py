"""Guard rule pack for GitHub: direct `gh` / API calls that would go around the gated kit scripts.

Loaded by core/guard/guard.py. A rule pack is a Python file named <host>_rules.py that defines
RULES = [(regex, reason), ...]. Each regex is searched in the command with whitespace collapsed.
All shipped packs are always active: a pack only matches its own host's CLI.
"""

# gh with optional global flags (-R o/r, --repo o/r) before the subcommand.
GH = r"(?:\bgh)(?:\s+-{1,2}[\w-]+(?:[= ]\S+)?)*\s+"
API = r"(?:" + GH + r"api\b|api\.github\.com|/api/v3/)"

RULES = [
    (GH + r"pr\s+merge\b", "merge only through agent-merge.sh"),
    (API + r".*pulls/[^\s/]+/merge\b", "merge only through agent-merge.sh"),
    (API + r".*repos/\S+/merges\b", "merge only through agent-merge.sh"),
    (API + r".*graphql.*(mutation|[\s=]@|--input)",
     "GraphQL mutations are not allowed; use host.sh or the kit scripts"),
    (API + r".*(statuses|check-runs)", "commit statuses are posted only by the kit scripts"),
    (API + r".*git/refs.*(-X\s*(POST|PATCH|PUT|DELETE)|--method\s+(POST|PATCH|PUT|DELETE)|\s-[fF]\s|--field|--raw-field)",
     "refs and tags are written only by the kit scripts"),
    (GH + r"release\s+create\b", "tags are created only by the kit scripts"),
    (API + r".*(branches/.*/protection|rulesets)", "don't change branch protection"),
    (GH + r"(pr|issue)\s+edit\b.*--remove-label\s+['\"]?needs-human", "only the owner clears needs-human"),
    (GH + r"pr\s+review\b.*(--approve|\s-a\b)", "only the owner approves pull requests"),
    (API + r".*pulls/[^\s/]+/reviews", "only the owner approves pull requests"),
    (GH + r"auth\s+(token|status\b.*(-t\b|--show-token))", "don't read host tokens"),
]
