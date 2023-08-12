#!/bin/bash

echo
read -p "<<< PASTE AWS CREDENTIALS >>>"

# AWS CONFIGURE
# read -p "AWS Access Key: " aws_access_key
# read -p "AWS Secret Access Key: " aws_secret_access_key
read -p "AWS Default Region (us-east-1): " aws_region_code

if [[ -z $aws_region_code ]]
then
    aws_region_code=us-east-1
fi

# aws configure set aws_access_key_id $aws_access_key
# aws configure set aws_secret_access_key $aws_secret_access_key
aws configure set default.region $aws_region_code

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION=$(aws configure get region)


# PIVNET CREDENTIALS
export PIVNET_USERNAME=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"pivnet-username\")
export PIVNET_PASSWORD=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"pivnet-password\")
export PIVNET_TOKEN=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"pivnet-token\")

token=$(curl -X POST https://network.pivotal.io/api/v2/authentication/access_tokens -d '{"refresh_token":"'$PIVNET_TOKEN'"}')
access_token=$(echo $token | jq -r .access_token)

curl -i -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $access_token" \
    -X GET https://network.pivotal.io/api/v2/authentication


# DOWNLOAD AND INSTALL TANZU CLI
# https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/install-tanzu-cli.html
# https://network.tanzu.vmware.com/products/tanzu-application-platform#/releases/1287438/file_groups/12507
echo
echo "<<< INSTALLING TANZU CLI AND CLUSTER ESSENTIALS >>>"
echo

sleep 5

export TANZU_CLI_NO_INIT=true
export TANZU_VERSION=v0.90.1

export CLI_FILENAME=tanzu-cli-linux-amd64.tar.gz
export ESSENTIALS_FILENAME=tanzu-cluster-essentials-linux-amd64-1.6.0.tgz

export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME=$PIVNET_USERNAME
export INSTALL_REGISTRY_PASSWORD=$PIVNET_PASSWORD

mkdir $HOME/tanzu

wget https://network.pivotal.io/api/v2/products/tanzu-application-platform/releases/1346010/product_files/1539749/download \
    --header="Authorization: Bearer $access_token" -O $HOME/tanzu/$CLI_FILENAME
tar -xvf $HOME/tanzu/$CLI_FILENAME -C $HOME/tanzu

cd tanzu

sudo install $TANZU_VERSION/tanzu-cli-linux_amd64 /usr/local/bin/tanzu

tanzu plugin install --group vmware-tap/default:v1.6.1
#tanzu plugin install --local cli all

rm $CLI_FILENAME

cd $HOME


# DOWNLOAD AND INSTALL CLUSTER ESSENTIALS
# https://docs.vmware.com/en/Cluster-Essentials-for-VMware-Tanzu/1.5/cluster-essentials/deploy.html
# https://network.tanzu.vmware.com/products/tanzu-cluster-essentials/
echo
echo "<<< INSTALLING TANZU CLUSTER ESSENTIALS >>>"
echo

sleep 5

export INSTALL_BUNDLE=registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle@sha256:54e516b5d088198558d23cababb3f907cd8073892cacfb2496bb9d66886efe15

mkdir $HOME/tanzu-cluster-essentials

wget https://network.pivotal.io/api/v2/products/tanzu-cluster-essentials/releases/1321952/product_files/1526701/download \
    --header="Authorization: Bearer $access_token" -O $HOME/tanzu-cluster-essentials/$ESSENTIALS_FILENAME
tar -xvf $HOME/tanzu-cluster-essentials/$ESSENTIALS_FILENAME -C $HOME/tanzu-cluster-essentials

docker login $INSTALL_REGISTRY_HOSTNAME -u $INSTALL_REGISTRY_USERNAME -p $INSTALL_REGISTRY_PASSWORD

cd $HOME/tanzu-cluster-essentials

./imgpkg copy \
  -b registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle@sha256:54e516b5d088198558d23cababb3f907cd8073892cacfb2496bb9d66886efe15 \
  --to-tar cluster-essentials-bundle-1.6.0.tar \
  --include-non-distributable-layers

sudo cp $HOME/tanzu-cluster-essentials/kapp /usr/local/bin/kapp
sudo cp $HOME/tanzu-cluster-essentials/imgpkg /usr/local/bin/imgpkg

rm $HOME/tanzu-cluster-essentials/$ESSENTIALS_FILENAME

cd $HOME

echo
echo "***DONE***"
echo
echo "NEXT -> ~/aria-operations/tap/tdp/04-tanzu-multicluster-vpc.sh"
echo
