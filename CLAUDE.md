# Setting up demos on OpenShift

This project is to hold configurations for an OpenShift cluster (clusters once the ACM demo is done) which illustrate specific key features. There are going to be multiple demos, each of them need about 30-40 minutes of talk/demo only. The "slides" should be no more than 10 minutes of the whole process.

## Slide deck

A 5-10 minute slide deck using **reveal.js** needs to be created - this will be used for the introduction. (Not Marp: reveal.js supports vertical slides, which the screenshot backups below rely on, plus Markdown slides and speaker notes.) I'll supply branding logos and formatting to make it look official. Each area may use different products so product logos may change and not all just show OpenShift and Kubernetes. The `branding/` directory in the root holds the brand source material (logo packs, presentation template) and is internal only: it is never committed and never referenced by a presentation.

For each major step in the demo, having a slide that shows the steps taken, commands written, so it's easy to show what was done later will be needed. Each slide set will start with a "Welcome to the Red Hat User Group for FAA" - it will include the Red Hat logo and the FAA logo. We'll include the date of the presentation once we're ready. At the very last page needs to be a "Q&A" banner, with a link to the follow-up app (see "Presentation namespace") where "parking lot" / follow-up points are typed in and saved. The title of the demo/workshop will be in the footer of each slide, and a page number will be on the slide too.

As a rule slides should have few words, not a bunch of bullets. Using images to illustrate concepts that's being used in the demo, not words. Adding lots of words to the speaker notes is preferred - not the slides.

A presentation template has been placed in branding named "Red Hat standard presentation template.odp". It's a LibreOffice Impress template (as created by Google Slides) and it holds a lot of standards for slide layouts. Notice the wide format (16:9, not 4:3) and notice there are bright and dark templates. So the same type of example is there multiple times with different "color codes". For this, I want to use the dark themes, so the dark/black options are needed. You'll find zip files with all the logos and common graphics too.

Brand material is used internally only: `branding/` (anywhere in the repo) is excluded by `.gitignore`, and its zip files and .odp template are symlinks to my local brand folder. For each demo, extract only the logos its deck uses into `<demo>/images/` and have the presentation reference them there. Use the "Reverse" SVG variants (made for dark backgrounds), give them short names (e.g. `redhat-logo.svg`) and record each file's source pack and original name in `<demo>/images/SOURCES.md`. No FAA logo has been supplied yet. Upstream projects (Kubernetes, Tekton, Python, PostgreSQL, ...) are not in the Red Hat packs: for now use the official logo from the project's own website, stored in `<demo>/images/` with its source URL in `SOURCES.md`. Prefer SVG, and a variant that reads on a dark background. These may later be replaced with corporate-suggested versions.

## Presentation namespace (faa-demo)

Slides and demos run from the same cluster, in separate namespaces:
- `faa-demo` - the presentation: the static reveal.js slide decks (served by a web server) and the questions/follow-up application.
- `demo-intro`, ... - one namespace per demo, holding only what the demo needs.

A single Ansible playbook initializes `faa-demo` with the static slides and the follow-up app.

Follow-up app: a simple web app, opened from the Q&A slide or in a separate browser tab, where parking-lot / follow-up points are typed in during the session and saved persistently for later. Its source lives in Gitea (like the demo apps) and it is built and deployed on the cluster.

## Key information

OpenShift:
  api: https://api.homeocp.ocp4.peterlarsen.org:6443
  console: https://console-openshift-console.apps.homeocp.ocp4.peterlarsen.org
