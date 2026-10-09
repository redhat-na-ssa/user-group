# Demo 1 - OpenShift Fundamentals: web terminal cheat-sheet
#
# In the console's web terminal (the >_ icon, top right):
#   curl -sO http://slides.faa-demo.svc:8080/demo1-fundamentals/cheatsheet.sh
#   source cheatsheet.sh        # downloads the YAML files below, sets the project
#   cheat                       # all demo commands (no setup lines)
#   cheat 4                     # only part 4
#
# Every command below is copy/paste ready.

BASE=http://slides.faa-demo.svc:8080/demo1-fundamentals/files
for f in hello-pod.yaml guestbook-app.yaml guestbook-pipelinerun.yaml guestbook-db-env.patch.yaml guestbook-route-roundrobin.patch.yaml guestbook-eventlistener.yaml; do
  curl -sfO "$BASE/$f" || echo "could not download $f"
done
oc project demo-intro >/dev/null 2>&1
GIT_REPO=https://local-gitea-gitea.apps.homeocp.ocp4.peterlarsen.org/ocpdemo/guestbook.git
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

# ---------------------------------------------------------------- 1 - Deploy PostgreSQL ("it's this simple")
oc get templates                                   # postgresql-demo, staged by the platform team
oc process postgresql-demo --parameters            # what the catalog form asks for
oc new-app --template=postgresql-demo              # the CLI version of "Instantiate Template"
oc get deployment,service,secret,pvc -l template=postgresql-demo
oc get secret postgresql -o jsonpath='{.data}'     # keys: database-user, -password, -name

# ---------------------------------------------------------------- 2 - Containers and pods
oc get pods -o wide                                # the database pod, and its node
oc logs deployment/postgresql --tail=20
oc rsh deployment/postgresql psql -c '\l'          # inside the running container
oc apply -f hello-pod.yaml
oc get pod hello -o wide
oc exec hello -- ps -ef
oc exec hello -- id
oc delete pod hello
oc get pods                                        # gone - nothing manages it
oc delete pod -l app=postgresql                    # comes back - it has a Deployment

# ---------------------------------------------------------------- 3 - From source code
# Console: +Add -> Import from Git
#   Git Repo URL:    https://local-gitea-gitea.apps.homeocp.ocp4.peterlarsen.org/ocpdemo/guestbook.git
#   Import Strategy: detected (Builder Image -> Python) - keep the suggested version
#   Application:     guestbook        Name: guestbook (exactly - Part 6 needs it)
#   Build option:    Pipelines        Resource type: Deployment, Create a route
# Repo in the browser: https://local-gitea-gitea.apps.homeocp.ocp4.peterlarsen.org/ocpdemo/guestbook
# ...or as code instead of the form (also the catch-up if the form went wrong):
sed "s|\${GIT_REPO}|$GIT_REPO|g" guestbook-app.yaml | oc apply -f -   # ImageStream, Pipeline, Deployment, Service, Route
oc create -f guestbook-pipelinerun.yaml            # first build (create, not apply)
# Either way:
oc get pipeline guestbook -o yaml                  # the pipeline definition
oc get pipelineruns
oc logs -f -l tekton.dev/pipelineTask=build --all-containers --max-log-requests=10
oc patch deployment/guestbook --patch-file=guestbook-db-env.patch.yaml
oc set env deployment/guestbook --list             # POSTGRESQL_* from secret postgresql
oc get svc,route

# ---------------------------------------------------------------- 4 - Self-healing and scaling
oc set probe deployment/guestbook --readiness --get-url=http://:8080/readyz --period-seconds=5
oc set probe deployment/guestbook --liveness --get-url=http://:8080/healthz --initial-delay-seconds=10
oc delete pod -l deployment=guestbook
oc get pods -w                                     # Ctrl-C to stop
oc scale deployment/guestbook --replicas=3
oc get endpointslices -l kubernetes.io/service-name=guestbook
oc patch route/guestbook --patch-file=guestbook-route-roundrobin.patch.yaml
for i in 1 2 3 4 5 6; do curl -ks https://$(oc get route guestbook -o jsonpath='{.spec.host}')/healthz; done

# ---------------------------------------------------------------- 5 - Projects and RBAC
oc auth can-i create deployments                   # as yourself (user1: yes)
oc auth can-i get secrets                          # user1: yes
oc auth can-i create rolebindings                  # user1: no - only the admin
oc get rolebindings -n demo-intro                  # admin only
oc auth can-i patch deployments/scale -n demo-intro --as=user2   # admin only: no
oc auth can-i get secrets -n demo-intro --as=user2               # admin only: no

# ---------------------------------------------------------------- 6 - A commit becomes a new version
oc apply -f guestbook-eventlistener.yaml           # the listener Gitea's webhook calls
oc get eventlistener,pods -l eventlistener=guestbook
oc get pipelineruns -w                             # after committing in Gitea
oc rollout status deployment/guestbook
oc rollout history deployment/guestbook

# ---------------------------------------------------------------- 7 - Configuration and rollback
oc set env deployment/guestbook APP_COLOR='#0066cc' APP_TITLE='Guestbook - config change'
oc set env deployment/guestbook --list
oc rollout history deployment/guestbook
oc rollout undo deployment/guestbook
oc rollout restart deployment/guestbook            # the Deployment equivalent of "rollout latest"
