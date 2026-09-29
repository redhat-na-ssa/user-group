# shellcheck shell=bash
# Shared helpers for demo setup/reset/teardown scripts.
# Source from a demo script:  source "$(dirname "$0")/../common/lib.sh"

set -euo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=env.sh
source "${COMMON_DIR}/env.sh"

# ---------------------------------------------------------------- logging
if [[ -t 1 ]]; then
  _C_INFO=$'\e[1;34m'; _C_OK=$'\e[1;32m'; _C_WARN=$'\e[1;33m'; _C_ERR=$'\e[1;31m'; _C_OFF=$'\e[0m'
else
  _C_INFO=; _C_OK=; _C_WARN=; _C_ERR=; _C_OFF=
fi
info() { echo "${_C_INFO}==>${_C_OFF} $*"; }
ok()   { echo "${_C_OK} ✔${_C_OFF}  $*"; }
warn() { echo "${_C_WARN} !${_C_OFF}  $*" >&2; }
die()  { echo "${_C_ERR} ✘${_C_OFF}  $*" >&2; exit 1; }

# ---------------------------------------------------------------- preflight
# Require an oc session against the expected cluster. Pass "admin" to also
# require cluster-admin rights.
require_login() {
  command -v oc >/dev/null || die "oc not found in PATH"
  local server
  server=$(oc whoami --show-server 2>/dev/null) || die "Not logged in. Run: oc login ${OCP_API}"
  [[ "${server}" == "${OCP_API}" ]] \
    || warn "Logged in to ${server}, expected ${OCP_API}"
  if [[ "${1:-}" == "admin" ]]; then
    oc auth can-i '*' '*' --all-namespaces >/dev/null 2>&1 \
      || die "User $(oc whoami) is not cluster-admin"
  fi
  ok "Logged in as $(oc whoami) on ${server}"
}

# ---------------------------------------------------------------- projects / RBAC
# ensure_project NAME [DISPLAY_NAME] [DESCRIPTION]
ensure_project() {
  local ns=$1 display=${2:-} desc=${3:-}
  if oc get project "${ns}" >/dev/null 2>&1; then
    ok "Project ${ns} exists"
  else
    oc new-project "${ns}" --display-name="${display}" --description="${desc}" >/dev/null
    ok "Created project ${ns}"
  fi
  # new-project switches context; always leave the caller pointed at ns
  oc project "${ns}" >/dev/null
}

# grant_role ROLE USER NAMESPACE   (idempotent)
grant_role() {
  local role=$1 user=$2 ns=$3
  if oc get rolebindings -n "${ns}" -o json \
      | jq -e --arg r "${role}" --arg u "${user}" \
        '.items[] | select(.roleRef.name==$r) | .subjects[]? | select(.kind=="User" and .name==$u)' >/dev/null; then
    ok "${user} already has ${role} in ${ns}"
  else
    oc adm policy add-role-to-user "${role}" "${user}" -n "${ns}" >/dev/null
    ok "Granted ${role} to ${user} in ${ns}"
  fi
}

# ---------------------------------------------------------------- per-user sessions
# Each demo user gets its own kubeconfig so several identities can be used
# side by side in different terminals without logging each other out.
#   user_kubeconfig user1   -> prints path
#   login_user user1        -> logs in (password from DEMO_USER_PASSWORD)
user_kubeconfig() { echo "${DEMO_KUBECONFIG_DIR}/$1.kubeconfig"; }

login_user() {
  local user=$1 kc
  kc=$(user_kubeconfig "${user}")
  mkdir -p "${DEMO_KUBECONFIG_DIR}"
  KUBECONFIG="${kc}" oc login "${OCP_API}" -u "${user}" -p "${DEMO_USER_PASSWORD}" \
    ${OCP_LOGIN_FLAGS} >/dev/null \
    || die "Login failed for ${user}"
  ok "${user} logged in (KUBECONFIG=${kc})"
}

# ---------------------------------------------------------------- waiting
# wait_rollout KIND/NAME NAMESPACE [TIMEOUT]
wait_rollout() {
  local res=$1 ns=$2 timeout=${3:-300s}
  info "Waiting for ${res} rollout..."
  oc rollout status "${res}" -n "${ns}" --timeout="${timeout}" >/dev/null
  ok "${res} is ready"
}

# wait_url URL [TRIES]  - wait for HTTP 200 from a route
wait_url() {
  local url=$1 tries=${2:-30} i
  for ((i = 0; i < tries; i++)); do
    if curl -ksf -o /dev/null "${url}"; then ok "${url} responds"; return 0; fi
    sleep 2
  done
  die "${url} did not respond"
}

