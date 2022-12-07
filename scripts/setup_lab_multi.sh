##
# Script to prepare Openshift Laboratory
##

##
# Users 
##
USERS="user01
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
# Install Pipelines Operator
##
oc apply -f ./scripts/files/redhat_pipelines.yaml
sleep 60

## 
# Install GitOps Operator
##
oc apply -f ./scripts/files/redhat_gitops.yaml
sleep 60

## 
# Install Argo Rollouts
##
kubectl apply -k ./scripts/files/argo-rollouts/

## 
# Install Service Mesh
##
until kubectl apply -k ./scripts/files/service-mesh/; do sleep 15; done


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
  
  oc new-project $i-gitops-argocd
  oc label namespace $i-gitops-argocd argocd.argoproj.io/managed-by=$i-gitops-argocd --overwrite
  oc adm policy add-role-to-user admin $i -n $i-gitops-argocd
  oc adm policy add-role-to-user admin system:serviceaccount:$i-gitops-argocd:argocd-argocd-application-controller -n $i-gitops-argocd

  ## 
  # Install ArgoCD per user
  ##
  oc apply -f ./scripts/files/argocd.yaml -n $i-gitops-argocd

done
