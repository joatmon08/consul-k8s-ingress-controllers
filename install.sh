#!/bin/bash

helm install consul hashicorp/consul --values consul.yaml

kubectl apply -f consul/

## Creating applications

kubectl apply -f apps/

## Kong Commands

helm repo add kong https://charts.konghq.com
helm repo update
helm install -n default example kong/kong -f kong/values.yaml
kubectl apply -f kong/kubernetes/


## Traefik Commands

helm repo add traefik https://helm.traefik.io/traefik
helm repo update

export KUBERNETES_SVC_IP=$(kubectl get svc kubernetes -o=jsonpath='{.spec.clusterIP}')

cat <<EOF > traefik/values.yaml
deployment:
  podAnnotations:
    consul.hashicorp.com/connect-inject: "true"
    consul.hashicorp.com/connect-service: "traefik"
    consul.hashicorp.com/transparent-proxy: "true"
    consul.hashicorp.com/transparent-proxy-overwrite-probes: "false"
    consul.hashicorp.com/transparent-proxy-exclude-inbound-ports: "9000,8000,8443"
    consul.hashicorp.com/transparent-proxy-exclude-outbound-ports: "443"
    consul.hashicorp.com/transparent-proxy-exclude-outbound-cidrs: "${KUBERNETES_SVC_IP}/32"

logs:
  general:
    level: DEBUG
EOF

helm install -n default traefik traefik/traefik -f traefik/values.yaml

kubectl port-forward $(kubectl get pods --selector "app.kubernetes.io/name=traefik" --output=name) 9000:9000

export CONSUL_HTTP_ADDR=$(kubectl get svc consul-ui -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
export CONSUL_HTTP_TOKEN=$(kubectl get secrets consul-bootstrap-acl-token -o=jsonpath='{.data.token}' | base64 -d)
consul config write traefik/consul/service-defaults.hcl

kubectl apply -f traefik/kubernetes/