#!/bin/bash

#PIVNET CREDENTIALS
export PIVNET_USERNAME=$(az keyvault secret show --name pivnet-username --subscription nycpivot --vault-name tanzuvault --query value --output tsv)
export PIVNET_PASSWORD=$(az keyvault secret show --name pivnet-password --subscription nycpivot --vault-name tanzuvault --query value --output tsv)
export PIVNET_TOKEN=$(az keyvault secret show --name pivnet-token --subscription nycpivot --vault-name tanzuvault --query value --output tsv)

token=$(curl -X POST https://network.pivotal.io/api/v2/authentication/access_tokens -d '{"refresh_token":"'$PIVNET_TOKEN'"}')
access_token=$(echo $token | jq -r .access_token)

curl -i -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $access_token" \
    -X GET https://network.pivotal.io/api/v2/authentication

#TANZU AND TAP
export TANZU_CLI_NO_INIT=true
export TANZU_VERSION=v0.90.1
export TAP_VERSION=1.6.1

export CLI_FILENAME=tanzu-framework-linux-amd64-v0.28.1.1.tar
export ESSENTIALS_FILENAME=tanzu-cluster-essentials-linux-amd64-1.5.0.tgz

group=aria-operations
aks_region_code=eastus
tap_run=tap-run-aks

# 1. CREATE CLUSTER
echo
echo "<<< CREATING CLUSTER >>>"
echo

sleep 5

az group create --name $group --location $aks_region_code

az aks create --name $tap_run --resource-group $group \
    --node-count 2 --node-vm-size Standard_B4ms --kubernetes-version 1.25.6 \
    --enable-managed-identity --enable-addons monitoring --enable-msi-auth-for-monitoring --generate-ssh-keys 

#configure kubeconfig
az aks get-credentials --name $tap_run --resource-group $group

kubectl config use-context $tap_run

kubectl create ns tap-install

tanzu secret registry add tap-registry \
  --username $IMGPKG_REGISTRY_USERNAME_1 --password $IMGPKG_REGISTRY_PASSWORD_1 \
  --server $IMGPKG_REGISTRY_HOSTNAME_1 \
  --export-to-all-namespaces --yes --namespace tap-install

tanzu package repository add tanzu-tap-repository \
  --url $IMGPKG_REGISTRY_HOSTNAME_1/$INSTALL_REPO:$TAP_VERSION \
  --namespace tap-install
