# Demo 4 – OpenShift Storage: presenter script

**Length:** about 36 minutes: up to 8 minutes of slides, then about 28 minutes of live demo, mostly in the console. That's over the 30-minute aim but under 40. If it runs long, show Part 9 (OADP) with a backup taken during rehearsal.
**Audience:** operations. **Takeaway:** pods are disposable, claims are not. Developers ask for storage; the platform provides it, either from a shelf of pre-made volumes (static NFS) or made to measure (dynamic, ODF). ODF adds the visibility (dashboards, alerts) and the data services (snapshots, expansion, object storage). Snapshots undo mistakes; backups recover projects.

The speaker notes on each demo slide have the exact clicks and commands. `cheatsheet.sh` has the same commands by part (`cheat 4`).

---

## The app: a "logbook"

The application itself doesn't matter, so there's no source code and no build. Every pod runs the stock `ubi9/python-312` image with a two-line command. It appends `HH:MM:SS  <pod>  on  <node>` to `/data/logbook.txt` every 5 seconds and serves `/data` over HTTP. Opening `https://<route>/logbook.txt` in the browser shows who wrote what, and whether the history survived. It runs in three shapes:

| Workload | Storage | Shows | Parts |
|---|---|---|---|
| Deployment `logbook` (1 pod, strategy Recreate) | `emptyDir`, then static NFS PVC `nfs-claim`, then PVC `logbook-data` (ceph-rbd, RWO) | ephemeral vs persistent, static vs dynamic, expansion, snapshot restore | 1, 2, 3, 7, 8 |
| Deployment `logbook-rwo` (3 pods, anti-affinity) | one RWO PVC | Multi-Attach error: RWO is one *node* | 4 |
| DaemonSet `logbook-rwx` (a pod per worker) | one RWX PVC `logbook-shared` (cephfs) | every node writes to the same file | 4 |
| StatefulSet `logbook-sts` (3 replicas) | `volumeClaimTemplates`, giving `data-logbook-sts-0/1/2` | a disk per replica, stable identity | 5 |

Why both a DaemonSet and a StatefulSet: the DaemonSet guarantees a pod on *every* node, which is the clearest picture of RWX. The StatefulSet is how RWO storage scales correctly (databases, Kafka).

## Identities

| Who | Perspective | Used for |
|---|---|---|
| `peter` (admin) | Administrator | Storage classes, PVs (the NFS shelf), ODF dashboard, alert rules, OADP (Parts 2, 3, 6, 9) |
| `user1` (edit + `monitoring-rules-edit`) | Developer and Administrator | Creating the apps, claims, alert rule and snapshots (Parts 1–5, 7, 8). Shows that `oc get pv` is Forbidden for a developer |
| `user2` (view) | – | Not used in this demo |

This is an ops session, so the console is mostly in the **Administrator** perspective: storage pages live there. The Developer perspective is used for Topology and the project's Observe → Alerts.

## Hands off ODF

ODF on the demo cluster is shared and already installed. **The demo and its automation never change the cluster-wide ODF configuration.** That covers the StorageCluster, StorageClasses (including which class is the default, `allowVolumeExpansion` and encryption), VolumeSnapshotClasses, Ceph pools, the NooBaa system and anything else in `openshift-storage`. The demo only *uses* ODF, the way any application would: PVCs, VolumeSnapshots and an ObjectBucketClaim in the demo's own namespaces. In the ODF console pages (Part 6), only look; never use Edit, Add Capacity or Create StorageClass.

Setup and verify only **list** the ODF classes (by provisioner, not by assumed name) and check that what the demo needs is there:

| Demo needs | Found by | Expected (ODF default name) |
|---|---|---|
| Block, RWO, `allowVolumeExpansion: true` | provisioner `openshift-storage.rbd.csi.ceph.com` | `ocs-storagecluster-ceph-rbd` |
| File, RWX | provisioner `openshift-storage.cephfs.csi.ceph.com` | `ocs-storagecluster-cephfs` |
| Buckets | provisioner `openshift-storage.noobaa.io/obc` | `openshift-storage.noobaa.io` |
| Block snapshots | driver `openshift-storage.rbd.csi.ceph.com` | `ocs-storagecluster-rbdplugin-snapclass` |

