# shellcheck shell=bash
# Cluster-wide settings shared by all demos. Override any value by exporting
# it before running a script, e.g.  OCP_API=https://... ./setup.sh

: "${OCP_API:=https://api.homeocp.ocp4.peterlarsen.org:6443}"
: "${OCP_CONSOLE:=https://console-openshift-console.apps.homeocp.ocp4.peterlarsen.org}"
: "${OCP_APPS_DOMAIN:=apps.homeocp.ocp4.peterlarsen.org}"
: "${GIT_SERVER:=https://gitlab.peterlarsen.org}"
: "${CONTAINER_REGISTRY:=quay2.peterlarsen.org}"

# Gitea on the cluster (namespace gitea) - holds the demo source repos
: "${GITEA_URL:=https://local-gitea-gitea.apps.homeocp.ocp4.peterlarsen.org}"
: "${GITEA_INTERNAL_URL:=http://local-gitea.gitea.svc:3000}"
: "${GITEA_USER:=demo}"
: "${GITEA_PASSWORD:=welcome1}"
: "${GITEA_ORG:=ocpdemo}"

# Non-privileged demo users user1..user10
: "${DEMO_USER_PASSWORD:=welcome1}"
# Where per-user kubeconfigs are kept (see login_user in lib.sh)
: "${DEMO_KUBECONFIG_DIR:=${HOME}/.kube/demo-users}"
# Extra flags for oc login, e.g. "--insecure-skip-tls-verify=true"
: "${OCP_LOGIN_FLAGS:=}"

# Images from the cluster's internal registry (openshift namespace)
: "${INTERNAL_REGISTRY:=image-registry.openshift-image-registry.svc:5000}"
