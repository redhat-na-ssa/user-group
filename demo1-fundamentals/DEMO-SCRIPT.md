# Demo 1 – OpenShift Fundamentals: presenter script

**Length:** about 40 minutes: up to 10 minutes of slides ("OpenShift architecture 1:1"), then about 30 minutes of live demo, **mostly in the console**.
**Audience takeaway:** you tell OpenShift what you want (a Deployment, a pipeline), and it keeps that true. Projects and RBAC decide who can ask for what.

Every live section has a **catch-up script** in `steps/`. If a console step goes wrong or time runs short, run the script in Terminal B. It brings the project to the end state of that section, and then you carry on in the console.

> **Rehearse the console clicks on this cluster version.** Menu names move between OpenShift releases. Where this script says "+ → Import from Git", your console may show it under **+Add** in the Developer view, or under the **+** (Quick create) button at the top of the page.

---

## Before you go on stage (T-15 min)

```bash
cd demo1-fundamentals
./reset.sh      # only if you rehearsed since the last setup
./verify.sh     # must end with "All good - ready to present Demo 1"
```

| Window | Logged in as | Starting point |
|---|---|---|
| **Browser A – main** | `user1` / `welcome1` | Console → project **demo-intro** → Topology |
| **Browser B – private window** | `user2` / `welcome1` | Console → project **demo-intro** → Topology |
| **Browser C – other profile** | `peter` | Console → Compute → Nodes |
| **Browser tab (in A)** | `demo` in Gitea | `https://local-gitea-gitea.apps.homeocp.ocp4.peterlarsen.org/ocpdemo/guestbook` |
| **Terminal B** (backup only) | `user1` | `export KUBECONFIG=~/.kube/demo-users/user1.kubeconfig; cd demo1-fundamentals` |

Increase the browser zoom to 125–150%. Keep `manifests/hello-pod.yaml` open in an editor, ready to copy.

---

## Slides – OpenShift architecture 1:1 (≤ 10 min)

One idea per slide. The last column is what you point at later in the demo, so the audience sees every term again.

| # | Term | One-line definition | Where it shows up in the demo |
|---|---|---|---|
| 1 | **Cluster** | Control plane nodes (API, scheduler, etcd) plus worker nodes that run the workloads | Part 1: the admin's **Nodes** page |
| 2 | **Node** | A machine (VM or bare metal) that runs pods | Part 2: the "Node" field on a pod |
| 3 | **Container image** | The app plus its dependencies, packaged and immutable. It is stored in a **registry** | Part 3: the pipeline builds one |
| 4 | **Pod** | One or more containers sharing an IP and storage. The smallest unit you run, and disposable | Part 2 |
| 5 | **Deployment** (→ ReplicaSet) | "Keep N copies of this pod template running." A new template means a rolling update | Parts 3–6 |
| 6 | **Service** | A stable name and virtual IP in front of a changing set of pods | Part 3: the frontend finds `postgresql` by name |
| 7 | **Route** | An external HTTPS URL that forwards to a Service | Part 3: the app URL |
| 8 | **Project** (namespace) | The boundary for names, quotas, network and **RBAC** | Part 1 |
| 9 | **ConfigMap / Secret** | Configuration and credentials, kept outside the image | Parts 3 and 6 |
| 10 | **Pipeline** (Tekton) | Automated steps (clone → build → deploy) that each run in a pod | Parts 3 and 5 |

Close with the picture of today's app: **Gitea → Pipeline → image → Deployment (guestbook) → Service → Route**, with the guestbook talking to **PostgreSQL** (Deployment + PVC + Secret).

---

## Part 1 – Tour, projects and RBAC (5 min)

**Point to make:** a project is a tenant. The admin decides who can see or change what in each one.

1. **Browser C (peter):** open **Compute → Nodes**. These are the nodes from the slides: control plane and workers. Say: *"Developers never need this page, and user1 can't even see it."*
2. **Browser A (user1):** show **Topology** for `demo-intro`. PostgreSQL is already there, provided by "the platform team". Click it: Deployment, 1 pod, Service, and storage (PVC).
3. **Browser C (peter):** open **Project → demo-intro → Project access** (RoleBindings): peter is `admin`, user1 is `edit`, user2 is `view`.
4. **Browser B (user2):** the same Topology, but read-only. Try **Secrets**: access denied. Try to edit or scale the database: not allowed.

Talking points: roles are standard (`admin`, `edit`, `view`) and bound per project. user2 could be an auditor, or a team that depends on this app.

*Catch-up:* `steps/01-rbac.sh` (read-only; prints a can-i matrix)

---

## Part 2 – Containers and pods (4 min) · *Browser A*

**Point to make:** a pod is the smallest unit. It is useful to look at, but on its own it is fragile.

