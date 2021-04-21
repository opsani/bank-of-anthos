# Kustomize the Bank-of-Anthos application for envoy injection

## Deployment

The opsani-envoy-patch includes a callout for the `frontend` deployment. Update this parameter name for the specific targeted service of choice.

## Service

The service patch patches the named service (in the file), again, this defaults to `frontend`. In addition
it assumes the input port into the service is port 80 (appropriate only for frontend in BofA app), and the target is defined in the opsany-envoy-patch configuration for the opsani-envoy build. Please update as appropriate.

## Application

If you already applied the "bank-of-anthos" app with the opsani/deploy.sh script, you should be able to apply an update with:

```sh
kubectl apply -k olas/
```

Otherwise, if you have yet to deploy the Bank-of-Anthos app, deploy with the `deploy-olas.sh` script:

```sh
cd opsani
./deploy-olas.sh
```