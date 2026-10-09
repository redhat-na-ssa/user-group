#!/usr/bin/env bash
# Part 2 - A bare pod: create it, look inside, delete it, see that nothing
# brings it back. In the demo this is done in the console (Import YAML);
# this is the CLI equivalent. Runs as the developer (user1).
DEMO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${DEMO_DIR}/../common/lib.sh"
source "${DEMO_DIR}/demo.env"
use_user "${EDIT_USER}"
oc project -q "${NS}" >/dev/null

run oc apply -f "${DEMO_DIR}/manifests/hello-pod.yaml"
run oc wait --for=condition=Ready pod/hello --timeout=90s
run oc get pod hello -o wide
run oc exec hello -- ps -ef   # PID 1 is the app, running as a random UID
# The Service from another pod: the name resolves to its stable 172.30 address
oc get service/postgresql >/dev/null 2>&1 && run oc exec hello -- getent hosts postgresql
run oc delete pod hello
run oc get pods               # gone for good - nothing is managing it
