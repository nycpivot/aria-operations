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
export TANZU_VERSION=v0.28.1
export TAP_VERSION=1.5.0

export CLI_FILENAME=tanzu-framework-linux-amd64-v0.28.1.1.tar
export ESSENTIALS_FILENAME=tanzu-cluster-essentials-linux-amd64-1.5.0.tgz

group=aria-operations
aks_region_code=eastus
tap_run=tap-run-api

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


# 6. TANZU PREREQS
# https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/install-tanzu-cli.html
# https://network.tanzu.vmware.com/products/tanzu-application-platform#/releases/1287438/file_groups/12507
echo
echo "<<< INSTALLING TANZU AND CLUSTER ESSENTIALS >>>"
echo

mkdir $HOME/tanzu

wget https://network.pivotal.io/api/v2/products/tanzu-application-platform/releases/1283005/product_files/1446073/download --header="Authorization: Bearer $access_token" -O $HOME/tanzu/$CLI_FILENAME
tar -xvf $HOME/tanzu/$CLI_FILENAME -C $HOME/tanzu

cd tanzu

sudo install cli/core/$TANZU_VERSION/tanzu-core-linux_amd64 /usr/local/bin/tanzu

tanzu plugin install --local cli all

cd $HOME

# cluster essentials
# https://docs.vmware.com/en/Cluster-Essentials-for-VMware-Tanzu/1.5/cluster-essentials/deploy.html
# https://network.tanzu.vmware.com/products/tanzu-cluster-essentials/
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME=$PIVNET_USERNAME
export INSTALL_REGISTRY_PASSWORD=$PIVNET_PASSWORD
export INSTALL_BUNDLE=registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle@sha256:79abddbc3b49b44fc368fede0dab93c266ff7c1fe305e2d555ed52d00361b446

mkdir $HOME/tanzu-cluster-essentials

wget https://network.pivotal.io/api/v2/products/tanzu-cluster-essentials/releases/1275537/product_files/1460876/download --header="Authorization: Bearer $access_token" -O $HOME/tanzu-cluster-essentials/$ESSENTIALS_FILENAME
tar -xvf $HOME/tanzu-cluster-essentials/$ESSENTIALS_FILENAME -C $HOME/tanzu-cluster-essentials

cd $HOME/tanzu-cluster-essentials

./install.sh --yes

sudo cp $HOME/tanzu-cluster-essentials/kapp /usr/local/bin/kapp
sudo cp $HOME/tanzu-cluster-essentials/imgpkg /usr/local/bin/imgpkg
sudo cp $HOME/tanzu-cluster-essentials/ytt /usr/local/bin/ytt

cd $HOME

rm $HOME/tanzu/$CLI_FILENAME
rm $HOME/tanzu-cluster-essentials/$ESSENTIALS_FILENAME


# 7. IMPORT TAP PACKAGES
echo
echo "<<< IMPORTING TAP PACKAGES >>>"
echo

acr_name=$(az acr show --name tanzuapplicationregistry | jq ".name" -r)
if [[ $acr_name != "tanzuapplicationregistry" ]]
then
  az acr create --name tanzuapplicationregistry --resource-group tanzu-operations --sku Standard --admin-enabled
fi

acr_secret=$(az acr credential show --name tanzuapplicationregistry | jq -r ".passwords[0].value")

export IMGPKG_REGISTRY_HOSTNAME_0=registry.tanzu.vmware.com
export IMGPKG_REGISTRY_USERNAME_0=$PIVNET_USERNAME
export IMGPKG_REGISTRY_PASSWORD_0=$PIVNET_PASSWORD
export IMGPKG_REGISTRY_HOSTNAME_1=tanzuapplicationregistry.azurecr.io
export IMGPKG_REGISTRY_USERNAME_1=tanzuapplicationregistry
export IMGPKG_REGISTRY_PASSWORD_1=$acr_secret
export INSTALL_REPO=tanzu-application-platform/tap-packages

docker login $IMGPKG_REGISTRY_HOSTNAME_1 -u $IMGPKG_REGISTRY_USERNAME_1 -p $IMGPKG_REGISTRY_PASSWORD_1

imgpkg copy --concurrency 1 -b $IMGPKG_REGISTRY_HOSTNAME_0/tanzu-application-platform/tap-packages:${TAP_VERSION} --to-repo ${IMGPKG_REGISTRY_HOSTNAME_1}/$INSTALL_REPO

kubectl create ns tap-install

tanzu secret registry add tap-registry \
  --username $IMGPKG_REGISTRY_USERNAME_1 --password $IMGPKG_REGISTRY_PASSWORD_1 \
  --server $IMGPKG_REGISTRY_HOSTNAME_1 \
  --export-to-all-namespaces --yes --namespace tap-install

tanzu package repository add tanzu-tap-repository \
  --url $IMGPKG_REGISTRY_HOSTNAME_1/$INSTALL_REPO:$TAP_VERSION \
  --namespace tap-install
