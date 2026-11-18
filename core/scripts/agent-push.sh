#!/usr/bin/env bash
# agent-push.sh [-u|--set-upstream] [git push args...] <refspec...>
# git push to origin as the agent identity when one is configured (the host adapter pushes with the
# token; it never reaches argv). Without an agent identity this is a plain `git push origin`.
# A leading "origin" is accepted and dropped (the remote is always origin). -u sets the upstream
# to origin/<branch> after the push.
source "$(dirname "$0")/lib.sh"

upstream=0 args=() seen_ref=0
for a in "$@"; do
  case "$a" in
    -u|--set-upstream) upstream=1 ;;
    -*) args+=("$a") ;;
    origin) if [ "$seen_ref" = 0 ]; then seen_ref=1; else args+=("$a"); fi ;;  # the first non-option "origin" is the remote
    *) seen_ref=1; args+=("$a") ;;
  esac
done
[ ${#args[@]} -gt 0 ] || { echo "usage: agent-push.sh [-u] [push options] <refspec...>" >&2; exit 2; }

export ADLC_KIT_PUSH=1                        # lets the kit's own pre-push hook pass tag and session pushes
if [ -n "${ADLC_HOST_TOKEN:-}" ]; then host_push "${args[@]}"
else git push origin "${args[@]}"; fi          # no agent identity: push as the git user

if [ "$upstream" = 1 ]; then
  for a in "${args[@]}"; do
    case "$a" in -*) continue ;; esac
    a=${a#+}; src=${a%%:*}; dst=${a#*:}
    [ "$src" = HEAD ] && src=$(git symbolic-ref --short -q HEAD || true)
    src=${src#refs/heads/}; [ "$dst" = HEAD ] && dst=$src; dst=${dst#refs/heads/}
    [ -n "$src" ] && git show-ref --verify --quiet "refs/heads/$src" || continue
    # Same config `git push -u origin` writes; works even when origin's fetch refspec is narrow.
    git config "branch.$src.remote" origin && git config "branch.$src.merge" "refs/heads/$dst" \
      && git fetch --quiet origin "$dst:refs/remotes/origin/$dst" 2>/dev/null \
      || echo "⚠ pushed, but could not set upstream for $src" >&2
  done
fi
exit 0
