#!/usr/bin/env bash
# Part 4 - Self-healing, health probes, scaling and autoscaling. Runs as user1, then
# shows that user2 (view) is not allowed to scale.
DEMO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${DEMO_DIR}/../common/lib.sh"
source "${DEMO_DIR}/demo.env"
use_user "${EDIT_USER}"
oc project -q "${NS}" >/dev/null

run oc set probe deployment/guestbook --readiness --get-url=http://:8080/readyz --period-seconds=5
run oc set probe deployment/guestbook --liveness  --get-url=http://:8080/healthz --initial-delay-seconds=10
run oc annotate deployment/guestbook --overwrite kubernetes.io/change-cause="added health probes"
wait_rollout deployment/guestbook "${NS}"

pod=$(oc get pods -l deployment=guestbook -o name | head -1)
run oc delete "${pod}"
run oc get pods -l deployment=guestbook   # a replacement is already starting

run oc scale deployment/guestbook --replicas=3
wait_rollout deployment/guestbook "${NS}"
run oc get pods -l deployment=guestbook -o wide
run oc get endpointslices -l kubernetes.io/service-name=guestbook

# Routes are sticky by default (cookie) - switch to round robin so a browser
# refresh visibly lands on different pods
run oc patch route/guestbook --patch-file="${DEMO_DIR}/manifests/guestbook-route-roundrobin.patch.yaml"
sleep 3   # give the router a moment to reload
url=$(route_url guestbook "${NS}")
info "Requests are spread across the pods:"
for i in 1 2 3 4 5 6; do curl -ks "${url}/healthz"; done

# Autoscaling: the HPA needs a CPU request to measure against
run oc set resources deployment/guestbook --requests=cpu=50m,memory=320Mi --limits=memory=512Mi
wait_rollout deployment/guestbook "${NS}"
run oc apply -f "${DEMO_DIR}/manifests/guestbook-hpa.yaml"
info "Generate load from the laptop to see it scale (2 -> 6 pods):"
echo "  ab -k -c 10 -t 120 ${url}/"

echo
info "Now as ${VIEW_USER} (view role):"
use_user "${VIEW_USER}"
run oc get pods -n "${NS}"
run oc scale deployment/guestbook --replicas=1 -n "${NS}" || true
