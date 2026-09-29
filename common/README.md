# common/

Shared by all demos.

| File | Purpose |
|---|---|
| `env.sh` | Cluster-wide settings: API and console URLs, Gitea (URL, user, org), registry host, the demo user password, and where per-user kubeconfigs are kept. Override any value with an environment variable. |
| `lib.sh` | Helpers for demo scripts: logging, `require_login [admin]`, `ensure_project`, `grant_role` (idempotent), `login_user` and `use_user` (one kubeconfig per user), `wait_rollout`, `wait_url`, `route_url`, `run` (echo a command, then run it), and Gitea helpers (`gitea_api`, `require_gitea`, `gitea_ensure_repo`, `gitea_push_dir`, `gitea_ensure_webhook`, `gitea_delete_webhooks`). |
| `login-users.sh` | `./login-users.sh user1 user2`: logs each user into `~/.kube/demo-users/<user>.kubeconfig`, so each terminal can act as a different user. |

A demo script starts with:

```bash
DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${DEMO_DIR}/../common/lib.sh"
source "${DEMO_DIR}/demo.env"
```

Conventions for each demo directory: `setup.sh`, `verify.sh`, `reset.sh`, `teardown.sh`, `DEMO-SCRIPT.md`, and `steps/NN-*.sh` catch-up scripts.