1. **+ → Import YAML**, paste `manifests/hello-pod.yaml`, and click **Create**. Point out that this is all a pod is: a name and an image.
2. On the pod page:
   - **Details:** the pod IP, and the **Node** it landed on (tie back to the slide).
   - **Logs**.
   - **Terminal:** run `id` (a random high UID, not root) and `ps -ef`.
   - **Events:** scheduled → image pulled → started.
3. **Actions → Delete Pod.** It is gone, and nothing brings it back.
4. Contrast: in Topology, open the PostgreSQL pod and delete it. A new one appears within seconds, because its **Deployment** replaces it. (The data survives because it is on the PVC.)

*Catch-up:* `steps/02-pod.sh`

---

## Part 3 – From Git to running app: pipeline, Deployment, Service and Route (8 min) · *Browser A*

**Point to make:** a non-admin developer goes from a Git URL to a running, routed app, and OpenShift builds it with a visible pipeline.

1. Show the Gitea repo tab briefly: a plain Python app, `app.py`, `VERSION = "1.0"`.
2. **+ → Import from Git**:
   - **Git Repo URL:** `http://local-gitea.gitea.svc:3000/ocpdemo/guestbook.git`. This is Gitea's in-cluster **Service** address, the same idea as the guestbook reaching `postgresql`. The pipeline clones inside the cluster, so it never goes out through the router.
   - The console shows a yellow warning: *"The Gitea repository is unreachable"*. **That is expected.** The console checks the repo from outside the cluster, where Service names don't resolve. The pipeline runs inside the cluster, so it can clone. (Talking point: this is the Service concept from the slides, from the other side.)
   - Because the console couldn't read the repo, it can't detect the language. Choose **Import Strategy → Builder Image → Python**, version **3.12-ubi9**.
   - **Application:** `guestbook` (the existing application group, so it sits next to PostgreSQL). **Name:** `guestbook`. *The name must be `guestbook`, because the push trigger in Part 5 starts the pipeline by that name.*
   - **Build option: Pipelines** (in older consoles, the **Add pipeline** checkbox).
   - Resource type: **Deployment**. Keep **Create a route** checked.
   - **Create**.

3. **Talk through the build (about 90 seconds).** The first run takes 1.5–2 minutes. Use that time to walk through what the form just created, one object at a time; each one is a term from the slides:

   | Time | Click | Say |
   |---|---|---|
   | 0:00 | **Pipelines → guestbook →** the running PipelineRun | "Three steps: fetch the code, build an image, deploy it. Each box is a **pod**, scheduled onto a **node** like any other workload." |
   | 0:20 | **fetch-repository** → Logs | "It cloned from Gitea over the in-cluster **Service** address." |
   | 0:30 | **build** → Logs (pip install scrolling) | "No Dockerfile. The builder image knows Python: it installs the requirements and packages the app as a **container image**, then pushes it to the internal **registry**." |
   | 0:50 | **Topology** → guestbook → **Details** | "The **Deployment** already exists. We declared the state we want: 1 replica of this image. It's waiting for the image to exist." |
   | 1:10 | **Resources** tab → Service, then Route | "The **Service**: a stable name for the pods to come. The **Routeproduct-logos.zip  'Red Hat standard presentation template.odp'   red-hat.zip   technical-partner-buttons.zip   tool-logos.zip**: the public URL, already reserved." |
   | 1:30 | Back to the PipelineRun: **deploy** turns green | "The image landed, the Deployment noticed, and a pod is starting." |

   If the build finishes early, skip the rows you haven't reached. If it runs long, open the **build** logs again: the push to the registry is the last thing it does.

4. Back in **Topology**, the guestbook ring turns blue. Open the route (the arrow icon). The page loads but shows **"Database unavailable: ... password authentication failed for user "guestbook""**. The app reached the database through its Service, but it has no credentials yet.

5. Click the guestbook Deployment → **Environment** tab. Scroll to **All values from existing ConfigMaps or Secrets (envFrom)**, choose the secret `guestbook-db`, and leave **Prefix** empty → **Save**. Every key in the secret becomes an environment variable with the same name: `POSTGRESQL_USER`, `POSTGRESQL_PASSWORD` and `POSTGRESQL_DATABASE`. Those are the names the app reads, and the same secret feeds the PostgreSQL pod. Point out that changing the pod template **rolls out a new pod**.
   *Don't use "Add from ConfigMap or Secret" under **Single values (env)**: it needs one row per key, with each name typed by hand.*
6. Refresh the app. It works. **Sign the guestbook**, or ask the audience to sign it from their phones.

Talking points:
- The frontend connects to `postgresql:5432`, which is the **Service** name, not a pod IP.
- The password lives in a **Secret**. user2 cannot read it (Browser B).
- *"Environment variables keep it simple for today. In production you'd mount credentials as files, or pull them from a vault with something like the External Secrets Operator. The idea is the same: credentials live outside the image."*
- The **Route** is the public HTTPS URL. Show it on the Route's details page.

*Catch-up:* `steps/03-import-from-git.sh`. It creates the same pipeline, Deployment, Service and Route, runs the first build, and wires in the secret.

