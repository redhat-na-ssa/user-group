#!/usr/bin/env bash
# Build the presenter's terminal workspace for a demo, outside the repo:
#
#   ${DEMO_WORKSPACE_DIR}/<demo>/      (default ~/faa-demo/<demo>)
#     cheatsheet.sh + the demo's YAML files   copied from this working copy
#     <user>.kubeconfig                       one session per identity
#     <user>.rc                               start a terminal tab as that user
#
# Identities come from <demo>/demo.env: ADMIN_USER gets a copy of your current
# oc session (no password needed), EDIT_USER/VIEW_USER are logged in fresh.
# Run it shortly before presenting - user tokens expire (24h by default).
# Re-running refreshes everything; nothing in the workspace is precious.
#
#   common/workspace.sh demo1-fundamentals
#   bash --rcfile ~/faa-demo/demo1-fundamentals/user1.rc    # one per tab
source "$(dirname "$0")/lib.sh"

[[ $# -eq 1 ]] || die "usage: $0 <demo directory, e.g. demo1-fundamentals>"
DEMO=${1%/}
REPO="$(cd "${COMMON_DIR}/.." && pwd)"
DEMO_DIR="${REPO}/${DEMO}"
[[ -f "${DEMO_DIR}/demo.env" ]] || die "${DEMO_DIR}/demo.env not found"
source "${DEMO_DIR}/demo.env"
WS="${DEMO_WORKSPACE_DIR}/${DEMO}"

require_login admin
[[ "$(oc whoami)" == "${ADMIN_USER}" ]] \
  || warn "Logged in as $(oc whoami), not ${ADMIN_USER} - the ${ADMIN_USER} tab gets this session"

info "Workspace ${WS}"
mkdir -p "${WS}"
cp "${DEMO_DIR}/cheatsheet.sh" "${WS}/"
# The same files the web terminal downloads: the deck's "files" list in the
# faa-demo playbook
"${REPO}/.venv/bin/python" - "${REPO}" "${DEMO}" <<'EOF' | while read -r f; do cp "${DEMO_DIR}/${f}" "${WS}/"; done
import sys, yaml
repo, demo = sys.argv[1:]
decks = yaml.safe_load(open(f"{repo}/faa-demo/playbook.yml"))[0]["vars"]["decks"]
print("\n".join(next(d for d in decks if d["name"] == demo).get("files", [])))
EOF
ok "Copied cheatsheet.sh and the demo files"

info "Sessions"
oc config view --raw --minify > "${WS}/${ADMIN_USER}.kubeconfig"
chmod 600 "${WS}/${ADMIN_USER}.kubeconfig"
ok "${ADMIN_USER}: copy of the current session"
for u in "${EDIT_USER}" "${VIEW_USER}"; do
  DEMO_KUBECONFIG_DIR="${WS}" login_user "${u}"
done

for u in "${ADMIN_USER}" "${EDIT_USER}" "${VIEW_USER}"; do
  cat > "${WS}/${u}.rc" <<EOF
# Terminal tab for ${u} (written by common/workspace.sh).
#   bash --rcfile ${WS}/${u}.rc
[ -f ~/.bashrc ] && . ~/.bashrc
export KUBECONFIG=${WS}/${u}.kubeconfig
cd ${WS}
. ./cheatsheet.sh
# Prompt: [command number] live 'oc whoami' (follows any oc login/logout) dir $
__demo_whoami() { __demo_user=\$(oc whoami --request-timeout=3s 2>/dev/null) || __demo_user='(not logged in)'; }
PROMPT_COMMAND="__demo_whoami\${PROMPT_COMMAND:+; \$PROMPT_COMMAND}"
PS1='\[\e[2m\][\#]\[\e[0m\] \[\e[1;31m\]\${__demo_user}\[\e[0m\] \W \\$ '
EOF
done
ok "Wrote ${ADMIN_USER}.rc ${EDIT_USER}.rc ${VIEW_USER}.rc"

echo
info "One terminal tab per user:"
for u in "${ADMIN_USER}" "${EDIT_USER}" "${VIEW_USER}"; do
  echo "    bash --rcfile ${WS}/${u}.rc"
done
