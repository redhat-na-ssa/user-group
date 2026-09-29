#!/usr/bin/env bash
# Put Demo 1 back to its starting state after a run (or a rehearsal):
# removes everything created live (database, app, pipeline, runs, event
# listener, hello pod) and resets the Gitea repo to the v1.0 source.
# Keeps the project, RBAC and what setup.sh staged (database template,
# trigger binding/template, webhook).
DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${DEMO_DIR}/../common/lib.sh"
source "${DEMO_DIR}/demo.env"

require_login admin
require_gitea
oc get project "${NS}" >/dev/null 2>&1 || die "Project ${NS} missing - run ./setup.sh"

info "Removing resources created during the demo"
# By name, plus by the labels the console's Import from Git puts on things
oc delete -n "${NS}" --ignore-not-found \
  deployment/guestbook service/guestbook route/guestbook imagestream/guestbook \
  pipeline.tekton.dev/guestbook pod/hello eventlistener.triggers.tekton.dev/guestbook
oc delete -n "${NS}" --ignore-not-found \
  deployment,service,route,imagestream,pipeline.tekton.dev,secret \
  -l 'app.kubernetes.io/instance=guestbook'
# The database from the postgresql-demo template (Part 1). Instantiating it in
# the console also creates a TemplateInstance and a "-parameters" Secret.
oc delete -n "${NS}" --ignore-not-found templateinstance.template.openshift.io --all
oc get secret -n "${NS}" -o name | { grep '^secret/postgresql-demo-parameters' || true; } \
  | xargs -r oc delete -n "${NS}" --ignore-not-found
# ...its objects by label, plus the
# pre-staged database of older versions of this demo
oc delete -n "${NS}" --ignore-not-found \
  deployment,service,secret,persistentvolumeclaim -l template=postgresql-demo
oc delete -n "${NS}" --ignore-not-found \
  deployment/postgresql service/postgresql secret/postgresql secret/guestbook-db \
  persistentvolumeclaim/postgresql persistentvolumeclaim/postgresql-data
oc delete -n "${NS}" --ignore-not-found pipelinerun.tekton.dev -l tekton.dev/pipeline=guestbook
oc wait -n "${NS}" --for=delete pod -l 'app in (guestbook,postgresql)' --timeout=60s 2>/dev/null || true
oc wait -n "${NS}" --for=delete pod/hello --timeout=60s 2>/dev/null || true

info "Resetting the Git repo to v1.0"
sed -i 's/^VERSION = .*/VERSION = "1.0"/' "${DEMO_DIR}/app/app.py"
# Drop the webhook while rewriting history so the push doesn't start a build
gitea_delete_webhooks "${GIT_REPO_NAME}"
gitea_push_dir "${DEMO_DIR}/app" "${GIT_REPO_NAME}" "Guestbook v1.0"
gitea_ensure_webhook "${GIT_REPO_NAME}" "${EL_URL}" \
  "$(oc get secret guestbook-webhook -n "${NS}" -o jsonpath='{.data.secret}' | base64 -d)"

# Gitea processes pushes asynchronously, so the push above can still reach
# the webhook and start a run of the not-yet-existing pipeline. Remove it.
sleep 10
oc delete -n "${NS}" --ignore-not-found pipelinerun.tekton.dev -l tekton.dev/pipeline=guestbook >/dev/null

echo
ok "Reset done. Run ./verify.sh to double-check."
