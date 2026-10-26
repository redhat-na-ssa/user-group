# FAA OpenShift user group: demos and slides

This repository holds everything needed to run a series of short OpenShift
sessions for the FAA: each one is about 30 minutes, a few minutes of
slides followed by a live demo on an OpenShift cluster. For every demo it
contains:

- a **reveal.js slide deck** (dark Red Hat theme, speaker notes on every
  slide, console screenshots as backup slides under each demo step),
- the **automation** that prepares the cluster for the demo, checks that it
  is ready, and resets it afterwards (Ansible, idempotent),
- a **presenter script** (`DEMO-SCRIPT.md`) and a **cheat-sheet**
  (`cheatsheet.sh`) with every CLI command used in the demo.

The decks are published on GitHub Pages:
<https://redhat-na-ssa.github.io/user-group/>

| Demo | Directory | Status |
|---|---|---|
| 1 - OpenShift fundamentals (pods, services, routes, deployments, pipelines, RBAC) | [demo1-fundamentals/](demo1-fundamentals/) | Ready (shell scripts, to be converted to Ansible) |
| 2 - OpenShift admin overview | - | Planned |
| 3 - Resource management (requests and limits, quotas, overcommit, right-sizing) | [demo3-resources/](demo3-resources/) | Outline (deck and script drafted, no automation yet) |
| 4 - OpenShift storage (PV/PVC, CSI, ODF, snapshots, OADP) | [demo4-storage/](demo4-storage/) | In progress |
| 5 - External secret management (HashiCorp Vault) | - | Planned |

## Repository layout

| Path | What it holds |
|---|---|
| `common/` | Shared settings (`vars.yml`, `env.sh`), shell helpers (`lib.sh`), the presenter workspace builder (`workspace.sh`) and the deck theme shared by all decks (`deck/`: `theme.css`, `deck.js`, `icons.svg`). |
| `faa-demo/` | The presentation namespace on the cluster: a playbook that deploys the slide site and the follow-up app, the slide-site image, the follow-up app source, and `preview.sh` for local preview. |
| `demoN-<name>/` | One directory per demo: setup/verify/reset/teardown, `DEMO-SCRIPT.md`, `cheatsheet.sh`, `slides/index.html`, `images/` (logos with their sources in `SOURCES.md`, screenshots) and `manifests/`. |
| `.github/workflows/pages.yml` | Builds and publishes the decks to GitHub Pages on every push to `main`. |

On the cluster, the slides and the follow-up app run in the `faa-demo`
namespace; each demo gets its own namespace (`demo-intro`, ...) holding only
what that demo needs.

## How to use

### Prerequisites

- `oc`, logged in to the cluster as a cluster admin
- Python 3, plus `npm` for the local slide preview
- On the cluster: OpenShift Pipelines, the Gitea instance used for the demo
  source repos, and the demo users `user1`..`user10`.

Nothing in the repository names a cluster. The playbooks and scripts work on
whichever cluster `oc` is logged in to: the API URL, console URL and apps
domain are read from the cluster itself, and the Gitea URL is derived from
the apps domain. The remaining settings (Gitea user and org, demo user
password, ...) are in [common/vars.yml](common/vars.yml) and
[common/env.sh](common/env.sh). Docs use `apps.<cluster-domain>` for your
cluster's apps domain. Per-demo settings, such as the NFS server for
demo 4, are in each demo's `demo.env`.

### 1. Install Ansible in a project venv (once)

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/ansible-galaxy collection install -r requirements.yml -p ./collections
```

`.venv/` and `collections/` are git-ignored. Run the playbooks from the repo
root.

### 2. Preview the slides locally

```bash
faa-demo/preview.sh            # http://localhost:8000/
```

The decks are symlinked from the working copy, so an edit shows up on a
browser refresh.

### 3. Deploy the presentation namespace

```bash
.venv/bin/ansible-playbook faa-demo/playbook.yml
```

This creates the `faa-demo` namespace, pushes the slide and follow-up app
sources to Gitea, builds them with a pipeline and deploys them. It also
applies two cluster settings the demos rely on (git in pipeline pods trusts
the cluster CA; CORS on the Gitea route). When adding a demo, add its deck to
the `decks` list in the playbook.

### 4. Prepare a demo

Each demo's own README or `DEMO-SCRIPT.md` has the details. In short:

```bash
# Demo 1 (shell scripts, from demo1-fundamentals/)
./setup.sh       # once
./verify.sh      # before every presentation
./reset.sh       # back to the start state after a run
./teardown.sh    # remove everything

# Demo 4 (Ansible, from the repo root)
.venv/bin/ansible-playbook demo4-storage/setup.yml
.venv/bin/ansible-playbook demo4-storage/verify.yml
.venv/bin/ansible-playbook demo4-storage/reset.yml
.venv/bin/ansible-playbook demo4-storage/teardown.yml
```

All of these are safe to re-run.

### 5. Set up the presenter's terminals

Shortly before presenting (demo user tokens expire):

```bash
common/workspace.sh demo1-fundamentals
bash --rcfile ~/faa-demo/demo1-fundamentals/user1.rc   # one terminal tab per identity
```

This builds `~/faa-demo/<demo>/` outside the repo with the cheat-sheet, the
demo's YAML files and one login per identity (admin, edit user, view user).
Each tab's prompt shows which user is typing, and `cheat` prints the
commands for a demo part.

### 6. Present

Open the deck and the OpenShift console in a browser, follow
`DEMO-SCRIPT.md` (the speaker notes have the same steps and commands), and
keep the cheat-sheet open on the private screen.

## Branding

Red Hat brand material (logo packs, presentation template) is kept in a
local `branding/` directory, which is git-ignored and never referenced by a
deck. Only the logos a deck actually uses are copied into that demo's
`images/` directory, with their source recorded in `images/SOURCES.md`.
