#!/bin/bash

helm install consul hashicorp/consul --version v0.32.0-beta3 --values consul.yaml

kubectl apply -f consul/

## Creating applications

kubectl apply -f apps/

## Kong Commands

helm repo add kong https://charts.konghq.com
helm repo update

# kubectl create namespace kong
# helm install -n kong example kong/kong -f kong/values.yaml
helm install -n default example kong/kong -f kong/values.yaml
kubectl apply -f kong/kubernetes/

HOST=$(kubectl get svc --namespace kong consul-kong-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
PORT=$(kubectl get svc --namespace kong consul-kong-proxy -o jsonpath='{.spec.ports[0].port}')
export PROXY_IP=${HOST}:${PORT}
curl $PROXY_IP


# traefik

helm repo add traefik https://helm.traefik.io/traefik
helm repo update

helm install -n default traefik traefik/traefik -f traefik/values.yaml