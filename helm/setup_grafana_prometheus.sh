#!/bin/bash

echo "Add the helm repo for prometheus and grafana"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

echo create the monitoring namespace and install prometheus and grafana
kubectl create ns monitoring
helm install kube-prometheus-stack prometheus-community/prometheus --namespace monitoring
helm install grafana grafana/grafana --namespace monitoring

echo "Add additional metrics monitoring for prometheus"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo "check metrics availability with: kubectl get --raw /apis/custom.metrics.k8s.io/v1beta1"
helm install kube-prometheus-alerts prometheus-community/prometheus-adapter --namespace monitoring

