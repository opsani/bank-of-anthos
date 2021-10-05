# Bank of Anthos with AppDynamics

[Bank of Anthos](https://github.com/GoogleCloudPlatform/bank-of-anthos) is a complete demo banking application that is K8s-based built with Java and Python components. 

[AppDynamics](https://www.appdynamics.com/) is an application performance management platform that allows for robust metric gathering and control of deployments.

This repo is built to serve the necessary components to instrument Bank of Anthos with AppDynamics agents.

## Prerequistes and Components

1. `kubectl` cli command version appropriate to your cluster
2. bash command line interpreter (to run the deployment scripts)
3. target kubernetes cluster with at least **8** AWS m5.xl equivalent nodes avaialble exclusively for this test
4. ability to create a namespace, or define a namespace in the NAMESPACE environment variable for Bank of Anthos
5. ability to create the metrics-service (or already have it installed) in the kube-systems administrative namespace
6. an AppDynamics account with sufficient licenses for all services (alternatively, selectively use the non-instrumented images for certain services accordingly), as well as proper allocation of these licenses under rules

## Overview of Changes for use with AppDynamics

Bank of Anthos is comprised of 6 services (along with 2 databases). For use with AppDynamics, each of the 6 components has to be instrumented, which varies based on the underlying language of the component. Dynamic deployments (frontend and user-service) register a new AppD agent for each new pod initialized.

The Java components (balance-reader, ledger-writer, and transaction-history) utilize the [AppDynamics Java machine agent](https://docs.appdynamics.com/display/PRO21/Install+the+Java+Agent), which is installed into the application's JVM. The following changes have been made:

1. An initContainer that pulls and installs the Java machine agent 
2. Environment variables (both directly in the manifest and project-wide from the config.yaml) to set the AppDynamics parameters
3. An /appdynamics volume+mount to run the "appd-env-script" from appd-scripts.yaml and ensure all variables are passed correctly to the agent
4. An override entrypoint that starts the agent simultaneously with the component

The Python components (contacts, frontend and userservice) utilize the [AppDynamics Python machine agent](https://docs.appdynamics.com/display/PRO21/Python+Agent) and have been modified as so:

1. Rebulid of the docker images contained within the /src to include the AppDynamics python package
2. Environment variables (both directly in the manifest and project-wide from the config.yaml) to set the AppDynamics parameters
3. An initContainer that runs the 'appd-pyagent' script within appd-scripts.yaml to build an appd.cfg file
4. An override entrypoint to that preprends 'pyagent run' to the gunicorn command based on the predefined entrypoint in the /src/*/Dockerfile

The `config.yaml` is the only file required to be modified with AppDynamics-specific parameters. General variables are stored in the "appd-config" ConfigMap, where `APPDYNAMICS_AGENT_APPLICATION_NAME` has to be set and all others will run with the default options.
AppDynamics credentials are stored in "appd-secrets", and require the  username, account name, controller host name, password and access key. 

## QUICKSTART

Populate the `/kubernetes-manifests/config.yaml` and run the `/appdynamics/deploy.sh` script which will attempt to validate the pre-requisites, install any missing k8s service components, and install the Bank of Anthos application:

```sh
cd appdynamics && ./deploy.sh
```

## Install Bank of Anthos (Manually)

The following commands will deploy the basic Bank-of-Anthos app, updated to use more realistic resources (requests/limits), and a loadgenerator deployment that should drive 3-5 frontend pods to run and scale up to ~10 pods over time (Currently ~ 1 hour).

The following commands are run by the above `deploy.sh` script, but can be run manually instead:

### Ensure kubectl is installed and pointing to your cluster

The following command will ensure that a) `kubectl` is installed, b) that you can talk to the cluster and c) that you see at least 6 nodes (the output should be a number).

```sh
kubectl get nodes | grep 'internal' | wc -l
```

### Ensure you have a namespace and to simplify followon processes, that the namespace is default

```sh
echo "ensure NAMESPACE is an environment variable":
export NAMESPACE=${NAMESPACE:-bank-of-anthos-appdynamics}
if [ "`kubectl create ns ${NAMESPACE} >& /dev/null; echo $?`" ]; then
  echo `kubectl get ns ${NAMESPACE} | grep ${NAMESPACE}`
fi
```

Also, you may want to add the namespace to your kubeconfig as the "Default" for this cluster:

```sh
kubectl config set-context `kubectl config get-contexts | awk '/^\*/ {print $2}'` --namespace ${NAMESPACE}
```

### Ensure that the metrics service is installed and running

Metrics are needed to run the HPA pod autoscaler, and are simple point in time cpu and memory data captured from 
the kubelet service on each node. You need access to the kube-system namespace and the ability to create Cluster Roles and Cluster Role Bindings in order to apply this manifest from the Kubernetes metrics-sig:

```sh
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### Finally, we can install Bank-of-Anthos

Step one is to create a JWT token to support login via the Web UI

```sh
openssl genrsa -out jwtRS256.key 4096
openssl rsa -in jwtRS256.key -outform PEM -pubout -out jwtRS256.key.pub
kubectl create -n ${NAMESPACE} secret generic jwt-key --from-file=./jwtRS256.key --from-file=./jwtRS256.key.pub
rm ./jwt*key*
```

Step two is to launch all of the manifests from the kubernetes-manifests directory which will complete the application deployment.

```sh
kubectl apply -n ${NAMESPACE} -f ../kubernetes-manifests/
```

### Verify that the service is up and running

We can check to ensure that our pods are starting (this may take a moment):

```sh
kubectl -n ${NAMESPACE} get pods -w
```

This will wait and show you pods as they come online.  type ^C (control-C) to quit watching for new pods.

Alternately, we can launch a port-forward to enable access to the Frontend service from our local machine:

```sh
kubectl port-forward -n ${NAMESPACE} svc/frontend 8080:http &
```

You should then be able to point to [http://localhost:8080](http://localhost:8080) and get a login page.  The default user is `testuser` and the default password is `password`.

## Load generation

Load is automatically generated in a dynamic fashion with the loadgenerator pod.  Opsani has modified
this with the latest version of locust.io, and inlcudes a dynamic sinusoidal load pattern.  You can modify the
parameters of the `kubernetes-manifests/loadgenerator.yaml` document with the following parameters:

  STEP_SEC: seconds per step, longer will generate a longer load range, usually 10 is good for initial tests, and 600 for longer term load.
  USER_SCALE:  Number of users to vary, the more the heavier the load.  180 appears to be a good starting point for reasonable load.
  SPAWN_RATE: How quickly to change during the step, there is likely no need to change this parameter.
  MIN_USERS: As the sinusoidal shape varies between "0" and "1" multiplied by the USER_SCALE parameter, it is often good to ensure some load, we set this as 50 by default.

## Examining in AppDynamics Console

At this point, the Bank of Anthos application should be running on your Kubernetes cluster, have dynamic load reaching it, and have AppDynamics agents running in each component that will be generating a flowmap and gathering metrics in the controller console.

![](static/flowmap.png)

## (Optional) Install the Cluster Agent

The cluster agent allows for high-level insights into the underlying K8s behavior, such as:
- pod failures and restarts
- node starvation
- pod eviction threats and pod quota violations
- image and storage failures
- pending or stuck pods
- bad endpoints: detects broken links between pods and application components
- service endpoints in a failed state
- missing dependencies (Services, configMaps, Secrets)

To install the CA per [documentation here](https://docs.appdynamics.com/21.1/en/infrastructure-visibility/monitor-kubernetes-with-the-cluster-agent/install-the-cluster-agent/install-the-cluster-agent-with-the-kubernetes-cli), update the `cluster-agent/cluster-agent.yaml` with the target appName, controllerUrl and account, then apply it along with the CA operator (Note: this is not deployed in the automatic `deploy.sh` script).

```sh
kubectl create namespace appdynamics
kubectl create -f cluster-agent/cluster-agent-operator.yaml
kubectl create -f cluster-agent/cluster-agent.yaml 
```

## Uninstall Bank-of-Anthos

If a namespace was created for this project, the simplest approach is to simply delete the namespace.

Alternatively, clean out the deployed manifests:

```sh
kubectl delete -n ${NAMESPACE} -f ../kubernetes-manifests/
```

We will also want to clean up the manually deployed jwt-key secret:

```sh
kubectl delete secret jwt-key
```

And to really clean things out, you can delete the namespace and the metrics service as well:

```sh
kubectl delete ns ${NAMESPACE}
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```
