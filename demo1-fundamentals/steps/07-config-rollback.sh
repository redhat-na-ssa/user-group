#!/usr/bin/env bash
# Part 7 - Configuration change rolls out a new ReplicaSet; then roll back.
# Runs as user1.
#
# Usage: 07-config-rollback.sh [COLOR]    (default #0066cc)
DEMO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${DEMO_DIR}/../common/lib.sh"
source "${DEMO_DIR}/demo.env"
COLOR=${1:-#0066cc}
use_user "${EDIT_USER}"
oc project -q "${NS}" >/dev/null

run oc set env deployment/guestbook APP_COLOR="${COLOR}" APP_TITLE="Guestbook - config change"
run oc annotate deployment/guestbook --overwrite kubernetes.io/change-cause="config: APP_COLOR=${COLOR}"
wait_rollout deployment/guestbook "${NS}"
run oc rollout history deployment/guestbook
run oc rollout undo deployment/guestbook
wait_rollout deployment/guestbook "${NS}"
run oc set env deployment/guestbook --list | grep -E 'APP_|POSTGRES' || true
