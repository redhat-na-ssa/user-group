# Setting up demos on OpenShift

This project is to hold configurations for an OpenShift cluster (clusters once the ACM demo is done) which illustrate specific key features. There are going to be multiple demos, each of them need about 30-40 minutes of talk/demo only. The "slides" should be no more than 10 minutes of the whole process.

## Slide deck

A 5-10 minute slide deck using **reveal.js** needs to be created - this will be used for the introduction. (Not Marp: reveal.js supports vertical slides, which the screenshot backups below rely on, plus Markdown slides and speaker notes.) I'll supply branding logos and formatting to make it look official. Each area may use different products so product logos may change and not all just show OpenShift and Kubernetes. The `branding/` directory in the root holds the brand source material (logo packs, presentation template) and is internal only: it is never committed and never referenced by a presentation.

### Deck structure (every demo)

One reveal.js deck per demo, at `<demo>/slides/index.html`. The site root (`faa-demo/templates/index.html.j2`) is a page that lists the decks to pick from. Time budget: aim for 30 minutes for the whole session (slides + demo) - not much less, and never more than 40; slides take no more than 10 minutes of it. If a run-through comes in well under 30, add depth to the demo (or plan to use the optional down slides) rather than leave the time empty.

Horizontal flow (RIGHT arrow), about 5 slides before the demo starts:
1. **Title** - the demo's name, the presentation date, the Red Hat and FAA logos (no footer).
2. **Who are we** - one column per Red Hat presenter (photo once permission is given, name, title); under them the mission statement "Enable FAA to get more value out of Red Hat technologies".
3. **What we will cover today** - the demo's steps in plain, non-technical words (no Kubernetes terms; those are explained during the demo). It mirrors the wrap-up slide, which says the same in product terms.
4. **Concepts covered** - one overview slide (demo 1: "What is OpenShift?"). The detailed concept slides are vertical slides under it (DOWN arrow), used only when the audience needs them; RIGHT goes straight on to the demo.
5. **Demo steps** - an intro slide (the picture of what gets built), then one slide per demo step showing the steps taken and the commands ("The same, as code"), so it's easy to show later what was done. Console screenshots of the step go in vertical backup slides under it (see "Demo scripts").
6. A short wrap-up, then the **Q&A** slide (last): a "Q&A" banner, a link and QR code to the deck on GitHub Pages (https://redhat-na-ssa.github.io/user-group/<demo>/), "See you next time: <next demo>" once the next topic is set, and a few short discussion prompts (was it useful, is the format right, what next) - the session ends with a conversation, not just questions. The QR code is captioned "Presentation source". The follow-up app is **not** linked from any deck or public page (the decks are public on GitHub Pages; the audience's questions must not be) - the presenter opens it from a bookmark.

Every slide except title and Q&A shows the demo/workshop title in the footer and a page number. The page number only appears when the mouse hovers over it (bottom right): the total includes the backup slides, which the audience shouldn't count.

### Look and content

- Dark theme only, 16:9. The styling is defined once in `common/deck/theme.css` (modelled on the dark layouts of the Red Hat template) and `common/deck/deck.js`; use the existing classes (`title-slide`, `about`, `term`, `steps`, `backup`, `qa`, `diagram`, ...) rather than inline styles.
- Slides have few words, not a bunch of bullets. Use images and diagrams to illustrate the concepts used in the demo. Diagrams are inline SVG using the shared red line-art icons in `common/deck/icons.svg` (`<use href="#i-pod">`). Any new logo or image a slide needs is taken from the brand packs in `branding/` first: extract it into `<demo>/images/` and reference it there (see below).
- Every slide has speaker notes - a paragraph or two (`<aside class="notes">`). Lots of words in the notes are preferred to words on the slide. Demo-step notes include the exact CLI commands to type.

A presentation template has been placed in branding named "Red Hat standard presentation template.odp". It's a LibreOffice Impress template (as created by Google Slides) and it holds a lot of standards for slide layouts. Notice the wide format (16:9, not 4:3) and notice there are bright and dark templates. So the same type of example is there multiple times with different "color codes". For this, I want to use the dark themes, so the dark/black options are needed. You'll find zip files with all the logos and common graphics too.

Brand material is used internally only: `branding/` (anywhere in the repo) is excluded by `.gitignore`, and its zip files and .odp template are symlinks to my local brand folder. Whenever a deck needs a new logo or image, look in the brand packs first. For each demo, extract only the images its deck uses into `<demo>/images/` and have the presentation reference them there. Use the "Reverse" SVG variants (made for dark backgrounds), give them short names (e.g. `redhat-logo.svg`) and record each file's source pack and original name in `<demo>/images/SOURCES.md`. The FAA logo was supplied separately (`faa-seal.svg`, see demo 1's `SOURCES.md`). Upstream projects (Kubernetes, Tekton, Python, PostgreSQL, ...) are not in the Red Hat packs: for now use the official logo from the project's own website, stored in `<demo>/images/` with its source URL in `SOURCES.md`. Prefer SVG, and a variant that reads on a dark background. These may later be replaced with corporate-suggested versions.

