#!/bin/bash

helm install consul hashicorp/consul --version v0.32.0-beta2 --values consul.yaml

kubectl apply -f consul/
kubectl apply -f apps/