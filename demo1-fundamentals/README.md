# Demo 1 – OpenShift Fundamentals

"OpenShift architecture 1:1" slides, followed by a mostly console-driven demo that covers pods, Deployments, Services, Routes, Tekton pipelines from Git, push-to-deploy, scaling, config changes and project RBAC. The app is a small guestbook: a Python/Flask frontend and PostgreSQL.

The presenter's talk track is in **[DEMO-SCRIPT.md](DEMO-SCRIPT.md)**.

| | |
|---|---|
| Project | `demo-intro` |
| Admin | `peter` (runs setup) |
| Developer | `user1` – `edit` role, drives the demo in the console |
| Viewer | `user2` – `view` role |
| Source repo (browser) | `https://local-gitea-gitea.apps.homeocp.ocp4.peterlarsen.org/ocpdemo/guestbook` (Gitea user `demo`) |
| Clone URL (pipelines) | `http://local-gitea.gitea.svc:3000/ocpdemo/guestbook.git`: the in-cluster Service, so pipelines never depend on the ingress certificate |
| App URL (after Part 3) | `https://guestbook-demo-intro.apps.homeocp.ocp4.peterlarsen.org` |

## Lifecycle

```bash
oc login -u peter https://api.homeocp.ocp4.peterlarsen.org:6443
./setup.sh      # one time: project, RBAC, PostgreSQL, Gitea repo, pipeline trigger
./verify.sh     # pre-flight: run before every presentation
#   ... present ...
./reset.sh      # back to the start state (removes the app and pipeline, resets the repo to v1.0)
./teardown.sh   # delete the project and the Gitea repo
```

All scripts are safe to re-run. `setup.sh --reset-source` force-pushes `app/` to Gitea even if the repo already has commits.

### What setup prepares, and what gets created live

| Pre-staged by `setup.sh` | Created live in the console |
|---|---|
| Project and rolebindings | `hello` pod (Import YAML, then deleted) |
| | `pacman` from an existing image (`quay.io/plarsen/pacman`, +Add → Container images) |
| Secret `guestbook-db` (random password) | Import from Git: pipeline `guestbook`, ImageStream, Deployment, Service, Route |
| PostgreSQL Deployment, Service and 1Gi PVC | The first PipelineRun (clone → build → deploy) |
| Gitea repo `ocpdemo/guestbook` at v1.0 | The DB secret wired into the Deployment's environment |
| EventListener, TriggerBinding and TriggerTemplate `guestbook`, plus a webhook secret | Health checks, scaling, route annotations |
| Gitea webhook → `el-guestbook` (in-cluster service URL) | The v2.0 commit in Gitea → an automatic PipelineRun → rollout |
| Logins for user1 and user2 in `~/.kube/demo-users/` | Config change and rollback |

## How push-to-deploy works

```
Gitea commit to main
  └─ webhook (Gitea sends GitHub-compatible headers and signature)
      └─ EventListener el-guestbook   github interceptor checks the secret, CEL filter: main only
          └─ TriggerTemplate guestbook → PipelineRun of pipeline "guestbook" (clones via the Gitea Service)
              └─ git-clone → s2i-python build → pushes demo-intro/guestbook:latest
                  └─ image trigger on the Deployment → rolling update
```

The pipeline itself is created live by the console, from the `s2i-python-deployment` template, so the TriggerTemplate passes that template's parameters. That's why the app **must be named `guestbook`** in the Import from Git form.

## Layout

```
app/                 guestbook source; setup/reset push it to Gitea (VERSION in app.py is what changes)
manifests/
  database.yaml          PostgreSQL (applied by setup)
  pipeline-trigger.yaml  EventListener, TriggerBinding, TriggerTemplate (applied by setup)
  hello-pod.yaml         pasted into the console in Part 2
  guestbook-db-env.patch.yaml  Part 3: DB credentials as code (oc patch / paste into YAML tab)
  guestbook-route-roundrobin.patch.yaml  Part 4: route round robin, no sticky cookie
  guestbook-app.yaml     catch-up only: what Import from Git creates
steps/NN*-*.sh       catch-up scripts, one per demo section, safe to re-run
setup.sh / verify.sh / reset.sh / teardown.sh
demo.env             project, user and repo names for this demo
```

Shared helpers and cluster settings (API URL, Gitea, user password) are in [`../common`](../common).