Git: https://gitlab.peterlarsen.org (exists, but not trusted enough to be in the critical path of a demo)
  Demo source repos: Gitea on the cluster, installed just for demos.
    URL: https://local-gitea-gitea.apps.homeocp.ocp4.peterlarsen.org (service local-gitea:3000, namespace gitea; managed by the RHPDS Gitea operator)
    User: demo / welcome1 (member of org ocpdemo; ocpdemo is an org, not a login). No user1..user10 in Gitea. Demo repos live in the ocpdemo org. Settings are in common/env.sh.
    Pipelines clone over the in-cluster Service (http://local-gitea.gitea.svc:3000/...), not the public route: task pods don't trust the ingress CA. Gitea allows webhooks to cluster-internal addresses (ALLOWED_HOST_LIST = external,private).
  Note: the cluster has a leftover GitLab CRD but no GitLab operator or instance - it is not an option without reinstalling.
Container repo: quay2.peterlarsen.org

During development, the oc/kubectl command will be authenticated as a cluster admin. There are a set of non privileged users (user1-user10) with the password welcome1 that would be used to demonstrate developer and other non admin things.

## Repository layout

- `branding/` - internal brand source material (git-ignored, never referenced by a deck)
- `common/` - shared settings and helpers used by every demo: `vars.yml` (Ansible), `env.sh`/`lib.sh` (shell), `deck/` (reveal.js theme `theme.css` and bootstrap `deck.js` shared by all decks)
- `faa-demo/` - the presentation namespace: `playbook.yml` (namespace, Gitea repos `ocpdemo/faa-slides` + `ocpdemo/faa-followups`, build pipeline, deployments), `slides-site/` (nginx + reveal.js/fonts image), `followup-app/` (Flask + SQLite). Add each new demo's deck to the `decks` list in the playbook.
- Ansible runs from a project venv: `python3 -m venv .venv && .venv/bin/pip install -r requirements.txt`, then `ansible-galaxy collection install -r requirements.yml -p ./collections` (`.venv/` and `collections/` are git-ignored). Run from the repo root: `ansible-playbook faa-demo/playbook.yml`.
- `demoN-<name>/` - one directory per demo: setup/verify/reset/teardown automation, `DEMO-SCRIPT.md` (presenter talk track), the reveal.js deck (`slides/index.html`), `images/` (the logos extracted for this deck, diagrams and console screenshots; see `images/SOURCES.md`) and the terminal cheat-sheet (see "Demo scripts"). Automation must be idempotent.

Demo 1 was first built with shell scripts (`setup.sh`, `verify.sh`, `reset.sh`, `teardown.sh`, `steps/NN*-*.sh`); these are to be converted to Ansible.

## Demo scripts

To setup a cluster with the pre-reqs for the demo, and to set/reset a demo to a given state, we use Ansible (ansible-core) whenever possible. Avoid using shell scripts for this.

The shell during a demo is the **OpenShift web terminal in the console**. The demo is primarily GUI-driven, but the terminal must be available to showcase CLI options too. In the speaker notes, show the CLI commands like "oc get pods", "oc new-app" to be run at each step to remind the speaker of exactly what to type. Have the same commands in a single cheat-sheet file per demo that can be opened in the OCP web terminal, to quickly reference or copy/paste forgotten commands in the heat of the presentation.

When a demo uses the GUI, the main pages need a slide with a screen-dump, placed as a vertical slide (reached by pressing down, not right) under the step's slide, so it can be used as a backup if the demo system is having issues. Screen-dumps are taken by hand while the demo script is developed, and stored in the demo's `images/` directory.

Console conventions for demos: use the **Developer perspective** for the demo users; describe navigation as a new user sees it (no pinned items - e.g. reach a Deployment's full page from Topology). Show a change once in the console, then apply it "as code" (a small YAML/patch file) to make the point that the console isn't the tool for real development.

## Demo 1 - OpenShift fundamentals

This introduces containers and pods, services, routes/ingress, deployments and how deployments can be refreshed or automatically updated. It will cover the console view of pods, how to interact with runtimes and understand what is going on. Core concepts like project RBAC and understanding namespaces is going to be a big part of the focus.

There should be at least two applications - a web frontend and a database. The focus isn't on the code but on how to manage them.

namespace/project: demo-intro
Admin user: peter (the active user setting up the demo)
Demo user: user1 - has edit rights to the project
Demo user: user2 - has view rights to the project

App: a guestbook (Python/Flask frontend + PostgreSQL). Every page shows the version, the serving pod and a banner colour (APP_COLOR), so new versions, load balancing and config changes are visible in the browser. A new version is a change to `VERSION` in app.py, committed in Gitea (ocpdemo/guestbook). pacman (quay.io/plarsen/pacman) is the "it's this simple" deploy-from-an-image example.

Structure of the session:
- Slides (<= 10 min): "OpenShift architecture 1:1" - define the terms (node, pod, container, deployment, service, route, project/namespace, etc.). Once that's done, dive into the demo.
- Demo: keep most of it in the OpenShift console, not the CLI. Prep work before the demo (automation) is fine and expected; the console-driven part is what the audience sees.

Builds: use OpenShift Pipelines (Tekton), not a bare S2I BuildConfig - pipelines show better in the console and look less cryptic to non-developers. This means the app source lives in a Git repo the pipeline clones from. The app is created live with the console's Import from Git (Pipelines build option) and **must be named `guestbook`**, because the pre-staged Gitea webhook -> EventListener -> TriggerTemplate starts the pipeline by that name.

## Demo 2 - Development (devspaces)

(more to come - we'll focus on demo 1 for now to see if this will work).
