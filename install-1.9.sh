#!/bin/bash

## Create GKE cluster

cd cluster
terraform init -ugprade
terraform approve


## Install Consul

cd ..

helm install consul hashicorp/consul --version v0.31.1 --values consul-1.9.yaml
kubectl apply -f consul/
kubectl apply -f apps/


## Test endnpoint

kubectl port-forward svc/ui 8080:80
curl localhost:8080