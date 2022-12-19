# Openshift Cluster Setup

This repository collects the required information and procedures to setup an Openshift cluster in order to run an Argo Rollouts laboratory. 

## Prerequisites

- Openshift 4.11+
- OC Client
- Argo Rollout (Kubectl Plugin)[https://argoproj.github.io/argo-rollouts/installation/#kubectl-plugin-installation]

## Setup Openshift Cluster

First of all, it is required to create a set of users, operators and much more object in Openshift. Please review the following list that includes all resources and configurations generated by this automatism:

- Generate a set of users by htpasswd 
- A new Auth Provider in Openshift
- Openshift GitOps operator
- Openshift Pipelines operator
- Argo Rollout Controller
- Multiple resources per user
  - 3 namespaces to deploy applications
  - 1 namespace to host Argo CD
  - An Argo CD Instance

In order to deploy the objects and configurations included above, it is required to follow the next steps:

- Login in Openshift

```$bash
$ oc login -u xxx -p xxx https://api.xxxx:6443
```

- Define the set of users that will be created

```$bash
$ vi scripts/setup_lab_multi.sh
...
USERS="user01
user02
user03
user04
"
...
```

- Execute the setup script

```$bash
$ sh scripts/setup_lab_multi.sh
```

## Testing Users Environment

The previous procedure creates multiple configurations and objects in Openshift as well as multiple users' environments. Please follow the next steps to test a user's environment individually:

- Login in Openshift

```$bash
$ oc login -u user01 -p user01 https://api.xxxx:6443
```

- Create an application

```$bash
$ oc project user01-blue-green

$ oc apply -f examples/app.yaml
rollout.argoproj.io/back-springboot configured
service/rollout-bluegreen-active configured
service/rollout-bluegreen-preview configured

$ oc get replicaset 
NAME                         DESIRED   CURRENT   READY   AGE
back-springboot-869fd55b4b   1         1         1       18m

$ oc get pod
NAME                               READY   STATUS    RESTARTS   AGE
back-springboot-869fd55b4b-xqwlt   1/1     Running   0          17m

$ oc argo rollouts get rollout back-springboot
...
NAME                                         KIND        STATUS     AGE  INFO
⟳ back-springboot                            Rollout     ✔ Healthy  19m  
└──# revision:1                                                          
   └──⧉ back-springboot-869fd55b4b           ReplicaSet  ✔ Healthy  19m  stable,active
      └──□ back-springboot-869fd55b4b-xqwlt  Pod         ✔ Running  19m  ready:1/1
```

- Execute a rollout procedure

```$bash
$ oc argo rollouts set image back-springboot back-springboot-multi=quay.io/acidonpe/jump-app-back-springboot:monitoring

$ oc argo rollouts get rollout back-springboot
...
NAME                                         KIND        STATUS               AGE  INFO
⟳ back-springboot                            Rollout     ◌ Progressing        20m  
├──# revision:2                                                                    
│  └──⧉ back-springboot-9d6f8c655            ReplicaSet  ◌ Progressing        4s   preview
│     └──□ back-springboot-9d6f8c655-5rwbc   Pod         ◌ ContainerCreating  4s   ready:0/1
└──# revision:1                                                                    
   └──⧉ back-springboot-869fd55b4b           ReplicaSet  ✔ Healthy            20m  stable,active
      └──□ back-springboot-869fd55b4b-xqwlt  Pod         ✔ Running            20m  ready:1/1

$ oc argo rollouts promote back-springboot                                
rollout 'back-springboot' promoted

$ oc argo rollouts get rollout back-springboot
...
NAME                                         KIND        STATUS     AGE  INFO
⟳ back-springboot                            Rollout     ✔ Healthy  21m  
├──# revision:2                                                          
│  └──⧉ back-springboot-9d6f8c655            ReplicaSet  ✔ Healthy  58s  stable,active
│     └──□ back-springboot-9d6f8c655-5rwbc   Pod         ✔ Running  58s  ready:1/1
└──# revision:1                                                          
   └──⧉ back-springboot-869fd55b4b           ReplicaSet  ✔ Healthy  21m  delay:8s
      └──□ back-springboot-869fd55b4b-xqwlt  Pod         ✔ Running  21m  ready:1/1

$ oc get replicaset                                    
NAME                         DESIRED   CURRENT   READY   AGE
back-springboot-869fd55b4b   0         0         0       21m
back-springboot-9d6f8c655    1         1         1       94s

$ oc get pods
NAME                              READY   STATUS    RESTARTS   AGE
back-springboot-9d6f8c655-5rwbc   1/1     Running   0          106s
```

Additionally, each user's enviroment has a specific Argo CD instance. In order to test the access, it is required to execute the following procedure:

- Obtain Argo CD credentials and URL

```$bash
$ oc get secret argocd-cluster -o jsonpath='{.data.admin\.password}' -n user01-gitops-argocd | base64 -d
xxx

$ oc get route argocd-server -n user01-gitops-argocd
...
argocd-server   argocd-server-user01-gitops-argocd.apps.xxx          argocd-server   https   passthrough/Redirect   None
```

- Access to the Argo CD console using the previous credentials

- Create an Argo CD Application

```$bash
$ oc apply -f examples/argo-app.yaml -n user01-gitops-argocd
```

- Check the new application in the Argo CD console and *sync* the application

## Authors

Asier Cidon @RedHat