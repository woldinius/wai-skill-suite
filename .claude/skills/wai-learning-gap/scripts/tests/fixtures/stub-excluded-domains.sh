#!/bin/sh
# A fake excluded-domains.sh for the rank-pr-candidates tests.
#
# rank-pr-candidates.sh classifies each PR by calling `excluded-domains.sh --pr <n>` and reading its
# exit code (0 clear / 1 excluded / 2 unknown). This stub returns a code per PR from a fixture file
# so the ranking logic can be exercised without the real classifier, gh, or a network.
set -u
PR=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --pr) PR="${2:-}"; shift 2 ;;
    *)    shift ;;
  esac
done
F="${EXD_FIXTURE:?EXD_FIXTURE not set}"
if [ -f "$F/pr$PR.rc" ]; then
  exit "$(cat "$F/pr$PR.rc")"
fi
exit 0
