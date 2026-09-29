# Demo 1 - OpenShift Fundamentals: web terminal cheat-sheet
#
# In the console's web terminal (the >_ icon, top right):
#   curl -sO http://slides.faa-demo.svc:8080/demo1-fundamentals/cheatsheet.sh
#   source cheatsheet.sh        # downloads the YAML files below, sets the project
#   cheat                       # shows this file again
#
# Every command below is copy/paste ready.

BASE=http://slides.faa-demo.svc:8080/demo1-fundamentals/files
for f in hello-pod.yaml guestbook-db-env.patch.yaml guestbook-route-roundrobin.patch.yaml; do
  curl -sfO "$BASE/$f" || echo "could not download $f"
done
oc project demo-intro >/dev/null 2>&1
CHEATSHEET=$(realpath "${BASH_SOURCE[0]:-cheatsheet.sh}")
cheat() { sed -n '/^# -----/,$p' "$CHEATSHEET" | less; }
return 0 2>/dev/null || true

# ---------------------------------------------------------------- 1 · Projects and RBAC
oc get rolebindings -n demo-intro
oc auth can-i create deployments -n demo-intro --as=user2     # needs admin
oc auth can-i get secrets -n demo-intro --as=user2            # needs admin
oc auth can-i create deployments -n demo-intro                # as yourself

# ---------------------------------------------------------------- 2 · Containers and pods
oc apply -f hello-pod.yaml
oc get pod hello -o wide
oc logs hello
oc exec hello -- ps -ef
oc exec hello -- id
oc delete pod hello
oc get pods
oc delete pod -l app=postgresql        # comes back - it has a Deployment

# ---------------------------------------------------------------- 3a · Deploy an image
oc new-app --image=quay.io/plarsen/pacman --name=pacman -l app.kubernetes.io/part-of=Games
oc create route edge pacman --service=pacman
oc get route pacman

# ---------------------------------------------------------------- 3b · From source code
oc get pipelineruns
oc logs -f -l tekton.dev/pipelineTask=build --all-containers --max-log-requests=10
oc patch deployment/guestbook --patch-file=guestbook-db-env.patch.yaml
oc get deployment guestbook -o yaml | grep -A3 envFrom
oc get svc,route

# ---------------------------------------------------------------- 4 · Self-healing and scaling
oc set probe deployment/guestbook --readiness --get-url=http://:8080/readyz --period-seconds=5
oc set probe deployment/guestbook --liveness --get-url=http://:8080/healthz --initial-delay-seconds=10
oc delete pod -l deployment=guestbook
oc get pods -w                          # Ctrl-C to stop
oc scale deployment/guestbook --replicas=3
oc get endpointslices -l kubernetes.io/service-name=guestbook
oc patch route/guestbook --patch-file=guestbook-route-roundrobin.patch.yaml
for i in 1 2 3 4 5 6; do curl -ks https://$(oc get route guestbook -o jsonpath='{.spec.host}')/healthz; done

# ---------------------------------------------------------------- 5 · A commit becomes a new version
oc get pipelineruns -w                  # after committing in Gitea
oc rollout status deployment/guestbook
oc rollout history deployment/guestbook

# ---------------------------------------------------------------- 6 · Configuration and rollback
oc set env deployment/guestbook APP_COLOR='#0066cc' APP_TITLE='Guestbook - config change'
oc set env deployment/guestbook --list
oc rollout history deployment/guestbook
oc rollout undo deployment/guestbook
oc rollout restart deployment/guestbook  # the Deployment equivalent of "rollout latest"
