#!/bin/bash

# DELETE AKS RESOURCES
kubectl config use-context tap-run-aks

kubectl delete secret -l secret-type=claim
kubectl delete clusterrole -l secret-type=claim

kubectl delete all -l operations=aria

# DELETE EKS RESOURCES
kubectl config use-context tap-run-eks

kubectl delete all -l operations=aria

if [ -d "${HOME}/tap-dotnet-run" ]
then
  rm -rf ${HOME}/tap-dotnet-run
fi

#tanzu service class-claim delete ${cache_redis_claim}