route_url() { # route_url NAME NAMESPACE
  echo "https://$(oc get route "$1" -n "$2" -o jsonpath='{.spec.host}')"
}

# ---------------------------------------------------------------- live demo
# run CMD...  - show the command the way the audience should see it, then run it
run() {
  local a out=
  for a in "$@"; do [[ "$a" =~ [[:space:]] ]] && a="\"$a\""; out+=" $a"; done
  echo "${_C_OK}\$${_C_OFF}${out}"
  "$@"
}

# use_user USER - point this shell at USER's kubeconfig (login if needed)
use_user() {
  local kc
  kc=$(user_kubeconfig "$1")
  if ! KUBECONFIG="${kc}" oc whoami >/dev/null 2>&1; then login_user "$1"; fi
  export KUBECONFIG="${kc}"
  ok "Acting as $(oc whoami)"
}

# ---------------------------------------------------------------- gitea
# gitea_api METHOD PATH [JSON]  - call the Gitea REST API as GITEA_USER
gitea_api() {
  local method=$1 path=$2 data=${3:-}
  curl -sf -u "${GITEA_USER}:${GITEA_PASSWORD}" -X "${method}" \
    -H 'Content-Type: application/json' ${data:+-d "${data}"} \
    "${GITEA_URL}/api/v1${path}"
}

require_gitea() {
  gitea_api GET /user >/dev/null \
    || die "Cannot log in to ${GITEA_URL} as ${GITEA_USER} - check GITEA_PASSWORD in common/env.sh"
  ok "Gitea: logged in as ${GITEA_USER}"
}

# gitea_ensure_repo NAME DESCRIPTION  - public repo in GITEA_ORG
gitea_ensure_repo() {
  local name=$1 desc=$2
  if gitea_api GET "/repos/${GITEA_ORG}/${name}" >/dev/null; then
    ok "Gitea repo ${GITEA_ORG}/${name} exists"
  else
    gitea_api POST "/orgs/${GITEA_ORG}/repos" \
      "$(jq -nc --arg n "${name}" --arg d "${desc}" \
         '{name:$n, description:$d, private:false, default_branch:"main"}')" >/dev/null \
      || die "Could not create repo ${GITEA_ORG}/${name}"
    ok "Created Gitea repo ${GITEA_ORG}/${name}"
  fi
}

# gitea_push_dir DIR REPO MESSAGE  - make DIR the entire content of REPO's
# main branch as a single commit (force push). Used to (re)set demo sources.
gitea_push_dir() {
  local dir=$1 repo=$2 msg=$3 tmp
  tmp=$(mktemp -d)
  cp -a "${dir}/." "${tmp}/"
  (
    cd "${tmp}"
    git init -q -b main
    git -c user.name="${GITEA_USER}" -c user.email="${GITEA_USER}@example.com" add -A
    git -c user.name="${GITEA_USER}" -c user.email="${GITEA_USER}@example.com" commit -qm "${msg}"
    git -c credential.helper= push -qf \
      "https://${GITEA_USER}:${GITEA_PASSWORD}@${GITEA_URL#https://}/${GITEA_ORG}/${repo}.git" main
  ) || { rm -rf "${tmp}"; die "Push to ${GITEA_ORG}/${repo} failed"; }
  rm -rf "${tmp}"
  ok "Pushed ${dir} to ${GITEA_ORG}/${repo} (main)"
}

# gitea_delete_webhooks REPO  - remove every webhook on REPO
gitea_delete_webhooks() {
  local repo=$1 id
  for id in $(gitea_api GET "/repos/${GITEA_ORG}/${repo}/hooks" | jq -r '.[].id'); do
    gitea_api DELETE "/repos/${GITEA_ORG}/${repo}/hooks/${id}" >/dev/null
  done
}

# gitea_ensure_webhook REPO URL SECRET  - push webhook (replaces any hook
# already pointing at URL, so the secret is always current)
gitea_ensure_webhook() {
  local repo=$1 url=$2 secret=$3 id
  for id in $(gitea_api GET "/repos/${GITEA_ORG}/${repo}/hooks" \
               | jq -r --arg u "${url}" '.[] | select(.config.url==$u) | .id'); do
    gitea_api DELETE "/repos/${GITEA_ORG}/${repo}/hooks/${id}" >/dev/null
  done
  gitea_api POST "/repos/${GITEA_ORG}/${repo}/hooks" \
    "$(jq -nc --arg u "${url}" --arg s "${secret}" \
       '{type:"gitea", active:true, events:["push"], branch_filter:"main",
         config:{url:$u, content_type:"json", secret:$s}}')" >/dev/null \
    || die "Could not create webhook on ${GITEA_ORG}/${repo}"
  ok "Webhook ${GITEA_ORG}/${repo} -> ${url}"
}
