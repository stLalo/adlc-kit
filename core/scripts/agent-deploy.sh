#!/usr/bin/env bash
# agent-deploy.sh <uat|prod> <ref> <change-id>
#
# uat : intent says deploy: uat|prod, ref is on the main branch → deploy to UAT, then run the UAT suite.
# prod: intent says deploy: prod, rollback + deploy commands configured, adlc/uat-tests and
#       adlc/prod-approval are success on this exact commit → tag vX.Y.Z (final), deploy,
#       smoke test, and roll back automatically if deploy or smoke fails.
source "$(dirname "$0")/lib.sh"
load_config

env="${1:?usage: agent-deploy.sh <uat|prod> <ref> <change-id>}"
ref="${2:?ref}"; change="${3:?change-id}"
intent=$(intent_path "$change")
policy=$(intent_field "$intent" deploy)

git fetch --quiet --tags origin "$MAIN_BRANCH"
sha=$(git rev-list -n1 "$ref") || die "unknown ref $ref"
git merge-base --is-ancestor "$sha" "origin/$MAIN_BRANCH" || die "$ref is not on $MAIN_BRANCH"

case "$env" in
uat)
  [[ "$policy" =~ ^(uat|prod)$ ]] || die "intent says deploy: ${policy:-none}"
  [ -n "${UAT_DEPLOY_CMD:-}" ] || die "UAT_DEPLOY_CMD not configured"
  info "deploying $ref (${sha:0:7}) to UAT"
  rc=0; REF="$ref" run_untrusted "$UAT_DEPLOY_CMD" || rc=$?
  agent_identity fresh      # the deploy may outlast a short-lived token
  [ "$rc" = 0 ] || { post_status "$sha" adlc/uat-deploy failure "UAT deploy failed"; die "UAT deploy failed"; }
  post_status "$sha" adlc/uat-deploy success "deployed $ref to UAT"
  "$SCRIPT_DIR/uat-test.sh" "$sha"
  ;;
prod)
  [ "$policy" = "prod" ] || die "intent says deploy: ${policy:-none} — prod not allowed for this change"
  [ -n "${PROD_DEPLOY_CMD:-}" ] || die "PROD_DEPLOY_CMD not configured"
  [ -n "${ROLLBACK_CMD:-}" ]    || die "ROLLBACK_CMD not configured — no prod without a rollback"
  require_status "$sha" adlc/uat-deploy
  require_status "$sha" adlc/uat-tests
  require_status "$sha" adlc/prod-approval

  ver=$(intent_field "$intent" release)
  release_ref="$ref"
  if [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    tag="v$ver"
    if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
      [ "$(git rev-list -n1 "$tag")" = "$sha" ] || die "$tag already exists on another commit"
    else
      git tag -a "$tag" "$sha" -m "$tag release (change $change)"
      "$SCRIPT_DIR/agent-push.sh" --quiet "refs/tags/$tag"
      info "tagged $tag"
    fi
    release_ref="$tag"
  fi

  info "deploying $release_ref (${sha:0:7}) to PROD"
  if REF="$release_ref" run_untrusted "$PROD_DEPLOY_CMD" && { [ -z "${PROD_SMOKE_CMD:-}" ] || REF="$release_ref" run_untrusted "$PROD_SMOKE_CMD"; }; then
    agent_identity fresh
    post_status "$sha" adlc/prod-deploy success "deployed $release_ref to prod"
    notify "PROD deployed: $release_ref ($change)"
  else
    agent_identity fresh
    post_status "$sha" adlc/prod-deploy failure "prod deploy/smoke failed; rolled back"
    info "rolling back: $ROLLBACK_CMD"
    REF="$release_ref" run_untrusted "$ROLLBACK_CMD" || notify "ROLLBACK FAILED for $release_ref — needs the owner now"
    notify "PROD deploy failed and was rolled back: $release_ref ($change)"
    exit 1
  fi
  ;;
*) die "env must be uat or prod" ;;
esac
