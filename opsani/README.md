# Deploy Bank of Anthos for Opsani Optimization Trials

Bank of Anthos is a polyglot application that can be used for a number of purposes. Opsani is providing this update to support optmization trials with enough scale and a transaction-defined load generator.

This will support your efforts in deploying and validating this application.

## Prerequistes and Components

1. `kubectl` cli command version appropriate to your cluster
2. bash command line interpreter (to run the deployment scripts)
3. target kubernetes cluster with at least **8** AWS m5.xl equivalent nodes avaialble exclusively for this test
4. ability to create a namespace, or define a namespace in the NAMESPACE environment variable for Bank of Anthos
5. ability to create the metrics-service (or already have it installed) in the kube-systems administrative namespace

## QUICKSTART

Run the `deploy.sh` script which will attempt to validate the pre-requisites, install any missing k8s service components, and install the Bank of Anthos application:

```sh
sh ./deploy.sh
```

## MANUAL STEPS

If the deploy script fails for some reason, you can work through the manual steps to implement the deployment.  See [README-manual.md](./README-manual.md)

## STATIC Loadgenerator

The Bank-of-Anthos application can be loaded either dynamically, or via a Static load.  In either case, the load generated is based on a quasi-random set of operations across the range of banking functions supported by the application, so even static load is not simply static, but it is of consistent load scale.

In order to enable static mode:

1. Remove the 'DYNAMIC' environment variable from the [loadgenerator.yaml](../kubernetes-manifests/loadgenerator.yaml) document
2. Deploy the loadgenerator or update it either by re-running the opsani/deploy.sh script, or by applying the loadgenerator.yaml manifest:

```sh
kubectl apply -f ../kubernetes-manifests/loadgenerator.yaml
```
