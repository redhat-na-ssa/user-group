# Demo 3 - Resource Management: terminal cheat-sheet (DRAFT - the manifests
# named below don't exist yet, see DEMO-SCRIPT.md "Still to do")
#
# On the presenter's laptop: common/workspace.sh demo3-resources puts this
# file, the YAML files and one session per user in ~/faa-demo/demo3-resources;
# open a tab per user with
#   bash --rcfile ~/faa-demo/demo3-resources/user1.rc
#   cheat                       # all demo commands
#   cheat 4                     # only part 4
#
# Fallback, the console's web terminal (>_ icon):
#   curl -sO http://slides.faa-demo.svc:8080/demo3-resources/cheatsheet.sh
#   source cheatsheet.sh
#
# Parts 1-3, 5, 6: user1 (edit). Part 4 setup, nodes, metrics, Part 7: peter (admin).

# The cluster's apps domain, from the console URL (works for any user)
CONSOLE=$(oc whoami --show-console 2>/dev/null)
APPS=${CONSOLE#https://*.}
BASE=https://slides-faa-demo.$APPS/demo3-resources/files

# TODO: list the manifests here once they exist (same as the deck's "files"
# in faa-demo/playbook.yml)
for f in; do
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

# ---------------------------------------------------------------- 1 - Used vs reserved (user1, then peter)
oc get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass   # BestEffort
oc adm top pods                                    # what they really use
# Console (peter): Observe -> Dashboards -> Kubernetes / Compute Resources / Namespace (Pods)
oc get nodes
oc describe $(oc get nodes -l node-role.kubernetes.io/worker -o name | head -1) | grep -A 8 'Allocated resources'   # peter: requests vs allocatable

# ---------------------------------------------------------------- 2 - Requests and limits, the right way (user1)
# Console: Deployment guestbook -> Actions -> Edit resource limits
#   CPU request 50m, memory request 320Mi, memory limit 512Mi, no CPU limit
oc patch deployment/guestbook --patch-file=guestbook-resources.patch.yaml   # the same, as code
oc get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass   # Burstable
oc set resources deployment/guestbook --requests=cpu=100   # far too much
oc get pods                                        # one new pod Pending
oc get events --field-selector reason=FailedScheduling   # Insufficient cpu
oc rollout undo deployment/guestbook

# ---------------------------------------------------------------- 3 - Hitting the ceiling (user1)
oc create -f memory-hog.yaml                       # 128Mi limit, allocates in a loop
oc get pod memory-hog -w                           # OOMKilled -> CrashLoopBackOff (Ctrl-C)
oc describe pod memory-hog | grep -A 4 'Last State'   # Reason: OOMKilled, Exit Code: 137
oc delete -f memory-hog.yaml
oc set resources deployment/guestbook --limits=cpu=100m
ab -k -c 10 -t 60 $GUESTBOOK_URL/                  # laptop; keep -c at 10
# Observe -> Metrics (peter):
#   rate(container_cpu_cfs_throttled_periods_total{namespace="demo-resources"}[1m])
oc rollout undo deployment/guestbook

# ---------------------------------------------------------------- 4 - A budget for each project (peter, then user1)
oc create -f project-limits.yaml                   # peter: LimitRange
oc create -f project-quota.yaml                    # peter: ResourceQuota
oc describe quota
oc describe limitrange
oc scale deployment/guestbook --replicas=10        # user1
oc get events --field-selector reason=FailedCreate # exceeded quota
oc scale deployment/guestbook --replicas=2
oc create -f no-requests-pod.yaml
oc get pod no-requests -o jsonpath='{.spec.containers[0].resources}'; echo   # LimitRange defaults
oc delete -f no-requests-pod.yaml
oc create -f big-claim.yaml                        # exceeded quota: requests.storage

# ---------------------------------------------------------------- 5 - How much storage is left? (user1)
oc get pvc
oc exec deployment/postgresql -- df -h /var/lib/pgsql/data
oc describe quota | grep storage
# Observe -> Metrics (peter): kubelet_volume_stats_available_bytes{namespace="demo-resources"}

# ---------------------------------------------------------------- 6 - Right-sizing (user1)
oc create -f guestbook-hpa.yaml                    # 2-6 pods, 50% of the CPU request
ab -k -c 10 -t 120 $GUESTBOOK_URL/                 # laptop
oc get hpa guestbook -w                            # (Ctrl-C)

# ---------------------------------------------------------------- 7 - Virtual machines (peter)
oc get vm,vmi
oc get pod -l kubevirt.io=virt-launcher -o jsonpath='{.items[0].spec.containers[0].resources}'; echo
oc describe quota

# ---------------------------------------------------------------- 8 - Bonus: new project defaults (peter, look only)
oc adm create-bootstrap-project-template -o yaml | less
oc get project.config.openshift.io cluster -o yaml
