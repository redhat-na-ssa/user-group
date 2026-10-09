#!/usr/bin/env bash
# Pre-flight check for Demo 1 - run this 10 minutes before presenting.
# Does not change anything (except refreshing the demo users' logins).
DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${DEMO_DIR}/../common/lib.sh"
source "${DEMO_DIR}/demo.env"
set +e   # report every problem, not just the first

FAIL=0
check() { # check "description" command...
  local desc=$1; shift
  if ( "$@" ) >/dev/null 2>&1; then ok "${desc}"; else warn "FAIL: ${desc}"; FAIL=1; fi
}
not() { ! "$@"; }
repo_at_v1() {
  curl -sf "${GITEA_URL}/${GITEA_ORG}/${GIT_REPO_NAME}/raw/branch/main/app.py" | grep -q '^VERSION = "1.0"'
}
# OpenShift Virtualization's console plugin takes over every Template page
# (list, details and Search) and shows only VM templates
kubevirt_plugin_enabled() {
  oc get consoles.operator.openshift.io cluster -o json \
    | jq -e '(.spec.plugins // []) | index("kubevirt-plugin") != null'
}
has_webhook() {
  gitea_api GET "/repos/${GITEA_ORG}/${GIT_REPO_NAME}/hooks" \
    | jq -e --arg u "${EL_URL}" 'any(.[]; .config.url==$u and .active)'
}

require_login admin

info "Cluster and Gitea"
check "Console reachable"                 curl -ksf -o /dev/null "${OCP_CONSOLE}"
check "Project ${NS} exists"              oc get project "${NS}"
check "Gitea login as ${GITEA_USER}"      gitea_api GET /user
check "Python 3.12 builder image exists"  oc get istag python:3.12-ubi9 -n openshift
check "kubevirt console plugin disabled (Template pages work)" not kubevirt_plugin_enabled

info "RBAC"
check "${EDIT_USER} can create deployments"   oc auth can-i create deployments -n "${NS}" --as="${EDIT_USER}"
check "${EDIT_USER} can create pipelines"     oc auth can-i create pipelines.tekton.dev -n "${NS}" --as="${EDIT_USER}"
check "${EDIT_USER} can instantiate templates" oc auth can-i create templateinstances.template.openshift.io -n "${NS}" --as="${EDIT_USER}"
check "${EDIT_USER} cannot manage RBAC"   not oc auth can-i create rolebindings -n "${NS}" --as="${EDIT_USER}"
check "${VIEW_USER} can list pods"        oc auth can-i list pods -n "${NS}" --as="${VIEW_USER}"
check "${VIEW_USER} cannot scale"         not oc auth can-i patch deployments/scale -n "${NS}" --as="${VIEW_USER}"
check "${VIEW_USER} cannot read secrets"  not oc auth can-i get secrets -n "${NS}" --as="${VIEW_USER}"

info "Demo user logins (password '${DEMO_USER_PASSWORD}')"
for u in "${EDIT_USER}" "${VIEW_USER}"; do
  check "${u} can log in" login_user "${u}"
done

info "Starting state"
check "PostgreSQL template is staged"     oc get template.template.openshift.io/postgresql-demo -n "${NS}"
check "PostgreSQL 15 image exists"        oc get istag postgresql:15-el9 -n openshift
check "No database yet (Part 1)"          not oc get deployment/postgresql -n "${NS}"
check "No leftover database secret"       not oc get secret/postgresql -n "${NS}"
check "Repo ${GITEA_ORG}/${GIT_REPO_NAME} is at VERSION 1.0"  repo_at_v1
check "Repo webhook points at ${EL_URL}"  has_webhook
check "Trigger template is staged"        oc get triggertemplate.triggers.tekton.dev/guestbook -n "${NS}"
check "No EventListener yet (Part 6)"     not oc get eventlistener.triggers.tekton.dev/guestbook -n "${NS}"
check "app/app.py is at VERSION 1.0"      grep -q '^VERSION = "1.0"' "${DEMO_DIR}/app/app.py"
check "No guestbook deployment yet"       not oc get deployment/guestbook -n "${NS}"
check "No guestbook pipeline yet"         not oc get pipeline.tekton.dev/guestbook -n "${NS}"
check "No guestbook pipeline runs yet"    test -z "$(oc get pipelinerun.tekton.dev -n "${NS}" -l tekton.dev/pipeline=guestbook -o name)"
check "No leftover hello pod"             not oc get pod/hello -n "${NS}"

echo
if ((FAIL)); then die "Some checks failed - try ./reset.sh (or ./setup.sh)"; fi
ok "All good - ready to present Demo 1"