Checked on the demo cluster on 2026-10-22 (read-only): ODF 4.22.6, `HEALTH_OK`, and all four match the default names. `ocs-storagecluster-ceph-rbd` is the cluster default and allows expansion, and so does cephfs. The cluster also has `ocs-storagecluster-ceph-rbd-virtualization` (used by OpenShift Virtualization), `ocs-storagecluster-ceph-rgw` (S3 through the Ceph object gateway) and `local-volume` (`kubernetes.io/no-provisioner`, a real example for the "Local storage" slide). The demo doesn't use those three.

The manifests use the default names. If verify finds different names, the names in the manifests change, never the cluster. If the block class doesn't allow expansion, Part 7 drops the "Expand PVC" step and only shows the alert. Which class is the cluster default is whatever it is today, so the manifests always name their class explicitly.

## The NFS export (Part 2)

Part 2 shows static provisioning with no storage system behind it: an admin made ten volumes in advance, and a claim takes one. They live on the lab file server `cloud.peterlarsen.org`, which doesn't serve anything to OpenShift yet. The cluster doesn't use NFS today. ODF ships an NFS driver, but switching it on would change ODF, so that's ruled out.

**The network path.** For now the PVs use the server's routed 1 Gbps interface, `cloud.peterlarsen.org` (192.168.11.45). The nodes reach it from the machine network (192.168.11.81–.86), and so does the presenter's laptop (192.168.12.0/24), which makes the setup easy to check. The existing export allows any host (`*`). Only port 2049 is open, so it's NFS version 4 only: `showmount` and `rpcinfo` don't work against it, but `mount -t nfs4` does. The PVs mount with `nfsvers=4.1`.

*Later option: the storage network.* The server also has a 10 Gbps address on the non-routed storage VLAN, `cloud.storage.peterlarsen.org` (192.168.20.45), and only answers it for clients on 192.168.20.0/24. Every node has an address there: 192.168.20.81–.86 on `eno5.20` (nodes 1–3) and `enp8s0`/`enp9s0` (nodes 4–6), set up by NodeNetworkConfigurationPolicies. The kubelet mounts NFS from the node itself, so pods need no route to it. To switch, set `NFS_SERVER=cloud.storage.peterlarsen.org` and re-run setup (the PVs are recreated). The laptop can't reach that network, so checks have to run from the cluster. A separate storage network is the design to recommend in the talk either way.

The export already exists on the file server and needs no change:

```
/mnt/fileserver	*(rw,sync,all_squash,anonuid=3000,anongid=3000)
```

- `*` means any host may mount it, so it covers the nodes on 192.168.11.0/24 (and the storage VLAN later) without listing them.
- `all_squash,anonuid=3000,anongid=3000` means every client user, root and the pods' random UIDs alike, is treated as 3000:3000 on the server. So the volume directories belong to 3000:3000 and need no mode 0777. It's also a talking point: on plain NFS every pod writes as the *same* user. Nothing on the server tells one project's files from another's; the only boundary is which directory an admin put in each PV.

On the file server, once, as root. `NFS_EXPORT` in `demo.env` is `/mnt/fileserver`, and the PVs point at subdirectories of it (NFS v4 can mount a subdirectory of an export):

```bash
mkdir -p /mnt/fileserver/pv{1..10}
chown 3000:3000 /mnt/fileserver/pv{1..10}
chmod 0755 /mnt/fileserver/pv{1..10}
```

Reset empties exactly `pv1`…`pv10` and nothing else. If the share holds other data, consider `NFS_EXPORT=/mnt/fileserver/ocp-demo-storage`, which keeps the demo in one folder of its own. Nothing else changes: the PVs follow `NFS_EXPORT`.

Check from the laptop (as root):

```bash
mkdir -p /mnt/tmp && mount -t nfs4 cloud.peterlarsen.org:/mnt/fileserver/pv1 /mnt/tmp \
  && touch /mnt/tmp/probe && ls -ln /mnt/tmp && rm /mnt/tmp/probe; umount /mnt/tmp
```

The probe file should show owner 3000 3000.

