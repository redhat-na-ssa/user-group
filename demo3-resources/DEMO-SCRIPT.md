# Demo 3 – Resource Management: presenter script (outline)

**Status:** outline. The deck (`slides/index.html`) has every slide with draft speaker notes and commands; the cheat-sheet has the same commands by part. No automation or manifests yet; see "Still to do".

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
| Pod `memory-hog` | 128Mi limit, allocates in a loop | 3 |
| A small VM | 2 vCPU, 4 GiB | 7 |

## Identities

| Who | Perspective | Used for |
|---|---|---|
| `peter` (admin) | Administrator | Dashboards, nodes, metrics queries, LimitRange and ResourceQuota, storage capacity, VM, project template (Parts 1, 3, 4, 5, 7, bonus) |
| `user1` (edit) | Developer | Sizing the guestbook, hitting the limits and the quota, HPA (Parts 1–6) |
| `user2` (view) | – | Not used |

## Slides (≤ 8 min)

1. Title, Who we are, What to expect, What we will cover today (plain words, mirrors the wrap-up).
2. **From servers to OpenShift**: the mapping slide for VM admins (reserved physical CPU and memory → requests, configured vCPU and memory → limits, hypervisor overcommit → the room between request and limit, budgets → quotas, top/sar/df → Prometheus, resize the VM → autoscaling). Optional concept slides below it (DOWN): Requests, Limits, CPU bends / memory breaks, Quality of service, Quotas & limit ranges, Scale out not up, Virtual machines too.
3. **Live demo: today's setup**: the guestbook, the project's guardrails, what's around it.

## Demo (≈ 26 min)

| Part | Time | Point to make | Where |
|---|---|---|---|
| 1 · Used vs reserved | 3 min | Without requests a pod is BestEffort and the scheduler knows nothing about it. Usage and reservations are different numbers. | Pod details (QoS), Observe → Dashboards → *Compute Resources / Namespace (Pods)*, Compute → Nodes, `oc describe node` |
| 2 · Requests and limits, the right way | 5 min | Requests from measurements, a memory limit, no CPU limit. Show it once in the form, then as a patch file. A request that fits nowhere stays Pending, even on idle nodes. | Actions → Edit resource limits; `oc patch`; FailedScheduling event; `oc rollout undo` |
| 3 · Hitting the ceiling | 4 min | Memory over the limit: OOMKilled (137). CPU over the limit: throttled, not killed. That's why CPU overcommits safely and memory doesn't. | `memory-hog` pod; CPU limit + `ab` load; throttling metric |
| 4 · A budget for each project | 5 min | ResourceQuota caps the project (CPU, memory, pods, storage); LimitRange fills in defaults. Over-budget pods are refused at creation; running ones are untouched. | Administration → ResourceQuotas; scale to 10; `no-requests` pod; `big-claim` |
| 5 · How much storage is left? | 3 min | Two levels of "free": inside the claim, and in the storage system behind it (thin provisioning). Quota is the third view. Details: the storage session. | PVC page, `df`, `kubelet_volume_stats_available_bytes`, Data Foundation overview |
| 6 · Right-sizing | 4 min | HPA adds pods under load and removes them after: don't build one big pod. For the size itself, mention (no demo) the VPA in recommend-only mode and Cost Management across clusters with cost. | HPA + `ab`; console.redhat.com backup slide |
| 7 · Virtual machines | 2 min | A VM is a virt-launcher pod: CPU request a fraction per vCPU (overcommitted by default), memory = guest + overhead. Same scheduler, same quota. | `oc get vm,vmi`, the pod's resources |
| Bonus · New project defaults | – | The project request template can give every new project a LimitRange and quota. Show only: it's cluster-wide. | `oc adm create-bootstrap-project-template` |

The speaker notes on each demo slide have the clicks and commands (marked DRAFT until rehearsed). `cheatsheet.sh` has the same commands by part (`cheat 4`).

## Still to do

- [ ] Presentation date on the title slide.
- [ ] Automation (Ansible, like demo 4): `setup.yml`, `verify.yml`, `reset.yml`, `teardown.yml`, `tasks/settings.yml` reading `demo.env`, and the `collections -> ../collections` symlink. Setup creates project `demo-resources`, rolebindings (user1 edit, user2 view), the `postgresql-demo` template and instance, and the guestbook **without resources**. Decide where the guestbook image comes from: a pipeline run from Gitea `ocpdemo/guestbook` in this project, or an image built once and pushed to the registry.
- [ ] Manifests: `guestbook-resources.patch.yaml`, `memory-hog.yaml`, `project-limits.yaml`, `project-quota.yaml`, `no-requests-pod.yaml`, `big-claim.yaml`, `guestbook-hpa.yaml` (copy of demo 1's, namespace changed). Then add them to the deck's `files` list in `faa-demo/playbook.yml` and to the download loop in `cheatsheet.sh`.
- [ ] Measure the guestbook's real CPU and memory use and set the Part 2 values and the quota numbers from it (demo 1 uses 50m / 320Mi / 512Mi). The quota must leave room for 2 guestbook pods + PostgreSQL + HPA headroom (6 pods), but not for 10 guestbook pods.
- [ ] Cost Management: is the cluster connected to console.redhat.com with the Cost Management Metrics Operator? Recommendations need days of data, so connect it well before the session and take the backup screenshot from there.
- [ ] Part 7: OpenShift Virtualization is installed, but the kubevirt-plugin console plugin is disabled (demo 1 needs that). Either show Part 7 from the CLI only, or enable the plugin for this demo and disable it again afterwards. Decide where the VM comes from (setup creates a small one in `demo-resources`?) and check the CPU allocation ratio and memory overhead numbers on this release.
- [ ] Throttling: check that the `container_cpu_cfs_throttled_periods_total` query shows clearly at `ab -c 10` with a 100m limit.
- [ ] Console screenshots for the backup slides (`images/demo3-<part>-<what>.webp`, lossless WebP).
- [ ] Rehearse and time it.
