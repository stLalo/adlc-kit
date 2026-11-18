#!/usr/bin/env bash
# uat-test.sh <sha>
# Runs the UAT regression/integration suite against the UAT environment and posts adlc/uat-tests
# on that exact commit. No suite configured = failure (prod stays blocked).
source "$(dirname "$0")/lib.sh"
load_config

sha="${1:?usage: uat-test.sh <sha>}"
mkdir -p .adlc/reports
report=".adlc/reports/uat-${sha:0:12}.log"

if [ -z "${UAT_TEST_CMD:-}" ]; then
  post_status "$sha" adlc/uat-tests failure "no UAT suite configured (UAT_TEST_CMD empty)"
  echo "No UAT suite configured. Prod promotion is blocked until UAT_TEST_CMD is set." >&2
  exit 4
fi

info "running UAT suite: $UAT_TEST_CMD"
rc=0; REF="$sha" run_untrusted "$UAT_TEST_CMD" 2>&1 | tee "$report" || rc=$?
agent_identity fresh        # the suite may outlast a short-lived token
if [ "$rc" = 0 ]; then
  post_status "$sha" adlc/uat-tests success "UAT suite passed ($(grep -c . "$report") log lines)"
  echo "$report"
else
  post_status "$sha" adlc/uat-tests failure "UAT suite failed; see $report"
  exit 1
fi
