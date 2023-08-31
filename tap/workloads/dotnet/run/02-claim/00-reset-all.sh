#!/bin/bash

# DELETE AKS RESOURCES
kubectl config use-context tap-run-aks

kubectl delete all -l secret-type=claim

# DELETE EKS RESOURCES
kubectl config use-context tap-run-eks

kubectl delete all -l secret-type=claim

if [ -d "${HOME}/workloads/claim"]
then
  rm -rf ${HOME}/workloads/claim
fi
