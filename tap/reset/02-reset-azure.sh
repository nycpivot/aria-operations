#!/bin/bash

az aks delete --name tap-run-aks --resource-group aria-operations --yes

kubectl config delete-cluster tap-run-aks
kubectl config delete-context tap-run-aks
kubectl config delete-user clusterUser_aria-operations_tap-run-aks

az group delete --name aria-operations --yes
