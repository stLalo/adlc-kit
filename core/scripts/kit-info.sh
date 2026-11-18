#!/usr/bin/env bash
# kit-info.sh [change-id]
# Prints how the kit is set up for the repo you are in: folders, adapters, spec-tool steps and role
# models. Playbooks run it first so they never hard-code a host, a spec tool or a model. Read-only:
# values are read as data from the working tree, nothing is executed.
source "$(dirname "$0")/lib.sh"
change="${1:-<change-id>}"
cfg() { local v; v="$(data_value .adlc/config.env "$1")"; echo "${v:-${2:-}}"; }
spec="$(cfg SPEC_ADAPTER "$DEFAULT_SPEC_ADAPTER")"; valid_name "$spec"
specfile="$KIT/adapters/spec/$spec.env"
[ -f "$specfile" ] || die "no spec adapter '$spec'"
sp() { data_value "$specfile" "$1" | sed "s/{change}/$change/g"; }
cat <<OUT
kit:            $KIT
repo:           $REPO_ROOT
main_branch:    $(cfg MAIN_BRANCH main)
protected:      $ADLC_PROTECTED_BRANCHES
host:           $HOST_ADAPTER
identity:       $IDENTITY_ADAPTER $([ -n "${ADLC_HOST_TOKEN:-}" ] && echo "(acting as the agent identity)" || echo "(acting as your own login)")
judge:          $(cfg JUDGE_ADAPTER "$DEFAULT_JUDGE_ADAPTER") $(cfg JUDGE_MODEL)
test_cmd:       $(cfg TEST_CMD)
uat_suite:      $([ -n "$(cfg UAT_TEST_CMD)" ] && echo configured || echo "not configured (prod is blocked)")
role_planner:   $(cfg ROLE_PLANNER any)
role_builder:   $(cfg ROLE_BUILDER any)
role_releaser:  $(cfg ROLE_RELEASER any)
spec:           $spec
changes_dir:    $(sp SPEC_CHANGES_DIR)
change_dir:     $(sp SPEC_CHANGES_DIR)/$change
specs_dir:      $(sp SPEC_SPECS_DIR)
docs_paths:     $(sp DOCS_PATHS)
spec_propose:   $(sp SPEC_PROPOSE_HINT)
spec_validate:  $(sp SPEC_VALIDATE_CMD)
spec_archive:   $(sp SPEC_ARCHIVE_HINT)
sessions_dir:   docs/sessions
templates:      $KIT/core/templates
OUT
