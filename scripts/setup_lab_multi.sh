##
# Script to prepare Openshift Laboratory
##

##
# Users 
##
USERS="user01
user02
user03
"

##
# Adding user to htpasswd
##
htpasswd -c -b users.htpasswd admin password
for i in $USERS
do
  htpasswd -b users.htpasswd $i $i
done

##
# Creating htpasswd file in Openshift
##
oc delete secret lab-users -n openshift-config
oc create secret generic lab-users --from-file=htpasswd=users.htpasswd -n openshift-config

##
# Configuring OAuth to authenticate users via htpasswd
##
oc apply -f ./scripts/files/oauth.yaml

##
# Disable self namespaces provisioner 
##
oc patch clusterrolebinding.rbac self-provisioners -p '{"subjects": null}'

##
# Creating Role Binding for admin user
##
oc adm policy add-cluster-role-to-user admin admin

##
# Libraries
##
waitpodup(){
  x=1
  test=""
  while [ -z "${test}" ]
  do 
    echo "Waiting ${x} times for pod ${1} in ns ${2}" $(( x++ ))
    sleep 1 
    test=$(oc get po -n ${2} | grep ${1})
  done
}

waitoperatorpod() {
  NS=openshift-operators
  waitpodup $1 ${NS}
  oc get pods -n ${NS} | grep ${1} | awk '{print "oc wait --for condition=Ready -n '${NS}' pod/" $1 " --timeout 300s"}' | sh
}

waitknativeserving() {
  NS=knative-serving
  waitpodup ${1} ${NS}
  oc get pods -n ${NS} | grep ${1} | awk '{print "oc wait --for condition=Ready -n '${NS}' pod/" $1 " --timeout 300s"}' | sh
}

## 
# Install Pipelines Operator
##
oc apply -f ./scripts/files/redhat_pipelines.yaml
echo "Waiting for Istio Operators is ready..."
waitoperatorpod pipelines
sleep 30

## 
# Install GitOps Operator
##
oc apply -f ./scripts/files/redhat_gitops.yaml
echo "Waiting for Istio Operators is ready..."
waitoperatorpod gitops
sleep 30

## 
# Install Service Mesh
##
echo "Creating istio namespace..."
oc new-project istio-system
oc new-project mesh-test
echo "Installing Istio operator..."
oc apply -f ./scripts/files/redhat_servicemesh.yaml
sleep 30
echo "Waiting for Istio Operators is ready..."
waitoperatorpod kiali
waitoperatorpod jaeger
waitoperatorpod istio
sleep 120
echo "Installing Istio control plane..."
oc apply -f ./scripts/files/mesh_scmp.yaml
oc apply -f ./scripts/files/mesh_smmr.yaml
echo "Extend monitoring Istio control plane..."
oc policy add-role-to-user view system:serviceaccount:openshift-monitoring:prometheus-k8s -n istio-system
oc apply -f ./scripts/files/mesh_service_monitor.yaml
echo "Waiting for Istio control plane is ready..."
oc wait --for condition=Ready -n istio-system smmr/default --timeout 300s

## 
# Install Argo Rollouts
##
oc new-project argo-rollouts
kubectl apply -n argo-rollouts -f ./scripts/files/argo-rollouts-install.yaml

## 
# Install Web Terminal
##
oc apply -f scripts/files/webterminal/dev-workspaces-operator.yaml
waitoperatorpod devworkspace-controller
waitoperatorpod devworkspace-webhook
oc apply -f scripts/files/webterminal/web-terminal-exec.yaml
oc apply -f scripts/files/webterminal/web-terminal-tooling.yaml
oc apply -f scripts/files/webterminal/webterminal-operator.yaml
waitoperatorpod web-terminal-controller

for i in $USERS
do

  ##
  # Create required namespaces for each user
  ##
  oc new-project $i-blue-green
  oc label namespace $i-blue-green argocd.argoproj.io/managed-by=$i-gitops-argocd --overwrite
  oc adm policy add-role-to-user admin $i -n $i-blue-green
  oc adm policy add-role-to-user admin system:serviceaccount:$i-gitops-argocd:argocd-argocd-application-controller -n $i-blue-green
  
  oc new-project $i-canary
  oc label namespace $i-canary argocd.argoproj.io/managed-by=$i-gitops-argocd --overwrite
  oc adm policy add-role-to-user admin $i -n $i-canary
  oc adm policy add-role-to-user admin system:serviceaccount:$i-gitops-argocd:argocd-argocd-application-controller -n $i-canary
  
  oc new-project $i-canary-service-mesh
  oc label namespace $i-canary-service-mesh argocd.argoproj.io/managed-by=$i-gitops-argocd --overwrite
  oc adm policy add-role-to-user admin $i -n $i-canary-service-mesh
  oc adm policy add-role-to-user admin system:serviceaccount:$i-gitops-argocd:argocd-argocd-application-controller -n $i-canary-service-mesh
  oc adm policy add-role-to-user admin system:serviceaccount:$i-gitops-argocd:argocd-argocd-application-controller -n istio-system
  oc apply -f scripts/files/mesh_smm.yaml -n $i-canary-service-mesh

  oc new-project $i-gitops-argocd
  oc label namespace $i-gitops-argocd argocd.argoproj.io/managed-by=$i-gitops-argocd --overwrite
  oc adm policy add-role-to-user admin $i -n $i-gitops-argocd
  oc adm policy add-role-to-user admin system:serviceaccount:$i-gitops-argocd:argocd-argocd-application-controller -n $i-gitops-argocd

  ## 
  # Install ArgoCD per user
  ##
  oc apply -f ./scripts/files/argocd.yaml -n $i-gitops-argocd

  ##
  # Create Routes for istio-system namespaces
  ##
cat << EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: dstrategies-back-$i-canary-service-mesh
  namespace: istio-system
spec:
  to:
    kind: Service
    name: istio-ingressgateway
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  port:
    targetPort: http2
EOF

cat << EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: dstrategies-frontend-$i-canary-service-mesh
  namespace: istio-system
spec:
  to:
    kind: Service
    name: istio-ingressgateway
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  port:
    targetPort: http2
EOF

done
