# Demo 3 - Resource Management: terminal cheat-sheet
#
# On the presenter's laptop: common/workspace.sh demo3-resources puts this
# file, the YAML files and one session per user in ~/faa-demo/demo3-resources;
# open a tab per user with
#   bash --rcfile ~/faa-demo/demo3-resources/user3.rc
#   cheat                       # all demo commands
#   cheat 4                     # only part 4
#
# Fallback, the console's web terminal (>_ icon):
#   curl -sO http://slides.faa-demo.svc:8080/demo3-resources/cheatsheet.sh
#   source cheatsheet.sh
#
# Parts 1-3, 5, 6: user3 (edit). Part 4 setup, nodes, metrics, Part 7: peter (admin).

# The cluster's apps domain, from the console URL (works for any user)
CONSOLE=$(oc whoami --show-console 2>/dev/null)
APPS=${CONSOLE#https://*.}
BASE=https://slides-faa-demo.$APPS/demo3-resources/files

# The demo's YAML files (the deck's "files" in faa-demo/playbook.yml)
for f in guestbook-resources.patch.yaml memory-hog.yaml project-limits.yaml \
         project-quota.yaml no-requests-pod.yaml big-claim.yaml guestbook-hpa.yaml \
         guestbook-vpa.yaml guestbook-vpa-initial.patch.yaml; do
  [ -f "$f" ] || curl -sfO "$BASE/$f" || echo "could not download $f"   # kept if already here
done
oc project demo-resources >/dev/null 2>&1
GUESTBOOK_URL=https://guestbook-demo-resources.$APPS
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

# ---------------------------------------------------------------- 1 - Used vs reserved (user3, then peter)
oc get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass   # BestEffort
ab -c 10 -t 120 $GUESTBOOK_URL/                    # laptop; start it first, the dashboards lag
oc adm top pods                                    # under load 2-3 cores per pod (idle ~2m), nothing reserved
# Console (peter): Observe -> Dashboards -> Kubernetes / Compute Resources / Namespace (Pods)
oc get nodes                                       # peter: user3 may not list nodes
oc describe $(oc get nodes -l node-role.kubernetes.io/worker -o name | head -1) | grep -A 8 'Allocated resources'   # peter: requests vs allocatable
#   Limits < Requests? Limits only adds containers that HAVE a limit (many
#   platform pods and VMs without a quota set requests only)

# ---------------------------------------------------------------- 2 - Requests and limits, the right way (user3)
# Console: Deployment guestbook -> Actions -> Edit resource limits
#   CPU request 50m, memory request 320Mi, limit 512Mi, CPU limit 0:
#   refused ("CPU request must be less than or equal to limit") -> Cancel
oc patch deployment/guestbook --patch-file=guestbook-resources.patch.yaml   # what the form can't do
oc get deployment guestbook -o jsonpath='{.spec.template.spec.containers[0].resources}'; echo   # no cpu limit
oc get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass   # Burstable
oc set resources deployment/guestbook --requests=cpu=100   # far too much
oc get pods                                        # one new pod Pending
oc get events --sort-by=.eventTime --field-selector reason=FailedScheduling | tail -1   # Insufficient cpu
oc rollout undo deployment/guestbook

# ---------------------------------------------------------------- 3 - Hitting the ceiling (user3)
oc create -f memory-hog.yaml                       # 128Mi limit, allocates in a loop
oc get pod memory-hog -w                           # OOMKilled -> CrashLoopBackOff (Ctrl-C)
oc describe pod memory-hog | grep -A 4 'Last State'   # Reason: OOMKilled, Exit Code: 137
oc delete -f memory-hog.yaml
oc set resources deployment/guestbook --limits=cpu=100m
ab -c 10 -t 60 $GUESTBOOK_URL/                     # laptop; no -k: every request picks a pod
#   read: Requests per second, Time per request (mean), Non-2xx (= real failures)
#   no limit: ~290 req/s, ~35 ms; 100m limit: ~11 req/s, ~0.9 s (2.6/s on a Xeon D node)
#   ignore "Failed requests: Length": sizes compared with the 1st reply (a 504 page = 92 bytes)
oc exec deployment/guestbook -- cat /sys/fs/cgroup/cpu.max   # 10000 100000 = 10ms per 100ms
oc exec deployment/guestbook -- grep throttled /sys/fs/cgroup/cpu.stat   # run twice: it climbs
oc adm top pods -l app=guestbook                   # CPU flat at 100m
# Observe -> Metrics (peter) - share of CPU periods throttled (~0.95 under load):
#   sum by (pod) (rate(container_cpu_cfs_throttled_periods_total{namespace="demo-resources",container="guestbook"}[1m])) / sum by (pod) (rate(container_cpu_cfs_periods_total{namespace="demo-resources",container="guestbook"}[1m]))
oc rollout undo deployment/guestbook

# ---------------------------------------------------------------- 4 - A quota for each project (peter, then user3)
oc create -f project-limits.yaml                   # peter: LimitRange (user3 may not)
oc create -f project-quota.yaml                    # peter: ResourceQuota
oc describe quota
oc describe limitrange
oc scale deployment/guestbook --replicas=10        # user3: only 7 start
oc get events --sort-by=.eventTime --field-selector reason=FailedCreate | tail -1   # exceeded quota: pods=8
oc scale deployment/guestbook --replicas=2
oc get pods                                        # wait for 3 pods - terminating ones still count
oc create -f no-requests-pod.yaml
oc get pod no-requests -o jsonpath='{.spec.containers[0].resources}'; echo   # LimitRange defaults
oc describe pod no-requests | grep limit-ranger    # who filled them in
oc delete -f no-requests-pod.yaml
oc create -f big-claim.yaml                        # exceeded quota: requests.storage

# ---------------------------------------------------------------- 5 - How much storage is left? (user3)
oc get pvc
oc exec deployment/postgresql -- df -h /var/lib/pgsql/data
oc describe quota | grep storage
# Observe -> Metrics (peter): kubelet_volume_stats_available_bytes{namespace="demo-resources"}

# ---------------------------------------------------------------- 6 - Right-sizing (user3)
oc create -f guestbook-hpa.yaml                    # 2-6 pods, 50% of the CPU request
ab -c 10 -t 120 $GUESTBOOK_URL/                    # laptop
oc get hpa guestbook -w                            # 6 pods in ~20s; back to 2 ~80s after the load (Ctrl-C)
# Optional (DOWN): the VPA - created by setup, recommend-only ("Off")
cat guestbook-vpa.yaml
oc get vpa guestbook                               # CPU / MEM: the target (MEM in bytes)
oc describe vpa guestbook                          # Lower Bound, Target, Upper Bound
#   apply it: memory only, at pod start - the HPA keeps CPU
oc patch vpa guestbook --type=merge --patch-file=guestbook-vpa-initial.patch.yaml
oc get vpa guestbook                               # wait for an empty CPU column (up to 1 min)
oc rollout restart deployment/guestbook
oc get pods -l app=guestbook -o jsonpath='{range .items[*]}{.metadata.name}{"  "}{.spec.containers[0].resources}{"\n"}{end}'

# ---------------------------------------------------------------- 7 - Virtual machines (peter)
# Console: Virtualization -> VirtualMachines -> small-vm -> Start (or:)
virtctl start small-vm                             # oc patch vm small-vm --type merge -p '{"spec":{"runStrategy":"Always"}}'
oc get vm,vmi
oc get pod -l kubevirt.io=virt-launcher -o jsonpath='{.items[0].spec.containers[0].resources}'; echo
# 2 vCPU -> cpu 200m; memory 2Gi + overhead = 2324Mi; limit 4648Mi added by
# OpenShift Virtualization because the quota has limits.memory
oc describe quota                                  # memory shown in bytes here; the console page reads better
virtctl stop small-vm

# ---------------------------------------------------------------- 8 - Bonus: new project defaults (peter, look only)
oc adm create-bootstrap-project-template -o yaml | less
oc get project.config.openshift.io cluster -o yaml
