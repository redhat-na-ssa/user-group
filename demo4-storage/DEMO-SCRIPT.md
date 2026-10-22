# Demo 4 – OpenShift Storage: presenter script

**Length:** about 35 minutes: up to 8 minutes of slides, then about 25 minutes of live demo, mostly in the console.
**Audience:** operations. **Takeaway:** pods are disposable, claims are not. Developers ask for storage and the platform provides it. ODF adds the visibility (dashboards, alerts) and the data services (snapshots, expansion, object storage). Snapshots undo mistakes; backups recover projects.

The speaker notes on each demo slide have the exact clicks and commands. `cheatsheet.sh` has the same commands by part (`cheat 3`).

---

## The app: a "logbook"

The application itself doesn't matter, so there's no source code and no build. Every pod runs the stock `ubi9/python-312` image with a two-line command. It appends `HH:MM:SS  <pod>  on  <node>` to `/data/logbook.txt` every 5 seconds and serves `/data` over HTTP. Opening `https://<route>/logbook.txt` in the browser shows who wrote what, and whether the history survived. It runs in three shapes:

| Workload | Storage | Shows | Parts |
|---|---|---|---|
| Deployment `logbook` (1 pod, strategy Recreate) | `emptyDir`, then PVC `logbook-data` (ceph-rbd, RWO) | ephemeral vs persistent, expansion, snapshot restore | 1, 2, 6, 7 |
| Deployment `logbook-rwo` (3 pods, anti-affinity) | one RWO PVC | Multi-Attach error: RWO is one *node* | 3 |
| DaemonSet `logbook-rwx` (a pod per worker) | one RWX PVC `logbook-shared` (cephfs) | every node writes to the same file | 3 |
| StatefulSet `logbook-sts` (3 replicas) | `volumeClaimTemplates`, giving `data-logbook-sts-0/1/2` | a disk per replica, stable identity | 4 |

Why both a DaemonSet and a StatefulSet: the DaemonSet guarantees a pod on *every* node, which is the clearest picture of RWX. The StatefulSet is how RWO storage scales correctly (databases, Kafka).

## Identities

| Who | Perspective | Used for |
|---|---|---|
| `peter` (admin) | Administrator | Storage classes, PVs, ODF dashboard, alert rules, OADP (Parts 2, 5, 8) |
| `user1` (edit + `monitoring-rules-edit`) | Developer and Administrator | Creating the apps, claims, alert rule and snapshots (Parts 1–4, 6, 7). Shows that `oc get pv` is Forbidden for a developer |
| `user2` (view) | – | Not used in this demo |

This is an ops session, so the console is mostly in the **Administrator** perspective: storage pages live there. The Developer perspective is used for Topology and the project's Observe → Alerts.

## Cluster prerequisites (setup automation, still to be written as Ansible)

- **OpenShift Data Foundation**, internal mode: storage classes `ocs-storagecluster-ceph-rbd` (default), `ocs-storagecluster-cephfs` and `openshift-storage.noobaa.io`; snapshot classes `ocs-storagecluster-rbdplugin-snapclass` and `-cephfsplugin-snapclass`.
- **User workload monitoring** enabled (`cluster-monitoring-config`: `enableUserWorkload: true`). This is a cluster-wide setting.
- **OADP operator** in `openshift-adp`, with an ObjectBucketClaim on NooBaa and a DataProtectionApplication: Velero with the `openshift` and `csi` plugins, node agent enabled (data mover), and the default BackupStorageLocation on that bucket.
- Project `demo-storage`: user1 `edit` + `monitoring-rules-edit`, user2 `view`, and `manifests/logbook-ephemeral.yaml` applied (the demo starts with the ephemeral logbook running).
- **Reset** must also: delete project `demo-storage-restore`, the Backup and Restore `demo-storage` in `openshift-adp` (a `DeleteBackupRequest`, so the bucket data goes too), and any leftover VolumeSnapshots.
- **Verify:** ODF `HEALTH_OK`, the BSL `Available`, the logbook Route answers, there are at least 3 schedulable workers (Part 3 needs 3 nodes for the anti-affinity) and no `VolumeAlmostFull` alert is firing.

---

## Slides (≤ 8 min)

Going RIGHT: **title** → **Who we are** → **What to expect** → **What we will cover today** → **Persistent storage in OpenShift** (one diagram: Pod → PVC → StorageClass → CSI → storage, PV bound back) → **Live demo: today's setup** → the demo parts.

Concept slides sit DOWN under "Persistent storage in OpenShift". Use them only if the audience needs them: Ephemeral by default · PV & PVC · StorageClass · Access modes · CSI · Local storage (why to avoid it) · Object storage · Snapshot ≠ backup · OpenShift Data Foundation.

## Demo (≈ 25 min)

| Part | Time | Who | What happens |
|---|---|---|---|
| 1 · Ephemeral by default | 2 min | user1 | Open the logbook, show the `emptyDir`, delete the pod, and the history is gone |
| 2 · Ask for storage: a PVC | 4 min | peter, user1 | StorageClasses (the menu). Create PVC `logbook-data` in the console, it's Bound, and a PV appears. `oc get pv` is Forbidden for user1. Swap the volume with `oc set volume`, delete the pod, and the history stays |
| 3 · RWO vs RWX | 4 min | user1 | `logbook-rwo`: 1 Running, 2 stuck on a Multi-Attach error. Delete it. `logbook-rwx` DaemonSet on CephFS: all nodes, one file |
| 4 · StatefulSet | 3 min | user1 | 3 pods, 3 claims. Delete `logbook-sts-1`: same name, same disk. Scale down: the claims stay. **Then start the fill for Part 6** |
| 5 · What ODF adds | 4 min | peter | Data Foundation dashboard (health, capacity, performance, consumers), Object tab, the PVC's usage graph, alert rules shipped by ODF. DOWN: "Any CSI driver vs ODF" table |
| 6 · A volume fills up | 3 min | user1 | `VolumeAlmostFull` fires. Expand PVC to 2 GiB online, `df` shows it, the alert resolves. Remove the ballast |
| 7 · Snapshots | 3 min | user1 | Create a snapshot, "oops" `rm`, restore as a new PVC, `oc set volume`, and the history is back |
| 8 · OADP | 4 min | peter | Backup `demo-storage` to the ODF bucket, restore as `demo-storage-restore`, open the restored logbook |

Then **When storage goes wrong** (1 min, a diagnostics checklist built from what was just seen), **What we just did**, and **Q&A**.

**Timing risks:**
- The alert in Part 6 needs about 2–3 minutes: kubelet volume stats are scraped about once a minute, plus `for: 1m`. That's why the fill starts at the end of Part 4 and runs while the ODF dashboard is shown.
- The OADP backup with data mover takes a minute or two, and the restore about as long. If time is short, show a backup taken during rehearsal and only start the restore live.

## Still to do

- [ ] Ansible: `setup.yml` / `verify.yml` / `reset.yml` / `teardown.yml` for the prerequisites above (and the `collections -> ../collections` symlink).
- [ ] Check on the cluster: ODF installed and its class names; the console's PVC form and the StorageClass list as user1; that a user-namespace PrometheusRule can use `kubelet_volume_stats_*` (Thanos Ruler should allow it); OADP data mover restore into a mapped namespace (route hosts are regenerated).
- [ ] Rehearse and take the backup screenshots (the deck shows placeholders with the expected file names, `images/demo4-*.webp`).
- [ ] Set the session date on the title slide, and "See you next time" on Q&A once the next topic is set.