---

## Part 4 – Self-healing, health checks and scaling (5 min) · *Browser A*

**Point to make:** you declare the state you want, and OpenShift keeps it true.

1. Topology → guestbook → **Actions → Add Health Checks**:
   - Readiness: HTTP GET `/readyz`, port 8080.
   - Liveness: HTTP GET `/healthz`, port 8080.
   - **Add** (this is another rollout).
2. Delete the guestbook pod. The ring shows the replacement starting straight away.
3. **Details** tab → the **up arrow** → 3 pods. Open the **Service → Pods** view: three endpoints behind one name.
4. Refresh the app: "served by pod" doesn't change. **Routes are sticky by default** (a cookie). Switch the route to round robin: Route → **YAML**, add these annotations, then **Save**:
   ```yaml
   metadata:
     annotations:
       haproxy.router.openshift.io/balance: roundrobin
       haproxy.router.openshift.io/disable_cookies: "true"
   ```
   Refresh again in a new private window, or run `curl` a few times. The pod name changes. Sign the book again: every entry records which pod wrote it, but they all share one database.
5. **Browser B (user2):** the scale arrows are missing or disabled.

*Catch-up:* `steps/04-scale.sh`

---

## Part 5 – Ship a new version with a Git commit (6 min) · *Gitea tab + Browser A*

**Point to make:** a commit becomes a rolling update, with no tickets and no manual redeploy.

1. In Gitea: open `app.py` → **Edit** (the pencil icon) → change `VERSION = "1.0"` to `VERSION = "2.0"` → commit to `main`.
2. Switch to **Pipelines**. A new PipelineRun has **started by itself**: Gitea's webhook called the pipeline's trigger. Open it: clone → build → deploy again.
3. Watch Topology while the build finishes: new pods come up, and old ones drain only after the new ones pass the readiness check from Part 4.
4. Refresh the app: the badge reads **v2.0**, and the guestbook entries are all still there, because the data is in PostgreSQL.

If the pipeline doesn't start within about 10 seconds, go to **Pipelines → guestbook → Actions → Start** (the defaults build `main`). Then check Gitea → repo **Settings → Webhooks → Recent deliveries** afterwards.

*Catch-up:* `steps/05-new-version.sh` (commits through the Gitea API, then waits for the pipeline and the rollout)

---

## Part 6 – Configuration change and rollback (3 min) · *Browser A*

**Point to make:** configuration is part of the Deployment too, and every revision is kept.

1. guestbook Deployment → **Environment** → add `APP_COLOR` = `#0066cc` and `APP_TITLE` = `Guestbook - config change` → **Save**.
2. Refresh the app: the banner is blue. A config change is a rollout too, with no rebuild.
3. **Deployment → ReplicaSets** tab: one ReplicaSet per revision.
4. Roll back. This is the one CLI moment, in Terminal B:
   ```bash
   oc rollout undo deployment/guestbook -n demo-intro
   ```
   Refresh: it is back to the red v2.0.

*Catch-up:* `steps/06-config-rollback.sh`

---

## Wrap-up (1 min)

Go back to the architecture picture and point at each box: you touched every one of them.
- **Project and RBAC:** who can do what, per team.
- **Pod → Deployment:** declare the state you want, and OpenShift keeps it true.
- **Service and Route:** stable names inside the cluster, HTTPS outside.
- **Pipeline:** a commit becomes an image, and the image becomes a rolling update. Config changes are rollouts too.
- Next demo: the developer inner loop with Dev Spaces.

## After the demo

```bash
./reset.sh      # ready to present again: removes the app and pipeline, resets the Git repo to v1.0
./teardown.sh   # removes the project and the Gitea repo
```

## If something goes wrong

| Symptom | Fix |
|---|---|
| The fetch-repository task fails with a TLS or certificate error | The Git URL is the public `https://local-gitea-gitea...` route. Use `http://local-gitea.gitea.svc:3000/ocpdemo/guestbook.git` |
| Import from Git can't detect the language | Choose Git type **Other** and pick the **Python** builder by hand |
| The app shows "Database unavailable ... password authentication failed" | This is expected until `guestbook-db` is added under **Environment** (Part 3, step 5) |
| The pipeline's build task fails on pip | The build needs outbound access to PyPI. Rerun it (**Actions → Rerun**) |
| A commit doesn't start a pipeline | Pipeline not named `guestbook`? Otherwise check Gitea **Settings → Webhooks → Recent deliveries**, then `oc logs deploy/el-guestbook -n demo-intro`. Start the run by hand with **Actions → Start** |
| The browser always shows the same pod | The route annotation from Part 4 is missing, or the browser kept a cookie (use a new private window) |
| user1 or user2 cannot log in | `../common/login-users.sh user1 user2` (the password is in `common/env.sh`) |
| The state is messed up mid-demo | Run that section's catch-up script. Each one is safe to re-run |
