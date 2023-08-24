#!/bin/bash

# PREREQUISITES - CREATE AKS CLUSTER
# ----------------------------------

# 1. CREATE CLUSTER
echo
echo "<<< CREATING CLUSTER >>>"
echo

sleep 5

group=aria-operations
aks_region_code=eastus
tap_run_aks=tap-run-aks
tmc_cluster_group=tmc-operations

az group create --name ${group} --location ${aks_region_code}

az aks create --name ${tap_run_aks} --resource-group ${group} \
    --node-count 2 --node-vm-size Standard_B4ms --kubernetes-version 1.25.6 \
    --enable-managed-identity --enable-addons monitoring --enable-msi-auth-for-monitoring --generate-ssh-keys 

az aks get-credentials --name ${tap_run_aks} --resource-group ${group}

kubectl config use-context ${tap_run_aks}

# 2. ATTACH TO TMC

echo
echo "<<< ATTACHING CLUSTER >>>"
echo

sleep 5

if test -f k8s-attach-manifest.yaml; then
  rm k8s-attach-manifest.yaml
fi 

tmc cluster attach --name ${tap_run_aks} --cluster-group ${tmc_cluster_group}

sleep 30

kubectl apply -f k8s-attach-manifest.yaml

echo
intervals=( 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 )
for interval in "${intervals[@]}" ; do
echo "${interval} minutes remaining..."
sleep 60 # give 20 minutes for all clusters to be created
done
