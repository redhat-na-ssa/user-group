#!/usr/bin/env bash
# Part 6 - Ship v2: create the EventListener (Import YAML in the console),
# then commit a change to app.py in Gitea (what the presenter does in Gitea's
# web editor). The webhook starts the pipeline, which builds
# a new image; the image change rolls out the Deployment. Runs as user1.
#
# Usage: 06-new-version.sh [VERSION]    (default 2.0)
DEMO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "${DEMO_DIR}/../common/lib.sh"
source "${DEMO_DIR}/demo.env"
NEW_VERSION=${1:-2.0}
use_user "${EDIT_USER}"
oc project -q "${NS}" >/dev/null

if ! oc get eventlistener.triggers.tekton.dev/guestbook >/dev/null 2>&1; then
  run oc apply -f "${DEMO_DIR}/manifests/guestbook-eventlistener.yaml"
  for _ in {1..30}; do oc get deployment/el-guestbook >/dev/null 2>&1 && break; sleep 2; done
  wait_rollout deployment/el-guestbook "${NS}"
fi

info "Committing VERSION = \"${NEW_VERSION}\" to ${GITEA_ORG}/${GIT_REPO_NAME} (app.py)"
file=$(gitea_api GET "/repos/${GITEA_ORG}/${GIT_REPO_NAME}/contents/app.py")
content=$(jq -r .content <<<"${file}" | base64 -d \
  | sed "s/^VERSION = .*/VERSION = \"${NEW_VERSION}\"/" | base64 -w0)
before=$(oc get pipelinerun -l tekton.dev/pipeline=guestbook -o name | sort)
gitea_api PUT "/repos/${GITEA_ORG}/${GIT_REPO_NAME}/contents/app.py" \
  "$(jq -nc --arg c "${content}" --arg s "$(jq -r .sha <<<"${file}")" --arg v "${NEW_VERSION}" \
     '{content:$c, sha:$s, branch:"main", message:("Release v"+$v)}')" >/dev/null \
  || die "Commit failed"
ok "Committed"

info "Waiting for the webhook to start a pipeline run..."
pr=
for _ in {1..30}; do
  pr=$(comm -13 <(echo "${before}") <(oc get pipelinerun -l tekton.dev/pipeline=guestbook -o name | sort) | head -1)
  [[ -n "${pr}" ]] && break
  sleep 2
done
[[ -n "${pr}" ]] || die "No pipeline run started - check the webhook (Gitea repo Settings -> Webhooks) and: oc logs deploy/el-guestbook"
ok "Started ${pr}"
run oc wait --for=condition=Succeeded "${pr}" --timeout=15m
wait_rollout deployment/guestbook "${NS}"
run oc annotate deployment/guestbook --overwrite kubernetes.io/change-cause="pipeline: v${NEW_VERSION}"
run curl -ks "$(route_url guestbook "${NS}")/healthz"
