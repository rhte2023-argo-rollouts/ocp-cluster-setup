##
# Script to prepare Openshift Laboratory
##

##
# Users 
##
USERS="user01
user02
user03
user04
user05
user06
user07
user08
user09
user10
user11
user12
user13
user14
user15
user16
user17
user18
user19
user20
user21
user22
user23
user24
user25
"

for i in $USERS
do

  ##
  # Create required namespaces for each user
  ##
  oc delete project $i-blue-green
  
  oc delete project $i-canary
  
  oc delete -f scripts/files/mesh_smm.yaml -n $i-canary-service-mesh
  oc delete -f ./scripts/files/argocd.yaml -n $i-gitops-argocd
  
  sleep 90

  oc delete project $i-canary-service-mesh
  oc delete project $i-gitops-argocd

cat << EOF | oc delete -f -
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

cat << EOF | oc delete -f -
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

oc delete -n argo-rollouts -f ./scripts/files/argo-rollouts-install.yaml
oc delete -f ./scripts/files/mesh_scmp.yaml
oc delete -f ./scripts/files/mesh_service_monitor.yaml

sleep 60

oc delete project argo-rollouts
oc delete project istio-system

