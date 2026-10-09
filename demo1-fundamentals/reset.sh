#!/usr/bin/env bash
# Put Demo 1 back to its starting state after a run (or a rehearsal): deletes
# the whole project, waits until it is gone, then runs ./setup.sh
# --reset-source to rebuild it (RBAC, database template, trigger, webhook) and
# push the v1.0 source to Gitea. Deleting the namespace is the only reset that
# catches everything the console created live, whatever it was.
#
# The project and the Gitea repo come back; use ./teardown.sh to remove them
# for good. Takes a minute or two, mostly namespace termination.
DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${DEMO_DIR}/../common/lib.sh"
source "${DEMO_DIR}/demo.env"

require_login admin
require_gitea

sed -i 's/^VERSION = .*/VERSION = "1.0"/' "${DEMO_DIR}/app/app.py"

if oc get namespace "${NS}" >/dev/null 2>&1; then
  info "Deleting project ${NS}"
  oc delete project "${NS}" >/dev/null
  oc wait --for=delete "namespace/${NS}" --timeout=5m >/dev/null \
    || die "Project ${NS} is still terminating - check 'oc get namespace ${NS} -o yaml'"
  ok "Project ${NS} deleted"
fi

exec "${DEMO_DIR}/setup.sh" --reset-source
