# Demo 3 – Resource Management: presenter script (outline)

**Status:** automation and manifests done; every CLI command in the cheat-sheet was run against the cluster as the user it names (2026-11-16). Console clicks not yet rehearsed: Parts 1 and 5 and the bonus are still marked DRAFT in the notes. See "Still to do".

## Running it

From the repo root (the venv and collections as in the root CLAUDE.md):

| Playbook | What it does | Time |
|---|---|---|
| `setup.yml` | Project `demo-resources` and roles; PostgreSQL from demo 1's `postgresql-demo` template; the guestbook image, built once by a pipeline from Gitea `ocpdemo/guestbook` (demo 1's source - run `demo1-fundamentals/setup.sh` first if Gitea doesn't have it); the guestbook with **no** requests or limits; VM `small-vm`, stopped. Safe to re-run: never undoes a run in progress. | ~4 min first time |
| `verify.yml` | Read-only: the start state, nothing left from a run, pod metrics, `ab` on the laptop. | seconds |
| `reset.yml` | In place, after a rehearsal or a session: removes quota, limit range, HPA, `memory-hog`, `no-requests`, `big-claim`; stops the VM; puts the guestbook back (2 pods, no resources). Keeps the image and the database. | ~1 min |
| `traffic.yml -e traffic=off` / `on` | Pauses / resumes the background traffic (below). | seconds |
| `teardown.yml` | Deletes the project (image, database, VM and all) and the traffic project. Nothing else is changed. | ~1 min |

**Background traffic.** Cost Management can only recommend sizes from real usage, and an idle guestbook gives it a flat line. Setup adds CronJob `guestbook-traffic` in its own project `demo-resources-traffic` (so it never counts against the Part 4 quota or shows in Topology): every hour at :17, 5 minutes of requests to the guestbook Service - 6 threads on weekdays 13-22 UTC (~1.5 cores per guestbook pod), 1 thread otherwise. It also shows in Parts 1 and 6, so:

- **Before a session:** `traffic.yml -e traffic=off` (also stops a run in progress) - `verify.yml` fails until it's paused.
- **After the session:** `reset.yml`, then `traffic.yml -e traffic=on`.

Then `common/workspace.sh demo3-resources` shortly before presenting (user tokens expire).

**Length:** aim for about 34 minutes: up to 8 minutes of slides, then about 26 minutes of live demo, mostly in the console. Part 7 and the bonus are the first to drop if it runs long.
**Audience:** operations. **Takeaway:** the scheduler counts reservations, the kernel enforces ceilings. Size from measurements (requests), cap memory (limits), budget each project (quotas and limit ranges), and answer load with more copies, not bigger pods. VMs follow the same rules.

Most of this is upstream Kubernetes; the session calls it OpenShift throughout.

---

## The app: the guestbook from demo 1

The same Python/Flask guestbook and PostgreSQL as in demo 1, in a project of its own. It's deployed by setup (no Import from Git, no live build) and **with no requests or limits**, the way many applications arrive. Every page shows the version and the serving pod, so scale-out under load is visible in the browser.

| Workload | Starts as | Used in |
|---|---|---|
| Deployment `guestbook` (2 pods) | no resources: BestEffort | 1, 2, 3, 4, 6 |
| Deployment `postgresql` + PVC `postgresql` | from the `postgresql-demo` template (it sets a small request and limit) | 5 |
| Pod `memory-hog` | 128Mi limit, allocates 16 MiB every 0.5 s | 3 |
| VM `small-vm` (Fedora container disk, no PVC) | 2 vCPU, 2 GiB, **stopped** until Part 7 | 7 |

Measured (rehearsal, 2026-11-16): the guestbook idles at ~2m CPU and ~290Mi per pod; under `ab -c 10` with no limits each pod takes ~3 cores. Hence Part 2's 50m / 320Mi / 512Mi (as in demo 1).

The quota (`project-quota.yaml`) is sized so the HPA's 6 guestbook pods + PostgreSQL + the VM fit, and 10 guestbook pods don't: the limit that bites is `pods: 8`. Memory alone can't do both, because the VM's request (2324Mi) is bigger than the gap.

## Identities

| Who | Perspective | Used for |
|---|---|---|
| `peter` (admin) | Administrator | Dashboards, nodes, metrics queries, LimitRange and ResourceQuota, storage capacity, VM, project template (Parts 1, 3, 4, 5, 7, bonus) |
| `user3` (edit) | Developer | Sizing the guestbook, hitting the limits and the quota, HPA (Parts 1–6). Can't list nodes, create a LimitRange/ResourceQuota or start a VM - all three are worth saying out loud. |
| `user2` (view) | – | Not used |

## Slides (≤ 8 min)

