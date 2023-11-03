#!/bin/bash

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION=$(aws configure get region)

#PIVNET CREDENTIALS
export PIVNET_USERNAME=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"pivnet-username\")
export PIVNET_PASSWORD=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"pivnet-password\")
export PIVNET_TOKEN=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"pivnet-token\")

token=$(curl -X POST https://network.pivotal.io/api/v2/authentication/access_tokens -d '{"refresh_token":"'$PIVNET_TOKEN'"}')
access_token=$(echo $token | jq -r .access_token)

curl -i -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $access_token" \
    -X GET https://network.pivotal.io/api/v2/authentication

export TAP_VERSION=1.6.1

tap_view=tap-view
tap_build=tap-build
tap_run=tap-run-eks
#tap_iterate=tap-iterate


# 1. CONFIGURE CLUSTERS
echo
echo "<<< CONFIGURE CLUSTERS >>>"
echo

sleep 5

#CONFIGURE CLUSTERS
clusters=( $tap_view $tap_build $tap_run )

for cluster in "${clusters[@]}" ; do

    kubectl config use-context $cluster

    eksctl utils associate-iam-oidc-provider --cluster $cluster --approve

    # 3. DOWNLOAD AND INSTALL TANZU CLI AND ESSENTIALS
    # https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/install-tanzu-cli.html
    # https://network.tanzu.vmware.com/products/tanzu-application-platform#/releases/1287438/file_groups/12507
    echo
    echo "<<< INSTALLING TANZU CLI AND CLUSTER ESSENTIALS >>>"
    echo

    sleep 5

    export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
    export INSTALL_REGISTRY_USERNAME=$PIVNET_USERNAME
    export INSTALL_REGISTRY_PASSWORD=$PIVNET_PASSWORD
    export INSTALL_BUNDLE=registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle@sha256:54e516b5d088198558d23cababb3f907cd8073892cacfb2496bb9d66886efe15

    cd $HOME/tanzu-cluster-essentials

    ./install.sh --yes
done


# 5. IMPORT TAP PACKAGES
echo
echo "<<< IMPORTING TAP PACKAGES >>>"
echo

sleep 5

registry_secret=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"registry-secret\")

export IMGPKG_REGISTRY_HOSTNAME_0=registry.tanzu.vmware.com
export IMGPKG_REGISTRY_USERNAME_0=$PIVNET_USERNAME
export IMGPKG_REGISTRY_PASSWORD_0=$PIVNET_PASSWORD
export IMGPKG_REGISTRY_HOSTNAME_1=tanzuapplicationregistry.azurecr.io
export IMGPKG_REGISTRY_USERNAME_1=tanzuapplicationregistry
export IMGPKG_REGISTRY_PASSWORD_1=$registry_secret
export INSTALL_REPO=tanzu-application-platform/tap-packages

docker login $IMGPKG_REGISTRY_HOSTNAME_0 -u $IMGPKG_REGISTRY_USERNAME_0 -p $IMGPKG_REGISTRY_PASSWORD_0

imgpkg copy --concurrency 1 -b $IMGPKG_REGISTRY_HOSTNAME_0/tanzu-application-platform/tap-packages:${TAP_VERSION} \
    --to-repo ${IMGPKG_REGISTRY_HOSTNAME_1}/$INSTALL_REPO

for cluster in "${clusters[@]}" ; do

    kubectl config use-context $cluster

    # 6. INSTALL TAP WITH CLI
    echo
    echo "<<< INSTALLING TAP WITH CLI >>>"
    echo

    sleep 5

    kubectl create ns tap-install

    tanzu secret registry add tap-registry \
      --username $IMGPKG_REGISTRY_USERNAME_1 \
      --password $IMGPKG_REGISTRY_PASSWORD_1 \
      --server $IMGPKG_REGISTRY_HOSTNAME_1 \
      --export-to-all-namespaces --yes --namespace tap-install

    tanzu package repository add tanzu-tap-repository \
      --url $IMGPKG_REGISTRY_HOSTNAME_1/$INSTALL_REPO:$TAP_VERSION \
      --namespace tap-install

    tanzu package repository get tanzu-tap-repository --namespace tap-install
done

kubectl config use-context $tap_view


#download sample app code
rm -rf tanzu-java-web-app
git clone https://github.com/nycpivot/tanzu-java-web-app

echo
echo "***DONE***"
echo
echo "1) NEXT -> ~/aria-operations/tap/cli/supply-chain/01-eks-ootb-basic-view-one-run.sh"
echo
echo "OR"
echo
echo "2) NEXT -> ~/aria-operations/tap/cli/supply-chain/01-eks-ootb-basic-view-two-run.sh"
echo
