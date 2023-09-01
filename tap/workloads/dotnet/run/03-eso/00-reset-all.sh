#!/bin/bash

# DELETE AKS RESOURCES
kubectl config use-context tap-run-aks

kubectl delete all -l secret-type=eso

# DELETE EKS RESOURCES
kubectl config use-context tap-run-eks

kubectl delete all -l secret-type=eso

if [ -d "${HOME}/workloads/eso" ]
then
  rm -rf ${HOME}/workloads/eso
fi

helm uninstall prometheus
helm uninstall external-secrets -n external-secrets
