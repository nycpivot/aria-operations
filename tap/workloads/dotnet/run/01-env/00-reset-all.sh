#!/bin/bash

# DELETE AKS RESOURCES
kubectl config use-context tap-run-aks

kubectl delete all -l secret-type=env

# DELETE EKS RESOURCES
kubectl config use-context tap-run-eks

kubectl delete all -l secret-type=env

if [ -d "${HOME}/run/env" ]
then
  rm -rf ${HOME}/run/env
fi