## Presentation namespace (faa-demo)

Slides and demos run from the same cluster, in separate namespaces:
- `faa-demo` - the presentation: the static reveal.js slide decks (served by a web server) and the questions/follow-up application.
- `demo-intro`, ... - one namespace per demo, holding only what the demo needs.

A single Ansible playbook initializes `faa-demo` with the static slides and the follow-up app.

Follow-up app: a simple web app, opened by the presenter in a separate browser tab (private: never linked from a deck or the public GitHub Pages site), where parking-lot / follow-up points are typed in during the session and saved persistently for later. Its source lives in Gitea (like the demo apps) and it is built and deployed on the cluster.

## Key information

OpenShift:
  api: https://api.homeocp.ocp4.peterlarsen.org:6443
  console: https://console-openshift-console.apps.homeocp.ocp4.peterlarsen.org
Git: https://gitlab.peterlarsen.org (exists, but not trusted enough to be in the critical path of a demo)
  Demo source repos: Gitea on the cluster, installed just for demos.
    URL: https://local-gitea-gitea.apps.homeocp.ocp4.peterlarsen.org (service local-gitea:3000, namespace gitea; managed by the RHPDS Gitea operator)
    User: demo / welcome1 (member of org ocpdemo; ocpdemo is an org, not a login). No user1..user10 in Gitea. Demo repos live in the ocpdemo org. Settings are in common/env.sh.
    Import from Git and the pipelines use the public route URL (https://local-gitea-gitea.apps.../ocpdemo/<repo>.git). Two cluster settings make that work, both applied by faa-demo/playbook.yml: (1) git in task pods trusts the cluster CA bundle - OpenShift Pipelines mounts it at /tekton-custom-certs/ca-bundle.crt but only advertises it via SSL_CERT_DIR (a hashed-directory lookup git ignores), so `common/manifests/tektonconfig-git-ca.patch.yaml` sets GIT_SSL_CAINFO in the TektonConfig default pod template, cluster-wide; (2) a CORS header on the Gitea route, because the console checks the repo from the browser. The in-cluster Service URL (http://local-gitea.gitea.svc:3000/...) still works for clones, but the console then shows "The Gitea repository is unreachable". Gitea allows webhooks to cluster-internal addresses (ALLOWED_HOST_LIST = external,private).
  Note: the cluster has a leftover GitLab CRD but no GitLab operator or instance - it is not an option without reinstalling.
Container repo: quay2.peterlarsen.org

During development, the oc/kubectl command will be authenticated as a cluster admin. There are a set of non privileged users (user1-user10) with the password welcome1 that would be used to demonstrate developer and other non admin things.

## Repository layout

- `branding/` - internal brand source material (git-ignored, never referenced by a deck)
- `common/` - shared settings and helpers used by every demo: `vars.yml` (Ansible), `env.sh`/`lib.sh` (shell), `deck/` (reveal.js theme `theme.css` and bootstrap `deck.js` shared by all decks)
- `faa-demo/` - the presentation namespace: `playbook.yml` (namespace, Gitea repos `ocpdemo/faa-slides` + `ocpdemo/faa-followups`, build pipeline, deployments), `slides-site/` (nginx + reveal.js/fonts image), `followup-app/` (Flask + SQLite), `preview.sh` (local preview of the decks at http://localhost:8000/, files symlinked from the working copy so edits show on refresh). Add each new demo's deck to the `decks` list in the playbook.
- Ansible runs from a project venv: `python3 -m venv .venv && .venv/bin/pip install -r requirements.txt`, then `ansible-galaxy collection install -r requirements.yml -p ./collections` (`.venv/` and `collections/` are git-ignored). Run from the repo root: `.venv/bin/ansible-playbook faa-demo/playbook.yml`. `ansible.cfg` is only read from the current directory, so each playbook directory also has a `collections -> ../collections` symlink (Ansible searches `collections/` next to the playbook): that lets the playbook run from its own directory too. Add the same symlink for every new playbook directory.
- `demoN-<name>/` - one directory per demo: setup/verify/reset/teardown automation, `DEMO-SCRIPT.md` (presenter talk track), the reveal.js deck (`slides/index.html`), `images/` (the logos extracted for this deck, diagrams and console screenshots; see `images/SOURCES.md`) and the terminal cheat-sheet (see "Demo scripts"). Automation must be idempotent.

Demo 1 was first built with shell scripts (`setup.sh`, `verify.sh`, `reset.sh`, `teardown.sh`, `steps/NN*-*.sh`); these are to be converted to Ansible.

## Demo scripts

To setup a cluster with the pre-reqs for the demo, and to set/reset a demo to a given state, we use Ansible (ansible-core) whenever possible. Avoid using shell scripts for this.

The shell during a demo is the **OpenShift web terminal in the console**. The demo is primarily GUI-driven, but the terminal must be available to showcase CLI options too. In the speaker notes, show the CLI commands like "oc get pods", "oc new-app" to be run at each step to remind the speaker of exactly what to type. Have the same commands in a single cheat-sheet file per demo that can be opened in the OCP web terminal, to quickly reference or copy/paste forgotten commands in the heat of the presentation. Keep the cheat-sheet and every other file opened in the web terminal plain ASCII (no "·", "→", curly quotes): the web terminal has no UTF-8 locale and shows such characters as raw bytes like `<C2><B7>`.

When a demo uses the GUI, the main pages need a slide with a screen-dump, placed as a vertical slide (reached by pressing down, not right) under the step's slide, so it can be used as a backup if the demo system is having issues. Screen-dumps are taken by hand while the demo script is developed, and stored in the demo's `images/` directory.

Console conventions for demos: use the **Developer perspective** for the demo users; describe navigation as a new user sees it (no pinned items - e.g. reach a Deployment's full page from Topology). Show a change once in the console, then apply it "as code" (a small YAML/patch file) to make the point that the console isn't the tool for real development. Point out console side effects when they appear (e.g. Instantiate Template leaves a `<template>-parameters-…` Secret with the form values). Longer term, the demos should steer the audience toward the CLI, Ansible or GitOps (Argo CD) as the way to do real work, with the console for learning and looking around.

## Demo 1 - OpenShift fundamentals

This introduces containers and pods, services, routes/ingress, deployments and how deployments can be refreshed or automatically updated. It will cover the console view of pods, how to interact with runtimes and understand what is going on. Core concepts like project RBAC and understanding namespaces is going to be a big part of the focus.

There should be at least two applications - a web frontend and a database. The focus isn't on the code but on how to manage them.

namespace/project: demo-intro
Admin user: peter (the active user setting up the demo)
Demo user: user1 - has edit rights to the project
Demo user: user2 - has view rights to the project

App: a guestbook (Python/Flask frontend + PostgreSQL). Every page shows the version, the serving pod and a banner colour (APP_COLOR), so new versions, load balancing and config changes are visible in the browser. A new version is a change to `VERSION` in app.py, committed in Gitea (ocpdemo/guestbook). PostgreSQL is deployed live from a project-local template (`postgresql-demo`, "PostgreSQL 15" in the Developer Catalog) - our own because the stock template and Helm chart create the deprecated DeploymentConfig; it creates a Deployment, Service, Secret `postgresql` (keys database-user/-password/-name) and PVC.

Structure of the session:
- Slides (<= 10 min): title, Who are we, What we will cover today, "What is OpenShift?" (the "OpenShift architecture 1:1" term slides - node, pod, container, deployment, service, route, project/namespace, etc. - are vertical slides under it, optional), then the demo intro "Live demo: today's application".
- Demo order: 1 deploy PostgreSQL from the catalog, 2 pods, 3 from source code (Import from Git + pipeline), 4 self-healing and scaling, 5 projects and RBAC (deliberately not first), 6 a commit becomes a new version (the EventListener is created live here, not in setup), 7 configuration and rollback.
- Demo: keep most of it in the OpenShift console, not the CLI. Prep work before the demo (automation) is fine and expected; the console-driven part is what the audience sees.

Builds: use OpenShift Pipelines (Tekton), not a bare S2I BuildConfig - pipelines show better in the console and look less cryptic to non-developers. This means the app source lives in a Git repo the pipeline clones from. The app is created live with the console's Import from Git (Pipelines build option) and **must be named `guestbook`**, because the pre-staged Gitea webhook -> EventListener -> TriggerTemplate starts the pipeline by that name.

## Demo 2 - Development (devspaces)

(more to come - we'll focus on demo 1 for now to see if this will work).