1. Title, Who we are, What to expect, What we will cover today (plain words, mirrors the wrap-up).
2. **From servers to OpenShift**: the mapping slide for VM admins (reserved physical CPU and memory → requests, configured vCPU and memory → limits, hypervisor overcommit → the room between request and limit, budgets → quotas, top/sar/df → Prometheus, resize the VM → autoscaling). Optional concept slides below it (DOWN): Requests, Limits, CPU bends / memory breaks, Quality of service, Quotas & limit ranges, Scale out not up, Virtual machines too.
3. **Live demo: today's setup**: the guestbook, the project's guardrails, what's around it.

## Demo (≈ 26 min)

| Part | Time | Point to make | Where |
|---|---|---|---|
| 1 · Used vs reserved | 3 min | Without requests a pod is BestEffort and the scheduler knows nothing about it. Usage and reservations are different numbers. | Pod details (QoS), Observe → Dashboards → *Compute Resources / Namespace (Pods)*, Compute → Nodes, `oc describe node` |
| 2 · Requests and limits, the right way | 5 min | Requests from measurements, a memory limit, no CPU limit. The console form takes one value per resource (request = limit), so it's shown and cancelled; the change is the patch file. A request that fits nowhere stays Pending, even on idle nodes. | Actions → Edit resource limits (look only); `oc patch`; FailedScheduling event; `oc rollout undo` |
| 3 · Hitting the ceiling | 4 min | Memory over the limit: OOMKilled (137). CPU over the limit: throttled, not killed. That's why CPU overcommits safely and memory doesn't. | `memory-hog` pod; CPU limit + `ab` load; throttling metric |
| 4 · A budget for each project | 5 min | ResourceQuota caps the project (CPU, memory, pods, storage); LimitRange fills in defaults. Over-budget pods are refused at creation; running ones are untouched. | Administration → ResourceQuotas; scale to 10; `no-requests` pod; `big-claim` |
| 5 · How much storage is left? | 3 min | Two levels of "free": inside the claim, and in the storage system behind it (thin provisioning). Quota is the third view. Details: the storage session. | PVC page, `df`, `kubelet_volume_stats_available_bytes`, Data Foundation overview |
| 6 · Right-sizing | 4 min | HPA adds pods under load and removes them after: don't build one big pod. For the size itself, mention (no demo) the VPA in recommend-only mode and Cost Management across clusters with cost. | HPA + `ab`; console.redhat.com backup slide |
| 7 · Virtual machines | 2 min | A VM is a virt-launcher pod: CPU request 1/10 per vCPU (200m, overcommitted by default), memory = guest + overhead (2324Mi). With a `limits.memory` quota, OpenShift Virtualization adds a memory limit itself (2× the request). Same scheduler, same quota. | Start `small-vm` (console or `virtctl`), `oc get vm,vmi`, the pod's resources, the quota |
| Bonus · New project defaults | – | The project request template can give every new project a LimitRange and quota. Show only: it's cluster-wide. | `oc adm create-bootstrap-project-template` |

The speaker notes on each demo slide have the clicks and commands (marked DRAFT until rehearsed). `cheatsheet.sh` has the same commands by part (`cheat 4`).

## Gotchas found in rehearsal

- `oc get events ... | tail` picks the wrong lines: new-style events have no `lastTimestamp`. Use `--sort-by=.eventTime`.
- After scaling back from 10 to 2, terminating pods still count against `pods: 8`: wait for `oc get pods` to show 3 before `no-requests-pod.yaml`, or it's refused.
- `ab` reports most requests as "Failed (Length)" with a CPU limit: not errors, the pages differ by pod name. The real ones are the few "Non-2xx" (router timeouts).
- The LimitRange admission caches LimitRanges for up to 30 s after a delete: `reset.yml` waits, or the "no resources" guestbook comes back Burstable.
- The OpenShift Virtualization console plugin is currently **enabled**. Demo 3 doesn't mind (and Part 7 uses its pages); demo 1's `verify.sh` fails until it's disabled again (it hides the `postgresql-demo` template there).

## Still to do

- [ ] Presentation date on the title slide.
- [ ] Rehearse the console side (Parts 1 and 5, the bonus are still DRAFT; check the Part 2 form wording and the Part 1 dashboard name on this release).
- [X] Cost Management: install the Cost Management Metrics Operator so console.redhat.com has days of data (or seed it) before the session, then take the backup screenshot.
- [x] Cost Management source registered (integration `homeocpdemo`), first upload 2026-11-16 16:13 UTC. The CostManagementMetricsConfig's `spec.source.name` must match the integration's name: left empty, the operator looks for a source named after the cluster ID and keeps reporting "no source" (and only re-checks every `check_cycle` minutes, default 1440).
- [ ] Cost Management: wait for the recommendations (from ~2026-11-17), then take the backup screenshot. Setup labels `demo-resources` with `cost_management_optimizations=true` (without it, no optimization data). Recommendations need ~24 h of data after the first upload (every 6 h); verify.yml checks all of it. Don't run teardown.yml in between - a new project starts the data over.
- [ ] Console screenshots for the backup slides (`images/demo3-<part>-<what>.webp`, lossless WebP).
- [ ] Time a full run (target ~34 min).
