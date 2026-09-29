#!/usr/bin/env bash
# Part 1 - Projects & RBAC (run as the admin, peter). Read-only: shows who
# can do what in the project.
DEMO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${DEMO_DIR}/../common/lib.sh"
source "${DEMO_DIR}/demo.env"

run oc get project "${NS}"
run oc get rolebindings -n "${NS}" -o wide
echo
for u in "${EDIT_USER}" "${VIEW_USER}"; do
  for verb in "get pods" "create deployments" "get secrets" "create rolebindings"; do
    printf '%-6s %-20s -> ' "$u" "$verb"
    oc auth can-i $verb -n "${NS}" --as="$u" || true
  done
done