In the cluster (setup, as admin). These are cluster-scoped objects, but they belong to the demo, carry the label `app.kubernetes.io/part-of: demo4-storage`, and are removed by teardown. None of them touches ODF:
- StorageClass `nfs-static` (`manifests/nfs-static-storageclass.yaml`): provisioner `kubernetes.io/no-provisioner`, `reclaimPolicy: Retain`, `Immediate`, **not** the default class.
- PVs `nfs-pv1`…`nfs-pv10` (`templates/nfs-pvs.yaml.j2`, rendered with `NFS_SERVER` / `NFS_EXPORT` from `demo.env`): 1 GiB (1–5), 2 GiB (6–8) and 5 GiB (9–10), RWX+RWO, label `storage=nfs-static`. The mixed sizes make the binder's "smallest PV that fits" visible: a 1.5 GiB claim gets a 2 GiB PV.

Talking points it sets up: the claim gets the *whole* PV; the size is only a label. The directories have no quota and sit on one 100 GiB file system, so `df` in the pod shows ~100G for a "2 GiB" volume. One pod can fill the space for all ten PVs and for anyone else on that disk, and the PVC page's Used and the metrics measure the shared 100 GiB. That's why the Part 7 fill only ever runs on the ODF volume; an empty shelf means a Pending claim and a ticket; with Retain, a deleted claim leaves its PV **Released** with the data still on the server (shown at the end of Part 3).

## Preparing the cluster

Run from the repo root, logged in as cluster admin (`oc login -u peter …`). The settings (project, users, NFS server and path) come from `demo.env`.

| Situation | Run |
|---|---|
| First time, or after teardown | `.venv/bin/ansible-playbook demo4-storage/setup.yml`: the project and roles, class `nfs-static` and PVs `nfs-pv1`…`10`, and the logbook in its Part 1 state. It waits until `/logbook.txt` answers. Safe to re-run: it never undoes a demo in progress |
| After a rehearsal or a run | `.venv/bin/ansible-playbook demo4-storage/reset.yml`: teardown, then setup |
| Always, right before presenting | `.venv/bin/ansible-playbook demo4-storage/verify.yml`: must end with "All good - ready to present Demo 4" |
| Remove the demo | `.venv/bin/ansible-playbook demo4-storage/teardown.yml`: deletes the projects, the PVs and the class, and empties `pv1`…`pv10` on the server (the directories stay). It leaves ODF alone |

Both verify's write test and teardown's emptying run *inside the cluster* (`tasks/nfs-shelf.yml`). Each binds a throwaway claim to every NFS PV in a helper project (`demo-storage-nfs-helper`), runs one pod that mounts all ten, and then recreates the PVs as Available. No root access to the server is needed, and the same steps will work when the PVs move to the storage VLAN, which the laptop can't reach. They refuse to run while a demo claim holds one of the PVs.

### What the cluster needs

- **OpenShift Data Foundation**: already installed, used as-is (see above).
- **Static NFS**: the export, the `nfs-static` class and the 10 PVs (see above).
- **User workload monitoring**: already enabled on the demo cluster (`enableUserWorkload: true`), so there's nothing to change. Verify checks that it stays on.
- **OADP operator**: 1.6.1 is already installed in `openshift-adp`, with no DataProtectionApplication yet. (ACM has its own copy in `open-cluster-management-backup`: leave it alone.) Setup adds, in `openshift-adp` only, an ObjectBucketClaim (a namespaced bucket request, like a PVC; no ODF configuration change) and a DataProtectionApplication: Velero with the `openshift` and `csi` plugins, node agent enabled (data mover), and the default BackupStorageLocation on that bucket.
- Project `demo-storage`: user1 `edit` + `monitoring-rules-edit`, user2 `view`, and `manifests/logbook-ephemeral.yaml` applied (the demo starts with the ephemeral logbook running).
- **Reset** must also: return the NFS shelf to all-Available (delete and recreate the 10 PVs, and empty `pv1`…`pv10` on the server, so no old logbook lines show up in Part 2), delete project `demo-storage-restore`, the Backup and Restore `demo-storage` in `openshift-adp` (a `DeleteBackupRequest`, so the bucket data goes too), and any leftover VolumeSnapshots.
- **Verify:** the 10 NFS PVs are Available, a test pod can mount one and write to it (this catches export, firewall and SELinux problems), the ODF classes in the table above exist (read-only listing), ODF `HEALTH_OK`, the BSL `Available`, the logbook Route answers, there are at least 3 schedulable workers (Part 4 needs 3 nodes for the anti-affinity; the demo cluster has 6 untainted nodes - 3 control-plane+worker, 3 storage+worker - so the DaemonSet runs 6 pods) and no `VolumeAlmostFull` alert is firing.

