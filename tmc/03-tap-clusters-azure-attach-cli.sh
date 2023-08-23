#!/bin/bash

# PREREQUISITES
# -------------
# AKS CLUSTER WILL HAVE BEEN CREATED (aria-operations/tap/cli/02-tap-azure-prereqs.sh)

tap_run_aks=tap-run-aks
tmc_cluster_group=tmc-operations

kubectl config use-context ${tap_run_aks}

if test -f k8s-attach-manifest.yaml; then
  rm k8s-attach-manifest.yaml
fi 

tmc cluster attach --name $tap_run_aks --cluster-group $tmc_cluster_group

sleep 30

kubectl apply -f k8s-attach-manifest.yaml

echo
intervals=( 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 )
for interval in "${intervals[@]}" ; do
echo "${interval} minutes remaining..."
sleep 60 # give 20 minutes for all clusters to be created
done
