# Demo 4 - OpenShift Storage: terminal cheat-sheet
#
# On the presenter's laptop: common/workspace.sh demo4-storage puts this
# file, the YAML files and one session per user in ~/faa-demo/demo4-storage;
# open a tab per user with
#   bash --rcfile ~/faa-demo/demo4-storage/user1.rc
#   cheat                       # all demo commands
#   cheat 7                     # only part 6
#
# Fallback, the console's web terminal (>_ icon):
#   curl -sO http://slides.faa-demo.svc:8080/demo4-storage/cheatsheet.sh
#   source cheatsheet.sh
#
# Parts 1-5, 7, 8: user1 (edit). Parts 6 and 9, and listing PVs: peter (admin).

# The cluster's apps domain, from the console URL (works for any user)
CONSOLE=$(oc whoami --show-console 2>/dev/null)
APPS=${CONSOLE#https://*.}
BASE=https://slides-faa-demo.$APPS/demo4-storage/files

for f in logbook-ephemeral.yaml nfs-claim.yaml nfs-claim-big.yaml logbook-data-pvc.yaml logbook-rwo.yaml logbook-rwx.yaml logbook-sts.yaml logbook-volume-alert.yaml logbook-snapshot.yaml logbook-data-restored-pvc.yaml demo-storage-backup.yaml demo-storage-restore.yaml; do
  [ -f "$f" ] || curl -sfO "$BASE/$f" || echo "could not download $f"   # kept if already here
done
oc project demo-storage >/dev/null 2>&1
LOGBOOK_URL=https://logbook-demo-storage.$APPS
LOGBOOK_RWX_URL=https://logbook-rwx-demo-storage.$APPS
CHEATSHEET=$(realpath "${BASH_SOURCE[0]:-cheatsheet.sh}")
# cheat: every part from the first section header on; cheat N: part N only
cheat() {
  if [ -n "$1" ]; then
    awk -v n="$1" '/^# -----/ { show = ($3 == n) } show' "$CHEATSHEET"
  else
    sed -n '/^# -----/,$p' "$CHEATSHEET" | less
  fi
}
return 0 2>/dev/null || true

# ---------------------------------------------------------------- 1 - Ephemeral by default (user1)
oc get pods -l app=logbook -o wide
oc set volume deployment/logbook                   # volume "data": an emptyDir
curl -s $LOGBOOK_URL/logbook.txt | tail -3         # time, pod, node
oc delete pod -l app=logbook
curl -s $LOGBOOK_URL/logbook.txt                   # only the new pod's lines

# ---------------------------------------------------------------- 2 - Static volumes: plain NFS (peter, then user1)
oc get pv -l storage=nfs-static                    # peter: nfs-pv1..10, Available (1, 2, 5 GiB)
oc get pv nfs-pv1 -o jsonpath='{.spec.nfs}{"\n"}'   # server + directory - that's all a PV is here
oc get storageclass nfs-static                     # kubernetes.io/no-provisioner: nothing creates PVs
oc create -f nfs-claim.yaml                        # user1: 1500Mi RWX
oc get pvc nfs-claim                               # Bound to a 2Gi PV - the smallest that fits
oc set volume deployment/logbook --add --overwrite --name=data --type=pvc --claim-name=nfs-claim
oc rollout status deployment/logbook
oc delete pod -l app=logbook
curl -s $LOGBOOK_URL/logbook.txt | head -3         # the old pod's lines survived
oc exec deployment/logbook -- df -h /data          # ~100G: the whole server disk, not 2Gi - no quota
oc create -f nfs-claim-big.yaml                    # 10Gi - nothing on the shelf fits
oc describe pvc nfs-claim-big | tail -3            # Pending: "...or manually by the system administrator"
oc delete -f nfs-claim-big.yaml

# ---------------------------------------------------------------- 3 - Dynamic storage: ODF (user1)
oc get storageclass | grep -E '^NAME|openshift-storage'   # the ODF classes: rbd, cephfs, noobaa
# Console: Storage -> PersistentVolumeClaims -> Create: logbook-data, ceph-rbd, RWO, 1 GiB
oc create -f logbook-data-pvc.yaml                 # ...or as code (skip if made in the console)
oc get pvc logbook-data                            # Bound
oc get pv                                          # user1: Forbidden - PVs are the platform's
oc set volume deployment/logbook --add --overwrite --name=data --type=pvc --claim-name=logbook-data
oc rollout status deployment/logbook
oc delete pod -l app=logbook
curl -s $LOGBOOK_URL/logbook.txt | head -3         # the new logbook on ODF survived
oc delete pvc nfs-claim                            # static: its PV is now Released, not Available
oc get pv -l storage=nfs-static                    # peter: STATUS Released, data still on the server

# ---------------------------------------------------------------- 4 - RWO vs RWX (user1)
oc create -f logbook-rwo.yaml                      # 3 pods, 3 nodes, one RWO claim
oc get pods -l app=logbook-rwo -o wide             # 1 Running, 2 ContainerCreating
oc get events --field-selector reason=FailedAttachVolume
oc delete -f logbook-rwo.yaml
oc create -f logbook-rwx.yaml                      # DaemonSet, one CephFS RWX claim
oc get pods -l app=logbook-rwx -o wide             # one per worker, all Running
curl -s $LOGBOOK_RWX_URL/logbook.txt | tail        # lines from every node

# ---------------------------------------------------------------- 5 - StatefulSet: a disk per replica (user1)
oc create -f logbook-sts.yaml
oc get pods,pvc -l app=logbook-sts                 # data-logbook-sts-0, -1, -2
oc exec logbook-sts-1 -- tail -3 /data/logbook.txt # only logbook-sts-1's lines
oc delete pod logbook-sts-1
oc get pod logbook-sts-1 -o wide                   # same name, same claim
oc exec logbook-sts-1 -- head -3 /data/logbook.txt # the old lines are still there
oc scale statefulset/logbook-sts --replicas=1
oc get pvc -l app=logbook-sts                      # all three claims stay
# Before Part 6 - start filling the volume (the alert needs ~2-3 min):
oc create -f logbook-volume-alert.yaml
oc exec deployment/logbook -- dd if=/dev/zero of=/data/ballast bs=1M count=900

# ---------------------------------------------------------------- 6 - What ODF adds (peter)
# Read-only: look, never change the cluster-wide ODF configuration
oc get storagecluster -n openshift-storage
oc get cephcluster -n openshift-storage            # HEALTH_OK
oc get pods -n openshift-storage -l app=rook-ceph-osd -o wide   # one OSD per disk
oc get storageclass -o custom-columns=NAME:.metadata.name,PROVISIONER:.provisioner,EXPAND:.allowVolumeExpansion | grep -E '^NAME|openshift-storage'
oc get volumesnapshotclass
oc get prometheusrules -n openshift-storage        # the alert rules ODF ships
oc get obc -A                                      # bucket claims (the OADP bucket)

# ---------------------------------------------------------------- 7 - A volume fills up (user1)
oc get prometheusrule logbook-volume -o yaml       # created at the end of Part 5
oc exec deployment/logbook -- df -h /data          # ~92% used
# Console: Observe -> Alerts: VolumeAlmostFull
# Console: Storage -> PersistentVolumeClaims -> logbook-data -> Actions -> Expand PVC: 2 GiB
oc patch pvc logbook-data --type=merge -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'
oc get pvc logbook-data                            # CAPACITY 2Gi
oc exec deployment/logbook -- df -h /data          # same pod, bigger filesystem
oc exec deployment/logbook -- rm /data/ballast     # before Part 8

# ---------------------------------------------------------------- 8 - Snapshots (user1)
oc create -f logbook-snapshot.yaml
oc get volumesnapshot                              # READYTOUSE true
oc exec deployment/logbook -- rm /data/logbook.txt # the "oops"
curl -s $LOGBOOK_URL/logbook.txt                   # only the last few seconds
oc create -f logbook-data-restored-pvc.yaml
oc set volume deployment/logbook --add --overwrite --name=data --claim-name=logbook-data-restored
oc rollout status deployment/logbook
curl -s $LOGBOOK_URL/logbook.txt | head -3         # the history is back

# ---------------------------------------------------------------- 9 - Backup and restore with OADP (peter)
oc get dataprotectionapplication -n openshift-adp
oc get backupstoragelocation -n openshift-adp      # Available
oc create -f demo-storage-backup.yaml
oc get backup demo-storage -n openshift-adp -o jsonpath='{.status.phase}{"\n"}'   # Completed
oc create -f demo-storage-restore.yaml
oc get restore demo-storage -n openshift-adp -o jsonpath='{.status.phase}{"\n"}'
oc get pods,pvc -n demo-storage-restore
curl -s https://logbook-demo-storage-restore.$APPS/logbook.txt | head -3

# ---------------------------------------------------------------- 10 - When storage goes wrong
oc describe pvc logbook-data
oc get events --sort-by=.lastTimestamp
oc get volumeattachment
oc adm must-gather --image=registry.redhat.io/odf4/odf-must-gather-rhel9:v4.22   # match the ODF version (4.22 here)
