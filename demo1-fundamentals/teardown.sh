#!/usr/bin/env bash
# Delete everything for Demo 1 (the whole project). Use ./reset.sh instead
# if you just want to run the demo again.
#
# Usage: ./teardown.sh [--yes]
DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${DEMO_DIR}/../common/lib.sh"
source "${DEMO_DIR}/demo.env"

require_login admin
if [[ "${1:-}" != "--yes" ]]; then
  read -r -p "Delete project ${NS}, everything in it and the Gitea repo ${GITEA_ORG}/${GIT_REPO_NAME}? [y/N] " answer
  [[ "${answer}" =~ ^[Yy]$ ]] || die "Aborted"
fi
oc delete project "${NS}" --ignore-not-found
oc delete clusterrolebinding "${NS}-pipeline-triggers" --ignore-not-found
if ( require_gitea ) >/dev/null 2>&1; then
  # Only an owner of the org may delete its repos (GITEA_USER must be in the
  # org's Owners team) - say so instead of failing silently
  if ! gitea_api GET "/repos/${GITEA_ORG}/${GIT_REPO_NAME}" >/dev/null; then
    ok "Gitea repo ${GITEA_ORG}/${GIT_REPO_NAME} already gone"
  elif gitea_api DELETE "/repos/${GITEA_ORG}/${GIT_REPO_NAME}" >/dev/null; then
    ok "Deleted Gitea repo ${GITEA_ORG}/${GIT_REPO_NAME}"
  else
    warn "Could not delete ${GITEA_ORG}/${GIT_REPO_NAME} as ${GITEA_USER} (not an owner of ${GITEA_ORG}?) - ./setup.sh --reset-source restores v1.0"
  fi
else
  warn "Gitea not reachable - delete ${GITEA_ORG}/${GIT_REPO_NAME} by hand"
fi
sed -i 's/^VERSION = .*/VERSION = "1.0"/' "${DEMO_DIR}/app/app.py"
ok "Demo 1 removed (the project takes a minute to finish terminating)"
