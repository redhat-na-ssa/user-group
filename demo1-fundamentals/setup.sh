#!/usr/bin/env bash
# Prepare the cluster for Demo 1 (OpenShift fundamentals). Safe to re-run.
#
# End state ("ready to present"):
#   * project demo-intro, peter=admin, user1=edit, user2=view
#   * PostgreSQL running (the "platform team" provided database)
#   * Gitea repo ocpdemo/guestbook holding the app source at VERSION 1.0
#   * push-to-deploy wiring: Gitea webhook -> EventListener -> TriggerTemplate
#     that runs the "guestbook" pipeline
#   * NO guestbook app or pipeline - the presenter creates them live with
#     the console's Import from Git
#   * per-user kubeconfigs for user1/user2 in ~/.kube/demo-users
#
# Usage: ./setup.sh [--reset-source]   --reset-source force-pushes app/ to
#                                      Gitea even if the repo has content
DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${DEMO_DIR}/../common/lib.sh"
source "${DEMO_DIR}/demo.env"

RESET_SOURCE=false
[[ "${1:-}" == "--reset-source" ]] && RESET_SOURCE=true

require_login admin
require_gitea

info "Project and RBAC"
ensure_project "${NS}" "${NS_DISPLAY}" "${NS_DESCRIPTION}"
grant_role admin "${ADMIN_USER}" "${NS}"
grant_role edit  "${EDIT_USER}"  "${NS}"
grant_role view  "${VIEW_USER}"  "${NS}"

info "Database"
if oc get secret guestbook-db -n "${NS}" >/dev/null 2>&1; then
  ok "Secret guestbook-db exists"
else
  oc create secret generic guestbook-db -n "${NS}" \
    --from-literal=POSTGRESQL_USER=guestbook \
    --from-literal=POSTGRESQL_PASSWORD="$(openssl rand -hex 12)" \
    --from-literal=POSTGRESQL_DATABASE=guestbook >/dev/null
  oc label secret guestbook-db -n "${NS}" app.kubernetes.io/part-of=guestbook >/dev/null
  ok "Created secret guestbook-db"
fi
oc apply -n "${NS}" -f "${DEMO_DIR}/manifests/database.yaml" >/dev/null
wait_rollout deployment/postgresql "${NS}"

info "Source repository"
gitea_ensure_repo "${GIT_REPO_NAME}" "Guestbook - OpenShift fundamentals demo"
if ${RESET_SOURCE} || [[ "$(gitea_api GET "/repos/${GITEA_ORG}/${GIT_REPO_NAME}" | jq -r .empty)" == "true" ]]; then
  grep -q '^VERSION = "1.0"' "${DEMO_DIR}/app/app.py" \
    || die "app/app.py is not at VERSION 1.0"
  # No webhook while (re)writing history, so this push doesn't start a build
  gitea_delete_webhooks "${GIT_REPO_NAME}"
  gitea_push_dir "${DEMO_DIR}/app" "${GIT_REPO_NAME}" "Guestbook v1.0"
else
  ok "Repo already has content (use --reset-source to overwrite)"
fi

info "Pipeline trigger"
if oc get secret guestbook-webhook -n "${NS}" >/dev/null 2>&1; then
  ok "Secret guestbook-webhook exists"
else
  oc create secret generic guestbook-webhook -n "${NS}" \
    --from-literal=secret="$(openssl rand -hex 16)" >/dev/null
  ok "Created secret guestbook-webhook"
fi
# EventListener service account: read trigger resources, create PipelineRuns
oc create rolebinding pipeline-triggers -n "${NS}" \
  --clusterrole=tekton-triggers-eventlistener-roles --serviceaccount="${NS}:pipeline" \
  --dry-run=client -o yaml | oc apply -f - >/dev/null
oc create clusterrolebinding "${NS}-pipeline-triggers" \
  --clusterrole=tekton-triggers-eventlistener-clusterroles --serviceaccount="${NS}:pipeline" \
  --dry-run=client -o yaml | oc apply -f - >/dev/null
oc apply -n "${NS}" -f "${DEMO_DIR}/manifests/pipeline-trigger.yaml" >/dev/null
for _ in {1..30}; do oc get deployment/el-guestbook -n "${NS}" >/dev/null 2>&1 && break; sleep 2; done
wait_rollout deployment/el-guestbook "${NS}"
gitea_ensure_webhook "${GIT_REPO_NAME}" "${EL_URL}" \
  "$(oc get secret guestbook-webhook -n "${NS}" -o jsonpath='{.data.secret}' | base64 -d)"
if ! oc get pipeline.tekton.dev/guestbook -n "${NS}" >/dev/null 2>&1; then
  # Gitea processes pushes asynchronously, so the push above can still reach
  # the webhook and start a run of the not-yet-existing pipeline. Remove it.
  sleep 10
  oc delete -n "${NS}" --ignore-not-found pipelinerun.tekton.dev -l tekton.dev/pipeline=guestbook >/dev/null
fi

info "Demo user sessions"
for u in "${EDIT_USER}" "${VIEW_USER}"; do
  ( login_user "${u}" ) || warn "Could not log in as ${u} with DEMO_USER_PASSWORD - check the htpasswd provider"
done

echo
ok "Demo 1 is ready. Run ./verify.sh right before presenting."
cat <<EOF

  Console:   ${OCP_CONSOLE}/topology/ns/${NS}
  Git repo:  ${GIT_REPO_WEB_URL}
  Clone URL: ${GIT_REPO_URL}  (use this in Import from Git)
  ${EDIT_USER} terminal:  export KUBECONFIG=$(user_kubeconfig "${EDIT_USER}")
  ${VIEW_USER} terminal:  export KUBECONFIG=$(user_kubeconfig "${VIEW_USER}")
EOF
