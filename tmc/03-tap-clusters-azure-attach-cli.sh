#!/bin/bash

# PREREQUISITES
# -------------
# AKS CLUSTER WILL BE HAVE BEEN CREATED (aria-operations/tap/cli/02-tap-azure-prereqs.sh)

tap_run_aks=tap-run-aks
tmc_cluster_group=tmc-operations

kubectl config use-context ${tap_run_aks}

if test -f k8s-attach-manifest.yaml; then
  rm k8s-attach-manifest.yaml
fi 

tmc cluster attach --name $tap_run_aks --cluster-group $tmc_cluster_group

sleep 20

kubectl apply -f k8s-attach-manifest.yaml
