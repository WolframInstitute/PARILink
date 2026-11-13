#!/bin/sh
# Print the ID of the CI run on main for a commit:
#
#   scripts/find-ci-run.sh COMMIT
#
# The Release workflow waits for this run to pass and publishes the archive that it built.
# GitHub can list a run some time after it starts or finishes, so while no run is listed the
# lookup is tried again every CI_RUN_WAIT seconds, CI_RUN_TRIES times in all: by default 10
# tries 30 seconds apart, about five minutes. A failed gh command counts as no run, and its
# message stays in the log.
set -eu

usage() {
    echo "usage: scripts/find-ci-run.sh COMMIT, with CI_RUN_TRIES a positive whole number and CI_RUN_WAIT a whole number of seconds" >&2
    exit 2
}

[ "$#" -eq 1 ] && [ -n "$1" ] || usage
commit=$1
tries=${CI_RUN_TRIES:-10}
wait_seconds=${CI_RUN_WAIT:-30}
case "$tries" in
    '' | *[!0-9]*) usage ;;
esac
case "$wait_seconds" in
    '' | *[!0-9]*) usage ;;
esac
[ "$tries" -ge 1 ] || usage

try=1
while :; do
    # A push to main, or a run started by hand on main, builds the archive of the commit.
    run=$(gh run list --workflow ci.yml --branch main --commit "$commit" \
        --limit 20 --json databaseId,event \
        --jq '[.[] | select(.event == "push" or .event == "workflow_dispatch")][0].databaseId') || run=
    case "$run" in
        '' | *[!0-9]*) ;;
        *)
            printf '%s\n' "$run"
            exit 0
            ;;
    esac
    [ "$try" -lt "$tries" ] || break
    echo "find-ci-run: no CI run on main is listed for $commit yet; looking again in $wait_seconds seconds." >&2
    sleep "$wait_seconds"
    try=$((try + 1))
done

echo "find-ci-run: no CI run on main was found for $commit after $tries tries." >&2
exit 1
