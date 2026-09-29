#!/usr/bin/env bash
# Part 3a - "It's this simple": deploy an existing image (the console's
# +Add -> Container images). Runs as user1.
DEMO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${DEMO_DIR}/../common/lib.sh"
source "${DEMO_DIR}/demo.env"
use_user "${EDIT_USER}"
oc project -q "${NS}" >/dev/null

if ! oc get deployment/pacman >/dev/null 2>&1; then
  run oc new-app --image="${PACMAN_IMAGE}" --name=pacman \
        -l app.kubernetes.io/part-of=Games
fi
# new-app only creates a Service when the image declares its ports (EXPOSE)
oc get service pacman >/dev/null 2>&1 \
  || run oc expose deployment/pacman --port=8080
oc get route pacman >/dev/null 2>&1 \
  || run oc create route edge pacman --service=pacman
wait_rollout deployment/pacman "${NS}"
info "Open: $(route_url pacman "${NS}")"
