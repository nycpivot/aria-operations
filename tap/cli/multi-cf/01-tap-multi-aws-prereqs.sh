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


# 1. CREATE CLUSTERS
echo
echo "<<< CREATING CLUSTERS >>>"
echo

sleep 5

# CREATE EKS ROLES
# vmware_eks_role=vmware-eks-role
# vmware_nodegroup_role=vmware-nodegroup-role

# cat <<EOF | tee eks-trust-policy.json
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/PowerUser"
#       },
#       "Action": "sts:AssumeRoleWithWebIdentity",
#       "Condition": {
#         "StringEquals": {
#           "arn:aws:iam::${AWS_ACCOUNT_ID}:role/PowerUser:aud": "sts.amazonaws.com"
#         }
#       }
#     }
#   ]
# }
# EOF

# aws iam create-role --role-name ${vmware_eks_role} --assume-role-policy-document eks-trust-policy.json --no-cli-pager
# aws iam create-role --role-name ${vmware_nodegroup_role} --assume-role-policy-document eks-trust-policy.json --no-cli-pager

# aws iam attach-role-policy --role-name ${vmware_eks_role} \
#   --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy \
#   --no-cli-pager

# aws iam attach-role-policy --role-name ${vmware_nodegroup_role} \
#   --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly \
#   --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy \
#   --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy \
#   --no-cli-pager

# rm eks-trust-policy.json


aws cloudformation create-stack --stack-name tap-multicluster-stack --region $AWS_REGION \
    --template-body file:///home/ubuntu/aria-operations/tap/config/tap-multicluster-stack-${AWS_REGION}.yaml \
    --parameters file://vpc-params.json
    
aws cloudformation wait stack-create-complete --stack-name tap-multicluster-stack --region $AWS_REGION

arn=arn:aws:eks:$AWS_REGION:$AWS_ACCOUNT_ID:cluster

aws eks update-kubeconfig --name $tap_view --region $AWS_REGION
aws eks update-kubeconfig --name $tap_build --region $AWS_REGION
aws eks update-kubeconfig --name $tap_run --region $AWS_REGION
#aws eks update-kubeconfig --name $tap_iterate --region $AWS_REGION

kubectl config rename-context ${arn}/$tap_view $tap_view
kubectl config rename-context ${arn}/$tap_build $tap_build
kubectl config rename-context ${arn}/$tap_run $tap_run
# #kubectl config rename-context ${arn}/$tap_iterate $tap_iterate

#CONFIGURE CLUSTERS
clusters=( $tap_view $tap_build $tap_run )

for cluster in "${clusters[@]}" ; do

    kubectl config use-context $cluster

    eksctl utils associate-iam-oidc-provider --cluster $cluster --approve

    # 2. INSTALL CSI PLUGIN (REQUIRED FOR K8S 1.23+)
    echo
    echo "<<< INSTALLING CSI PLUGIN ($cluster) >>>"
    echo

    sleep 5

    rolename=${cluster}-csi-driver-role-${AWS_REGION}

    aws eks create-addon \
      --cluster-name $cluster \
      --addon-name aws-ebs-csi-driver \
      --service-account-role-arn "arn:aws:iam::$AWS_ACCOUNT_ID:role/$rolename" \
      --no-cli-pager

    # #https://docs.aws.amazon.com/eks/latest/userguide/csi-iam-role.html
    # aws eks describe-cluster --name $cluster --query "cluster.identity.oidc.issuer" --output text

    #https://docs.aws.amazon.com/eks/latest/userguide/csi-iam-role.html
    oidc_id=$(aws eks describe-cluster --name $cluster --query "cluster.identity.oidc.issuer" --output text | awk -F '/' '{print $5}')
    echo "OIDC Id: $oidc_id"

    # Check if a IAM OIDC provider exists for the cluster
    # https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html
    if [[ -z $(aws iam list-open-id-connect-providers | grep $oidc_id) ]]; then
      echo "Creating IAM OIDC provider"
      if ! [ -x "$(command -v eksctl)" ]; then
        echo "Error `eksctl` CLI is required, https://eksctl.io/introduction/#installation" >&2
        exit 1
      fi

      eksctl utils associate-iam-oidc-provider --cluster $cluster --approve
    fi

cat <<EOF | tee aws-ebs-csi-driver-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/oidc.eks.$AWS_REGION.amazonaws.com/id/$oidc_id"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.$AWS_REGION.amazonaws.com/id/$oidc_id:aud": "sts.amazonaws.com",
          "oidc.eks.$AWS_REGION.amazonaws.com/id/$oidc_id:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }
  ]
}
EOF

    aws iam create-role \
      --role-name $rolename \
      --assume-role-policy-document file://"aws-ebs-csi-driver-trust-policy.json" \
      --no-cli-pager
      
    aws iam attach-role-policy \
      --role-name $rolename \
      --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
      --no-cli-pager
      
    kubectl annotate serviceaccount ebs-csi-controller-sa \
        eks.amazonaws.com/role-arn=arn:aws:iam::$AWS_ACCOUNT_ID:role/$rolename \
        -n kube-system --overwrite

    rm aws-ebs-csi-driver-trust-policy.json
    
    echo


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