---

## Slides (≤ 8 min)

Going RIGHT: **title** → **Who we are** → **What to expect** → **What we will cover today** → **Persistent storage in OpenShift** (one diagram: Pod → PVC → StorageClass → CSI → storage, PV bound back) → **Live demo: today's setup** → the demo parts.

Concept slides sit DOWN under "Persistent storage in OpenShift". Use them only if the audience needs them: Ephemeral by default · PV & PVC · Static or dynamic · StorageClass · Access modes · CSI · Local storage (why to avoid it) · Object storage · Snapshot ≠ backup · OpenShift Data Foundation.

## Demo (≈ 28 min)

| Part | Time | Who | What happens |
|---|---|---|---|
| 1 · Ephemeral by default | 2 min | user1 | Open the logbook and note the pod name. Delete the pod: a new pod name, and the history is gone. *Then* the why: the Deployment's Volumes table shows `data` with an empty Type (an `emptyDir`; the console has no "ephemeral" label, so the behaviour is the proof). Optional for ops: the folder on the node, from the node Terminal |
| 2 · Static volumes: plain NFS | 3 min | peter, user1 | The shelf: `nfs-pv1`…`10` Available, class `nfs-static` with no provisioner. A 1.5 GiB claim is bound to a 2 GiB PV. Mount it with `oc set volume`, delete the pod, and the history stays. `df` shows 100G, because the size isn't enforced. A 10 GiB claim stays Pending |
| 3 · Dynamic storage: ODF | 4 min | peter, user1 | StorageClasses (the menu). Create PVC `logbook-data` in the console, it's Bound, and a PV is created for it. `oc get pv` is Forbidden for user1. Swap the volume. Delete `nfs-claim`: its PV is Released, not Available |
| 4 · RWO vs RWX | 4 min | user1 | `logbook-rwo`: 1 Running, 2 stuck on a Multi-Attach error. Delete it. `logbook-rwx` DaemonSet on CephFS: all nodes, one file. Say that all pods appending to one file is a demo shortcut, not a pattern to copy (see "RWX in practice") |
| 5 · StatefulSet | 3 min | user1 | 3 pods, 3 claims. Delete `logbook-sts-1`: same name, same disk. Scale down: the claims stay. **Then start the fill for Part 7** |
| 6 · What ODF adds | 4 min | peter | Data Foundation dashboard (health, capacity, performance, consumers), Object tab, alert rules shipped by ODF. DOWN: "Any CSI driver vs ODF" table |
| 7 · A volume fills up | 3 min | user1 | How full is it: `df` in the pod is the reliable number (the PVC page and metrics only show usage when the driver reports it). `VolumeAlmostFull` fires. Expand PVC to 2 GiB online, `df` shows it, the alert resolves. Remove the ballast |
| 8 · Snapshots | 3 min | user1 | Create a snapshot, "oops" `rm`, restore as a new PVC, `oc set volume`, and the history is back |
| 9 · OADP | 4 min | peter | Backup `demo-storage` to the ODF bucket, restore as `demo-storage-restore`, open the restored logbook |

Then **When storage goes wrong** (1 min, a diagnostics checklist built from what was just seen), **What we just did**, and **Q&A**.

**Timing risks:**
- The alert in Part 7 needs about 2–3 minutes: kubelet volume stats are scraped about once a minute, plus `for: 1m`. That's why the fill starts at the end of Part 5 and runs while the ODF dashboard is shown.
- The OADP backup with data mover takes a minute or two, and the restore about as long. If time is short, show a backup taken during rehearsal and only start the restore live.

## RWX in practice (Part 4)

RWX only promises that pods on many nodes can mount the volume read-write at once. Neither Kubernetes nor CSI coordinates the writes; that's left to the shared filesystem and, above all, to the application.

