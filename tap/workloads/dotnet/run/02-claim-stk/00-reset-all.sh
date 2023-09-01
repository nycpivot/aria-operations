#!/bin/bash

# DELETE AKS RESOURCES
kubectl config use-context tap-run-aks

kubectl delete secret -l secret-type=claim
kubectl delete clusterrole -l secret-type=claim

kubectl delete all -l secret-type=claim

# DELETE EKS RESOURCES
kubectl config use-context tap-run-eks

kubectl delete all -l secret-type=claim

if [ -d "${HOME}/run/claim" ]
then
  rm -rf ${HOME}/run/claim
fi

tanzu service class-claim delete ${cache_redis_claim_claim_eks}
