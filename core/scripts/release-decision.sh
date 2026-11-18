#!/usr/bin/env bash
# release-decision.sh <final-check|prod-approval> <approve|reject> <sha> "<reason>"
# Used ONLY by the release-gate role (the releaser). Posts status adlc/<context>.
# It cannot touch adlc/judge: a judge failure always blocks.
source "$(dirname "$0")/lib.sh"

ctx="${1:?context}"; decision="${2:?approve|reject}"; sha="${3:?sha}"; reason="${4:?reason}"
case "$ctx" in final-check|prod-approval) ;; *) die "context must be final-check or prod-approval";; esac
case "$decision" in
  approve) state=success ;;
  reject)  state=failure ;;
  *) die "decision must be approve or reject" ;;
esac

if [ "$state" = success ]; then
  case "$ctx" in
    final-check)   require_status "$sha" adlc/judge ;;      # the releaser cannot approve past the judge
    prod-approval) require_status "$sha" adlc/uat-tests ;;  # no UAT evidence, no prod
  esac
fi
post_status "$sha" "adlc/$ctx" "$state" "$reason"