| | CephFS (ODF RWX) | NFS v4 |
|---|---|---|
| Seeing other clients' writes | Strong. The metadata server revokes client caching when several clients write one file, so it behaves close to a local POSIX filesystem | Close-to-open: changes are only guaranteed to be visible after the writer closes and the reader re-opens; attribute caching can lag a few seconds |
| Locks | POSIX advisory locks (`fcntl`, `flock`), coordinated across clients | Byte-range locks held by the server under a lease |
| A client dies holding locks | Evicted after a timeout and blocklisted (fenced), so it can't write after its locks are handed on | Its lease expires (90 s by default) and the locks are released |
| Appends from many clients | Coherent: writers are serialized | Not atomic across clients: lines can overwrite each other |

**Deadlocks:** the locks are advisory, so they only work if every writer uses them. Nothing detects deadlocks between pods on different nodes; Linux's `EDEADLK` only sees one machine. Avoiding them is the application's design: one lock order, timeouts, or no shared write locks at all. The storage's safety net is releasing a dead client's locks.

**Good RWX:** many readers, or many writers that each write their own files (uploads with unique names, shared static content).
**Bad RWX:** several writers updating the same file without locking. Never put a database's data directory on one RWX volume shared by replicas (SQLite on NFS is the classic failure); databases use one RWO volume per replica and replicate themselves (the StatefulSet, Part 5).
**RWX block for VMs** (OpenShift Virtualization live migration) is safe because the hypervisor guarantees a single writer, not the storage.

**Our demo:** every `logbook-rwx` pod appends to the *same* `logbook.txt`. That works on CephFS but would be unsafe on NFS. Say so on stage: "fine for a demo; a real app gives each pod its own file, or uses a database".

## Likely questions

- **"Can NFS clean up a released PV by itself?"** Kubernetes once had `persistentVolumeReclaimPolicy: Recycle`, which ran a scrub pod (`rm -rf`) and made the PV Available again. It has been deprecated for years, so don't build on it. The modern answer is a provisioner: the community `csi-driver-nfs` (or the older `nfs-subdir-external-provisioner`) creates a directory per claim on an existing NFS export and removes it when the claim is deleted (`onDelete: delete`, or `retain`/`archive`). Both are community projects, not supported by Red Hat, and need privileged pods on the nodes. They turn static NFS into dynamic storage, the same thing ODF does in Part 3. In this demo the cleanup is done by `teardown.yml`/`reset.yml`.
- **"Why does a 2 GiB NFS volume show 100 GiB in `df`?"** The directories have no quota, and the PV's capacity is only a label used for matching (Part 2).
- **"Why does the console show 0 B, or no usage at all, for a volume?"** Kubernetes only knows a volume's usage if the storage driver reports volume stats (CSI `NodeGetVolumeStats`). Not every driver does, raw block volumes never do, and the result depends on the filesystem; a nearly empty volume also rounds to 0 B. `df` inside the container is the reliable number. ODF's RBD and CephFS volumes do report, which is why Part 7's alert works.
- **"How does RWX handle concurrency and deadlocks?"** It doesn't: see "RWX in practice" above.
- **"Why not just give everyone NFS?"** All pods write as one squashed user (3000), there are no sizes, snapshots or expansion, and someone has to keep the shelf stocked. It's fine for existing shares, not as the platform's default storage.

## Still to do

- [x] Ansible: `setup.yml` / `verify.yml` / `reset.yml` / `teardown.yml` (2026-10-22: setup ran clean twice, the second time with no changes, and verify ended "All good" with the NFS write test passing on all 10 directories).
- [ ] OADP for Part 9: the ObjectBucketClaim and DataProtectionApplication in `openshift-adp` (setup), and deleting the Backup and Restore (teardown).
- [x] `pv1`…`pv10` on `cloud.peterlarsen.org`: they mount and are writable from the cluster (verify's write test).
- [ ] Check on the cluster: that restricted pods can write to the NFS PVs (the SELinux boolean `virt_use_nfs` on RHCOS; if it's off, choose another server setup rather than changing the nodes); the console's PVC form and the StorageClass list as user1; that a user-namespace PrometheusRule can use `kubelet_volume_stats_*` (Thanos Ruler should allow it); OADP data mover restore into a mapped namespace (route hosts are regenerated).
- [ ] Rehearse and take the backup screenshots (the deck shows placeholders with the expected file names, `images/demo4-*.webp`).
- [ ] Set the session date on the title slide, and "See you next time" on Q&A once the next topic is set.
