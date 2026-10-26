# shellcheck shell=bash
# Cluster-wide settings shared by all demos. Override any value by exporting
# it before running a script, e.g.  GITEA_USER=someone ./setup.sh

# The cluster is the one `oc` is logged in to: nothing here names a cluster.
# The apps domain comes from the cluster ingress config (needs cluster-admin),
# else from the console URL (any user).
: "${OCP_API:=$(oc whoami --show-server 2>/dev/null)}"
: "${OCP_CONSOLE:=$(oc whoami --show-console 2>/dev/null)}"
: "${OCP_APPS_DOMAIN:=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)}"
: "${OCP_APPS_DOMAIN:=${OCP_CONSOLE#https://*.}}"

# Gitea on the cluster (namespace gitea) - holds the demo source repos
: "${GITEA_URL:=https://local-gitea-gitea.${OCP_APPS_DOMAIN}}"
: "${GITEA_INTERNAL_URL:=http://local-gitea.gitea.svc:3000}"
: "${GITEA_USER:=demo}"
: "${GITEA_PASSWORD:=welcome1}"
: "${GITEA_ORG:=ocpdemo}"

# Non-privileged demo users user1..user10
: "${DEMO_USER_PASSWORD:=welcome1}"
# Where per-user kubeconfigs are kept (see login_user in lib.sh)
: "${DEMO_KUBECONFIG_DIR:=${HOME}/.kube/demo-users}"
# Presenter terminal workspaces, one per demo (see workspace.sh)
: "${DEMO_WORKSPACE_DIR:=${HOME}/faa-demo}"
# Extra flags for oc login, e.g. "--insecure-skip-tls-verify=true"
: "${OCP_LOGIN_FLAGS:=}"

# Images from the cluster's internal registry (openshift namespace)
: "${INTERNAL_REGISTRY:=image-registry.openshift-image-registry.svc:5000}"
