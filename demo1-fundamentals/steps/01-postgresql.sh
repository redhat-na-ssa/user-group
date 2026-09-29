#!/usr/bin/env bash
# Part 1 - "It's this simple": deploy PostgreSQL from the project's template
# (the console's +Add -> Developer Catalog -> Databases -> PostgreSQL).
# Creates a Deployment, Service, Secret (generated credentials) and PVC.
# Runs as user1.
DEMO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${DEMO_DIR}/../common/lib.sh"
source "${DEMO_DIR}/demo.env"
use_user "${EDIT_USER}"
oc project -q "${NS}" >/dev/null

if ! oc get deployment/postgresql >/dev/null 2>&1; then
  echo "\$ oc process postgresql-demo | oc apply -f -"
  oc process postgresql-demo | oc apply -f -
fi
wait_rollout deployment/postgresql "${NS}"
run oc get deployment,service,secret,pvc -l template=postgresql-demo
