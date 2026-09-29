#!/usr/bin/env bash
# Part 3 - CATCH-UP for the console's "Import from Git": creates the
# guestbook pipeline, image stream, deployment, service and route, runs the
# first pipeline build, then wires the database secret in. Runs as user1.
DEMO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${DEMO_DIR}/../common/lib.sh"
source "${DEMO_DIR}/demo.env"
use_user "${EDIT_USER}"
oc project -q "${NS}" >/dev/null

# The app needs the database from Part 1
oc get deployment/postgresql >/dev/null 2>&1 || "${DEMO_DIR}/steps/01-postgresql.sh"
run oc apply -f <(sed "s|\${GIT_REPO}|${GIT_REPO_URL}|g" "${DEMO_DIR}/manifests/guestbook-app.yaml")
if ! oc get deployment/guestbook -o jsonpath='{.spec.template.spec.containers[0].image}' | grep -q '@sha256'; then
  # First build: the image doesn't exist yet
  pr=$(oc create -o name -f - <<YAML
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: guestbook-
  labels: {tekton.dev/pipeline: guestbook}
spec:
  pipelineRef: {name: guestbook}
  workspaces:
    - name: workspace
      volumeClaimTemplate:
        spec:
          accessModes: [ReadWriteOnce]
          resources: {requests: {storage: 1Gi}}
YAML
)
  info "Started ${pr} - waiting for clone, build and deploy..."
  run oc wait --for=condition=Succeeded "${pr}" --timeout=15m
fi
run oc patch deployment/guestbook --patch-file="${DEMO_DIR}/manifests/guestbook-db-env.patch.yaml"
wait_rollout deployment/guestbook "${NS}"
url=$(route_url guestbook "${NS}")
wait_url "${url}"
echo
info "Open: ${url}"
