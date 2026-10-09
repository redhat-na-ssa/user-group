# Demo 1 – OpenShift Fundamentals: presenter script

**Length:** about 40 minutes: up to 10 minutes of slides ("OpenShift architecture 1:1"), then about 30 minutes of live demo, **mostly in the console**.
**Audience takeaway:** you tell OpenShift what you want (a Deployment, a pipeline), and it keeps that true. Projects and RBAC decide who can ask for what.

Every live section has a **catch-up script** in `steps/`. If a console step goes wrong or time runs short, run the script in Terminal B. It brings the project to the end state of that section, and then you carry on in the console.

> **Use the Developer perspective** (the perspective switcher at the top of the left nav) for user1 and user2. A new user's left nav has **+Add, Topology, Observe, Search, Builds, Pipelines, Helm, Project, ConfigMaps and Secrets**, with no Deployments entry. So this script reaches a Deployment's **full page** from Topology: click the node, then click the Deployment name at the top of the side panel. Only peter's Browser C uses the Administrator perspective, to show nodes.

---

## Preparing the cluster

The project isn't created during the demo; that's prep work. The demo starts from an **empty project** that "the platform team" gave you, with a PostgreSQL template published in its catalog. Log in as the admin first (`oc login -u peter …`).

| Situation | Run |
|---|---|
| First time, or after `./teardown.sh` (the project `demo-intro` doesn't exist) | `./setup.sh`: creates the project, RBAC (user1 edit, user2 view), the PostgreSQL template, the Gitea repo at v1.0 and the push trigger's hidden pieces (~1 min) |
| After a rehearsal or a previous run | `./reset.sh`: deletes the project and rebuilds it with `setup.sh`, Git repo back to v1.0 (a minute or two) |
| Always, right before presenting | `./verify.sh`: must end with "All good - ready to present Demo 1" |

The slides and the follow-up app live in their own namespace, `faa-demo` (`ansible-playbook faa-demo/playbook.yml`), and are not touched by these scripts.

## Before you go on stage (T-15 min)

```bash
cd demo1-fundamentals
./setup.sh      # only if demo-intro doesn't exist (first time, or after teardown)
./reset.sh      # only if you rehearsed since the last setup
./verify.sh     # must end with "All good - ready to present Demo 1"
```

| Window | Logged in as | Starting point |
|---|---|---|
| **Browser A – main** | `user1` / `welcome1` | Developer perspective → project **demo-intro** → Topology (empty) |
| **Browser B – private window** | `user2` / `welcome1` | Developer perspective → project **demo-intro** → Topology |
| **Browser C – other profile** | `peter` | Developer perspective → Project → Project access |
| **Browser tab (in A)** | `demo` in Gitea | `https://local-gitea-gitea.apps.homeocp.ocp4.peterlarsen.org/ocpdemo/guestbook` |
| **Slides** | – | `https://slides-faa-demo.apps.homeocp.ocp4.peterlarsen.org/demo1-fundamentals/`, press **S** for the speaker view |
| **Web terminal** (in A) | `user1` | `>_` icon: `curl -sO http://slides.faa-demo.svc:8080/demo1-fundamentals/cheatsheet.sh && source cheatsheet.sh` |

Increase the browser zoom to 125–150%. Keep `manifests/hello-pod.yaml` and `manifests/guestbook-eventlistener.yaml` open in an editor, ready to copy.

---

## Slides (≤ 10 min)

Going RIGHT: **title** → **Who are we** (introductions, mission) → **What we will cover today** → **What is OpenShift?** → **Live demo: today's application** → the demo parts.

The "OpenShift architecture 1:1" term slides below sit *under* "What is OpenShift?" (press DOWN). Use them only if the audience is new to the vocabulary; otherwise go RIGHT and explain each word as it appears in the demo. One idea per slide. The last column is what you point at later in the demo, so the audience sees every term again.

| # | Term | One-line definition | Where it shows up in the demo |
|---|---|---|---|
| 1 | **Cluster** | Control plane nodes (API, scheduler, etcd) plus worker nodes that run the workloads | Part 4: after scaling, the pods are spread across the worker nodes (the Node field on each pod) |
| 2 | **Node** | A machine (VM or bare metal) that runs pods | Part 2: the "Node" field on a pod |
| 3 | **Container image** | The app plus its dependencies, packaged and immutable. It is stored in a **registry** | Part 3: the pipeline builds one |
| 4 | **Pod** | One or more containers sharing an IP and storage. The smallest unit you run, and disposable | Part 2 |
| 5 | **Deployment** (→ ReplicaSet) | "Keep N copies of this pod template running." A new template means a rolling update | Parts 1, 3, 4, 6, 7 |
| 6 | **Service** | A stable name and virtual IP in front of a changing set of pods | Parts 1 and 3: the guestbook finds `postgresql` by name |
| 7 | **Route** | An external HTTPS URL that forwards to a Service | Part 3: the app URL |
| 8 | **Project** (namespace) | The boundary for names, quotas, network and **RBAC** | Part 5 |
| 9 | **ConfigMap / Secret** | Configuration and credentials, kept outside the image | Parts 1, 3 and 7 |
| 10 | **Pipeline** (Tekton) | Automated steps (clone → build → deploy) that each run in a pod | Parts 3 and 6 |

The demo intro slide is the picture of today's app: **Gitea → Pipeline → image → Deployment (guestbook) → Service → Route**, with the guestbook talking to **PostgreSQL** (Deployment + PVC + Secret).

---

## Part 1 – "It's this simple": deploy PostgreSQL (3 min) · *Browser A*

**Point to make:** the platform team publishes ready-made services. A developer picks one from the catalog and gets a running database in seconds, with everything it needs.

1. Topology for `demo-intro` is empty. *"This is the project the platform team gave me. Empty - but with a catalog."*
2. **+Add → Developer Catalog → Databases → PostgreSQL 15** (provider "Red Hat User Group for FAA") → **Instantiate Template**. *Not* the plain "PostgreSQL" from Red Hat, Inc.: that older template creates a DeploymentConfig.
   - Look at the form: service name `postgresql`, application `guestbook`, a generated user and password, database `guestbook`, 1Gi of storage, version `15-el9`. *"I don't even have to pick a password."*
   - **Create**.
3. Topology: `postgresql` appears inside the **guestbook** application and turns blue within seconds. Click it and walk through what one form created:
   - a **Deployment**, running 1 **pod**;
   - a **Service**, `postgresql:5432`, the name our app will use;
   - a **Secret**, `postgresql`, with the generated credentials (open it and reveal the values: keys `database-user`, `database-password`, `database-name`);
   - a **PersistentVolumeClaim**: 1Gi of storage that outlives the pod.
4. *Optional:* show the template itself: *"this is what the platform team published - parameters plus objects."* Use one of:
   - Bookmark: `https://console-openshift-console.apps.homeocp.ocp4.peterlarsen.org/search/ns/demo-intro?kind=template.openshift.io%7Ev1%7ETemplate&q=published-by%3Dplatform-team` → **postgresql-demo** → **YAML**. That's **Search → Template** filtered on the label `published-by=platform-team`: without the filter, Search also lists all the `openshift` namespace's templates. *"Labels are how you find things - the platform team tags what it publishes."*
   - Or skip it here, and show `oc get template postgresql-demo -o yaml` in the web terminal later.
   - *Needs the OpenShift Virtualization console plugin (`kubevirt-plugin`) disabled:* while it's enabled it takes over every Template page, including Search, and shows only VM templates. `verify.sh` checks this.

Talking points:
- Templates (and Helm charts, and operators) are how a platform team hands out approved building blocks. Everything it created is a normal object you can look at, change or delete.
- **Secrets** (left nav) shows *two* secrets: `postgresql`, which the database uses, and `postgresql-demo-parameters-…`. *"That second one is the console at work: it saves everything I typed into the form, password included, and it stays behind. It's a side effect of using the UI. The same template run from the CLI - `oc new-app --template=postgresql-demo` - or from Ansible or Argo CD leaves no such leftover. The console is great for learning and looking around; for anything real, the definition lives in code."*

*Catch-up:* `steps/01-postgresql.sh`

---

## Part 2 – Containers and pods (4 min) · *Browser A*

**Point to make:** a pod is the smallest unit. It is useful to look at, but on its own it is fragile. Other pods reach it through a **Service** name, not its IP.

1. Topology → `postgresql` → the pod. On the pod page:
   - **Details:** the pod IP, and the **Node** it landed on (tie back to the slide).
   - **Logs:** the database starting up.
   - **Terminal:** run `psql -c '\l'`. You're inside the running container. Run `id`: a random high UID, not root.
   - **Events:** scheduled → volume attached → image pulled → started.
2. A pod on its own: **+Add → Import YAML**, paste `manifests/hello-pod.yaml` → **Create**. *"This is all a pod is: a name and an image."*
3. **The Service, seen from another pod.** On the `hello` pod, open the **Terminal** tab:
   ```bash
   getent hosts postgresql
   # 172.30.x.x  postgresql.demo-intro.svc.cluster.local
   echo > /dev/tcp/postgresql/5432 && echo "postgresql:5432 is reachable"
   ```
   *"Any pod in the project can use the name `postgresql`. It resolves to 172.30…, the Service's stable address, not the database pod's 10.x address we saw on its Details tab, and the connection goes through. The guestbook will use exactly that name in Part 3."*
4. **Actions → Delete Pod** on `hello`. It is gone, and nothing brings it back.
5. Contrast: delete the PostgreSQL pod. A new one appears within seconds, because its **Deployment** replaces it. It has a **new** 10.x IP (Details), while the Service keeps the same 172.30 address. The data survives on the PVC.

*If someone asks about connecting a tool on their desktop:* `oc port-forward svc/postgresql 5432:5432` on the laptop, then point the tool at `localhost:5432`. It needs `oc` on the laptop; the web terminal runs inside the cluster, so it can't forward to your desktop.

*Catch-up:* `steps/02-pod.sh`

---

## Part 3 – From source code to running app (8 min) · *Browser A*

**Point to make:** a non-admin developer goes from a Git URL to a running, routed app, and OpenShift builds it with a visible pipeline.

1. Show the Gitea repo tab briefly: a plain Python app, `app.py`, `VERSION = "1.0"`.
2. **+Add → Import from Git**:
   - **Git Repo URL:** `https://local-gitea-gitea.apps.homeocp.ocp4.peterlarsen.org/ocpdemo/guestbook.git` (the same address as the Gitea tab, plus `.git`).
   - The console reads the repo and detects **Python** on its own (Import Strategy: Builder Image, Python). Keep the version it suggests.
   - **Application:** `guestbook` (the group PostgreSQL is already in). **Name:** `guestbook`. *The name must be `guestbook`: the push trigger in Part 6 starts the pipeline by that name.*
   - **Build option: Pipelines.** Resource type: **Deployment**. Keep **Create a route** checked.
   - **Create**.
3. **Talk through the build (about 90 seconds).** Walk through what the form created, one object at a time; each one is a term from the slides:

   | Time | Click | Say |
   |---|---|---|
   | 0:00 | **Pipelines → guestbook →** the running PipelineRun | "Three steps: fetch the code, build an image, deploy it. Each box is a **pod**, scheduled onto a **node** like any other workload." |
   | 0:20 | **fetch-repository** → Logs | "It cloned from Gitea over the in-cluster **Service** address." |
   | 0:30 | **build** → Logs (pip install scrolling) | "No Dockerfile. The builder image knows Python: it installs the requirements and packages the app as a **container image**, then pushes it to the internal **registry**." |
   | 0:50 | **Topology** → guestbook → **Details** | "The **Deployment** already exists. We declared the state we want: 1 replica of this image. It's waiting for the image to exist." |
   | 1:10 | **Resources** tab → Service, then Route | "The **Service**: a stable name for the pods to come. The **Route**: the public URL, already reserved." |
   | 1:30 | Back to the PipelineRun: **deploy** turns green | "The image landed, the Deployment noticed, and a pod is starting." |

   If the build finishes early, skip the rows you haven't reached. If it runs long, open the **build** logs again: the push to the registry is the last thing it does.
4. Topology: the guestbook ring turns blue. Open the route (the arrow icon). The page loads but shows **"Database unavailable: … password authentication failed"**. The app reached the database through its Service, but it has no credentials yet.
5. **Give the app its credentials: show it in the console, then do it as code.**
   - **Show:** Topology → guestbook → the Deployment name (full page) → **Environment** tab → **Add from ConfigMap or Secret**. Fill in *one* row: name `POSTGRESQL_USER` → secret `postgresql` → key `database-user`. *"The name is what the app reads, the key is where the Secret keeps it - and they don't have to match."*
   - **Stop there** (**Reload**, don't save): *"Three rows for one database. Now picture twenty variables across dev, test and prod, clicked in by hand every time. This is where the console stops being the right tool."*
   - **Tell:** in the web terminal:
     ```bash
     cat guestbook-db-env.patch.yaml    # three names, three keys, one Secret
     oc patch deployment/guestbook --patch-file=guestbook-db-env.patch.yaml
     ```
     *"That file goes into Git next to the code, gets reviewed, and is the same in every environment."* Changing the pod template **rolls out a new pod**: watch Topology.
6. Refresh the app. It works. **Sign the guestbook**, or ask the audience to sign it from their phones.

Talking points:
- The guestbook connects to `postgresql:5432`: the **Service** name from Part 1, not a pod IP.
- *"Environment variables keep it simple for today. In production you'd mount credentials as files, or pull them from a vault with something like the External Secrets Operator. The idea is the same: credentials live outside the image."*

*Catch-up:* `steps/03-import-from-git.sh`. It creates the same pipeline, Deployment, Service and Route, runs the first build, and applies the credentials patch.

---

## Part 4 – Self-healing, health checks and scaling (8 min) · *Browser A* + laptop terminal

**Point to make:** you declare the state you want, and OpenShift keeps it true - including how many pods, depending on load.

1. Topology → guestbook → **Actions → Add Health Checks**:
   - **Readiness:** HTTP GET `/readyz`, port 8080. *"Only send traffic once the pod can reach the database."*
   - **Liveness:** HTTP GET `/healthz`, port 8080, initial delay 10. *"Restart the container if the process hangs."*
   - **Add** (this is another rollout).
2. Delete the guestbook pod. The ring shows the replacement starting straight away.
3. **Details** tab → the **up arrow** → 3 pods. Open the Service's pods: three endpoints behind one name, and each pod's **Node** shows they landed on different workers. *"The scheduler spreads them, so one machine failing doesn't take the app down."*
4. Refresh the app: "served by pod" doesn't change. *Sticky sessions, in 10 seconds:* "The router sets a cookie, so your browser keeps hitting the same pod. That's good for apps that keep session state in memory. Ours keeps everything in the database, so any pod can answer." Switch the route to round robin, again as code:
   ```bash
   cat guestbook-route-roundrobin.patch.yaml
   oc patch route/guestbook --patch-file=guestbook-route-roundrobin.patch.yaml
   ```
   Refresh in a new private window a few times: the pod name changes. Sign the book again: each entry records which pod wrote it, but they all share one database.
5. **Autoscaling needs a CPU request.** In the terminal:
   ```bash
   oc set resources deployment/guestbook --requests=cpu=50m,memory=320Mi --limits=memory=512Mi
   ```
   *"The autoscaler measures CPU as a percentage of what the pod asked for, so it needs a request."* Another rollout. The same fields are in the console under the Deployment's **Actions → Edit resource limits**. (No CPU limit: it isn't needed for the demo, and a tight one slows the app under load.)
6. **Add the autoscaler in the console:** Topology → guestbook → **Actions → Add HorizontalPodAutoscaler**: minimum **2**, maximum **6**, CPU utilization **50%** → **Save**. *"From now on the autoscaler owns the replica count: my manual 3 will drop to 2."* Then the same as code, which can say more than the form:
   ```bash
   oc apply -f guestbook-hpa.yaml         # adds a 1-minute scale-down window (default: 5 minutes)
   ```
7. **Load.** In the laptop terminal:
   ```bash
   ab -k -c 10 -t 120 https://guestbook-demo-intro.apps.homeocp.ocp4.peterlarsen.org/
   ```
   and `oc get hpa guestbook -w` in a second terminal, with Topology on screen. CPU jumps far above 50%, and within about 30 seconds the ring grows from 2 to 6 pods. When `ab` stops after 2 minutes, CPU drops, and about a minute later the Deployment is back to 2.
   - Keep `-c` at **10**. With 50 concurrent requests, the health checks queue behind the load, the pods turn Not Ready, and the autoscaler ignores them (it shows `<unknown>`) until the load is over.

*Catch-up:* `steps/04-scale.sh`

---

## Part 5 – Projects and RBAC (4 min) · *Browsers B and C*

**Point to make:** everything so far happened in a project, as a developer with the `edit` role. The admin decides who can see or change what in each project.

1. **Browser C (peter, Developer perspective):** **Project** (left nav) → **Project access** tab: peter is `admin`, user1 is `edit`, user2 is `view`, and the `pipeline` **service account** has `edit` too. *"Roles aren't only for people: the pipeline runs under its own identity."* Only the admin sees this tab. *"These are project roles. There are also cluster-wide roles, for the platform team that runs the cluster itself - not today's topic."*
2. **Browser B (user2, view):** the same Topology, the same app, but read-only:
   - the guestbook's scale arrows are missing;
   - **Secrets** (left nav): access denied, so user2 can't read the database password;
   - Actions to edit or delete aren't available.

Talking points: roles are standard (`admin`, `edit`, `view`) and bound per project. user2 could be an auditor, or a team that depends on this app. RBAC is per project, so user1 could be `admin` in their own sandbox and `view` in production.

*Catch-up:* `steps/05-rbac.sh` (read-only; prints a can-i matrix)

---

## Part 6 – A commit becomes a new version (5 min) · *Gitea tab + Browser A*

**Point to make:** a commit becomes a rolling update, with no tickets and no manual redeploy.

1. **Give the pipeline an ear: the EventListener.** **+Add → Import YAML**, paste `manifests/guestbook-eventlistener.yaml` → **Create**. `el-guestbook` appears in Topology. *"This is the endpoint Gitea calls on every push. It checks the webhook's secret and starts our pipeline. It's part of OpenShift Pipelines (Tekton Triggers), and it's just another Deployment."* Wait until its ring is blue (about 15 seconds).
   (Gitea's webhook, and the template the listener runs, were staged beforehand. In Gitea, **Settings → Webhooks** shows where the push goes.)
2. In Gitea: open `app.py` → **Edit** (the pencil icon) → change `VERSION = "1.0"` to `VERSION = "2.0"` → commit to `main`.
3. **Pipelines**: a new PipelineRun has **started by itself**: Gitea's webhook called `el-guestbook`, which started the run. Open it: clone → build → deploy again.
4. Watch Topology while the build finishes: new pods come up, and old ones drain only after the new ones pass the readiness check from Part 4.
5. Refresh the app: the badge reads **v2.0**, and the guestbook entries are all still there, because the data is in PostgreSQL.

If the pipeline doesn't start within about 10 seconds, check that `el-guestbook` is running (blue ring). Otherwise go to **Pipelines → guestbook → Actions → Start** (the defaults build `main`), and check Gitea → repo **Settings → Webhooks → Recent deliveries** afterwards.

*Catch-up:* `steps/06-new-version.sh` (creates the EventListener if it's missing, commits through the Gitea API, then waits for the pipeline and the rollout)

---

## Part 7 – Configuration and rollback (3 min) · *Browser A*

**Point to make:** configuration is part of the Deployment too, and every revision is kept.

1. Topology → guestbook → the Deployment name (full page) → **Environment** → **Add more**: `APP_COLOR` = `#0066cc`, `APP_TITLE` = `Guestbook - config change` → **Save**.
2. Refresh the app: the banner is blue. A config change is a rollout too, with no rebuild.
3. **ReplicaSets** tab: one ReplicaSet per revision.
4. Roll back, in the web terminal:
   ```bash
   oc rollout undo deployment/guestbook
   ```
   Refresh: it is back to the red v2.0. (Environment variables roll out automatically; a ConfigMap change would not, which is one reason we use env here.)

*Catch-up:* `steps/07-config-rollback.sh`

---

## Wrap-up (1 min)

Go back to the architecture picture and point at each box: you touched every one of them.
- **Catalog:** a database in one form, with its Secret, Service and storage.
- **Pod → Deployment:** declare the state you want, and OpenShift keeps it true.
- **Service and Route:** stable names inside the cluster, HTTPS outside.
- **Pipeline:** a commit becomes an image, and the image becomes a rolling update. Config changes are rollouts too.
- **Project and RBAC:** who can do what, per team.
- Next demo: the developer inner loop with Dev Spaces.

## After the demo

```bash
./reset.sh      # ready to present again: deletes the project, re-runs setup, Git repo back to v1.0
./teardown.sh   # removes the project and the Gitea repo
```

## If something goes wrong

| Symptom | Fix |
|---|---|
| PostgreSQL isn't in the Developer Catalog | The template wasn't staged: run `./setup.sh` (or `./verify.sh` to see what's missing) |
| The fetch-repository task fails with a TLS or certificate error | The TektonConfig CA patch is missing (it makes git in task pods trust the route's certificate): re-run `ansible-playbook faa-demo/playbook.yml`. Fallback: `http://local-gitea.gitea.svc:3000/ocpdemo/guestbook.git` |
| Import from Git says "The Gitea repository is unreachable" | Expected with the in-cluster Service URL (the browser does the check). With the public URL, the Gitea route's CORS header is missing: re-run the playbook, or pick **Builder Image → Python** by hand |
| The app shows "Database unavailable … password authentication failed" | Expected until the credentials patch in Part 3, step 5 |
| The app shows "Database unavailable … could not translate host name" | PostgreSQL from Part 1 is missing: run `steps/01-postgresql.sh` |
| The pipeline's build task fails on pip | The build needs outbound access to PyPI. Rerun it (**Actions → Rerun**) |
| A commit doesn't start a pipeline | Is `el-guestbook` running? Is the pipeline named `guestbook`? Check Gitea **Settings → Webhooks → Recent deliveries**, then `oc logs deploy/el-guestbook`. Start the run by hand with **Actions → Start** |
| The browser always shows the same pod | The route patch from Part 4 is missing, or the browser kept a cookie (use a new private window) |
| user1 or user2 cannot log in | `../common/login-users.sh user1 user2` (the password is in `common/env.sh`) |
| The state is messed up mid-demo | Run that section's catch-up script. Each one is safe to re-run |
