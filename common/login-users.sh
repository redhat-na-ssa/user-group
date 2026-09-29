#!/usr/bin/env bash
# Log demo users in, each into its own kubeconfig, so you can keep one
# terminal per identity during a demo.
#
#   common/login-users.sh user1 user2
#   export KUBECONFIG=~/.kube/demo-users/user1.kubeconfig
source "$(dirname "$0")/lib.sh"

[[ $# -gt 0 ]] || die "usage: $0 USER [USER...]"
for u in "$@"; do login_user "$u"; done

echo
info "Use a user's session in a terminal with:"
for u in "$@"; do echo "    export KUBECONFIG=$(user_kubeconfig "$u")"; done
