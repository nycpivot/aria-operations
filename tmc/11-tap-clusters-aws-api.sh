#!/bin/bash

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION=$(aws configure get region)

generated_template_stack_id=13637809161061075293
full_tmc_stack_name=eks-tmc-cloud-vmware-com-${generated_template_stack_id}
tanzu_vpc_stack_name=tanzu-vpc-stack
tmc_org=3be385a3-d15d-4f70-b779-5e69b8b2a2cc
tmc_account_id=630260974543


# 1. CREATE IAM ROLES (THIS IS STEP 2 IN TMC CONSOLE)
aws cloudformation create-stack --stack-name ${full_tmc_stack_name} \
  --template-url https://tmc-mkp.s3.us-west-2.amazonaws.com/tmc_eks.template \
  --parameters ParameterKey=CredentialName,ParameterValue=aws-account-credential ParameterKey=AccountID,ParameterValue=${tmc_account_id} ParameterKey=OrgID,ParameterValue=3be385a3-d15d-4f70-b779-5e69b8b2a2cc ParameterKey=RoleName,ParameterValue=main/mkp ParameterKey=ExternalID,ParameterValue=50ed8bef-c8c6-5ba2-8501-992e94a0fedc ParameterKey=GeneratedTemplateID,ParameterValue=${generated_template_stack_id} \
  --capabilities CAPABILITY_NAMED_IAM

aws cloudformation create-stack \
  --stack-name ${tanzu_vpc_stack_name} \
  --template-url https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2020-10-29/amazon-eks-vpc-private-subnets.yaml

aws cloudformation wait stack-create-complete --stack-name ${full_tmc_stack_name} --region ${AWS_REGION}
aws cloudformation wait stack-create-complete --stack-name ${tanzu_vpc_stack_name} --region ${AWS_REGION}

output=$(aws cloudformation describe-stacks \
    --stack-name ${full_tmc_stack_name} \
    --query "Stacks[0].Outputs[?OutputKey=='Message'].OutputValue" \
    --region ${AWS_REGION} \
    --output text)

role_arn=$(sed '3q;d' <<< $output)

echo ${role_arn}
echo

read -p "Enter to continue..."
echo


# GET REFRESH TOKEN, EXCHANGE IT FOR AN ACCESS TOKEN FOR THE REMAINDER
tmc_token=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"tmc-token\")

if test -f tmc-token.json; then
  rm tmc-token.json
fi

curl -X POST https://console.cloud.vmware.com/csp/gateway/am/api/auth/api-tokens/authorize \
  -H "Accept: application/json" -H "Content-Type: application/x-www-form-urlencoded" \
  -d "refresh_token=${tmc_token}" \
  -o tmc-token.json

access_token=$(cat tmc-token.json | jq .access_token -r)


# 2. CREATE A TMC CLUSTER GROUP
tmc_cluster_group=tmc-operations

cat <<EOF | tee ${tmc_cluster_group}.yaml
fullName:
  name: ${tmc_cluster_group}
EOF

tanzu mission-control clustergroup create -f ${tmc_cluster_group}.yaml

sleep 10


# 3. CREATE TMC AWS ACCOUNT CREDENTIAL (THIS IS STEP 1 IN TMC CONSOLE)
# THIS ACCOUNT CREDENTIAL WILL REFERENCE THE CLUSTERLIFECYCLE IAM ROLE
# CREATED AND OUTPUT FROM THE CF STACK ABOVE
# (TMC CLI)
aws_account_credential=aws-account-credential

if test -f ${aws_account_credential}.yaml; then
  rm ${aws_account_credential}.yaml
fi

cat <<EOF | tee ${aws_account_credential}.yaml # TMC CLI VERSION (THIS WORKS)
fullName:
  name: ${aws_account_credential}
  orgId: 3be385a3-d15d-4f70-b779-5e69b8b2a2cc
meta:
  annotations:
    GeneratedTemplateID: "${generated_template_stack_id}"
    x-customer-domain: customer0.tmc.cloud.vmware.com
  labels:
    tmc.cloud.vmware.com/cred-cloudformation-key: "${generated_template_stack_id}"
  resourceVersion: "1"
spec:
  capability: MANAGED_K8S_PROVIDER
  data:
    awsCredential:
      iamRole:
        arn: ${role_arn}
  meta:
    provider: AWS_EKS
EOF

tmc account credential create -f ${aws_account_credential}.yaml

sleep 900


# *********************************************************************************
# NONE OF THE CLIs (OLD/NEW) WORK FOR THE FOLLOWING OBJECTS (EKSCLUSTER & NODEPOOL)
# BUT THE APIs SEEM TO WORK OK - THESE WILL BE REPLACED WHEN THE CLI WORKS
# *********************************************************************************

# 4. CREATE VPC
vpc_id=$(aws ec2 describe-vpcs --query "Vpcs[?Tags[?Value=='tanzu-vpc-stack-VPC']].VpcId" --output text)
subnets=$(aws ec2 describe-subnets --query "Subnets[?VpcId=='${vpc_id}']".SubnetId --output text)

subnet1=$(echo $subnets | awk -F ' ' '{print $1}')
subnet2=$(echo $subnets | awk -F ' ' '{print $2}')
subnet3=$(echo $subnets | awk -F ' ' '{print $3}')
subnet4=$(echo $subnets | awk -F ' ' '{print $4}')


# 5. CREATE CLUSTERS
tap_view=tap-view
tap_build=tap-build
tap_run_eks=tap-run-eks

clusters=( $tap_view $tap_build $tap_run_eks )

for cluster in "${clusters[@]}" ; do

if test -f ${cluster}.json; then
  rm ${cluster}.json
fi

cat <<EOF | tee ${cluster}.json
{
  "eksCluster": {
    "fullName": {
      "orgId": "${tmc_org}",
      "credentialName": "${aws_account_credential}",
      "region": "${AWS_REGION}",
      "name": "${cluster}"
    },
    "spec": {
      "clusterGroupName": "${tmc_cluster_group}",
      "config": {
        "version": "1.25",
        "roleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/control-plane.${generated_template_stack_id}.eks.tmc.cloud.vmware.com",
        "vpc": {
          "enablePrivateAccess": true,
          "enablePublicAccess": true,
          "publicAccessCidrs": [
            "0.0.0.0/0"
          ],
          "subnetIds": [
            "${subnet1}",
            "${subnet2}",
            "${subnet3}",
            "${subnet4}"
          ]
        }
      }
    }
  }
}
EOF

cluster_data=$(cat ${cluster}.json | jq -c .)

curl -X POST https://customer0.tmc.cloud.vmware.com/v1alpha1/eksclusters \
  -H "Accept: application/json" -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Authorization: Bearer ${access_token}" \
  -d ${cluster_data}

sleep 60

# NODE-POOL
cluster_nodepool=${cluster}-nodepool

if test -f ${cluster_nodepool}.json; then
  rm ${cluster_nodepool}.json
fi

cat <<EOF | tee ${cluster_nodepool}.json
{
  "nodepool": {
    "fullName": {
      "orgId": "${tmc_org}",
      "credentialName": "${aws_account_credential}",
      "region": "${AWS_REGION}",
      "eksClusterName": "${cluster}",
      "name": "${cluster_nodepool}"
    },
    "spec": {
      "roleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/worker.${generated_template_stack_id}.eks.tmc.cloud.vmware.com",
      "subnetIds": [
        "${subnet1}",
        "${subnet2}",
        "${subnet3}",
        "${subnet4}"
      ]
    }
  }
}
EOF

cluster_nodepool_data=$(cat ${cluster_nodepool}.json | jq -c .)

curl -X POST https://customer0.tmc.cloud.vmware.com/v1alpha1/eksclusters/${cluster}/nodepools \
  -H "Accept: application/json" -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Authorization: Bearer ${access_token}" \
  -d ${cluster_nodepool_data}
done

sleep 1200 # give 20 minutes for all clusters to be created


# UPDATE EKS KUBECONFIGS
aws eks update-kubeconfig --name ${tap_view} --region $AWS_REGION
aws eks update-kubeconfig --name ${tap_build} --region $AWS_REGION
aws eks update-kubeconfig --name ${tap_run_eks} --region $AWS_REGION

arn=arn:aws:eks:$AWS_REGION:$AWS_ACCOUNT_ID:cluster
kubectl config rename-context ${arn}/${tap_view} ${tap_view}
kubectl config rename-context ${arn}/${tap_build} ${tap_build}
kubectl config rename-context ${arn}/${tap_run_eks} ${tap_run_eks}


# DOWNLOAD TMC KUBE CONFIGS (CLIs DON'T WORK, AGAIN)
tap_view_config=$(tanzu mission-control cluster kubeconfig get eks.aws-account-credential.us-east-1.tap-view --management-cluster-name eks --provisioner-name eks)
tap_build_config=$(tanzu mission-control cluster kubeconfig get eks.aws-account-credential.us-east-1.tap-build --management-cluster-name eks --provisioner-name eks)
tap_run_eks_config=$(tanzu mission-control cluster kubeconfig get eks.aws-account-credential.us-east-1.tap-run-eks --management-cluster-name eks --provisioner-name eks)

tap_view_kubeconfig=${tap_view}-kubeconfig
tap_build_kubeconfig=${tap_build}-kubeconfig
tap_run_eks_kubeconfig=${tap_run_eks}-kubeconfig

echo ${tap_view_config} >> .kube/${tap_view_kubeconfig}
echo ${tap_build_config} >> .kube/${tap_build_kubeconfig}
echo ${tap_run_eks_config} >> .kube/${tap_run_eks_kubeconfig}

# OPEN THE AWS-AUTH CONFIG MAP (CONTAINS THE TMC USER WITH PERMISSIONS)
# https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/services/tanzumc-using/GUID-EF3A426A-6880-4CE3-95AD-83D4B244CB60.html
# https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html - USE EKSCTL INSTEAD OF MANUAL
# kubectl create clusterrolebinding tmc-clusterrole-binding \
#   --clusterrole=cluster-admin --group=tmc-cluster-access --kubeconfig .kube/tmc-config

# ADD AWS USER TO AWS-AUTH CONFIG MAP OF EACH CLUSTER
kubectl config use-context ${tap_view}

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::964978768106:role/worker.13637809161061075293.eks.tmc.cloud.vmware.com
      username: system:node:{{EC2PrivateDNSName}}
  mapUsers: |
    - groups:
      - system:masters
      userarn: arn:aws:iam::964978768106:user/mijames@vmware.com
      username: mijames@vmware.com
EOF

kubectl edit cm aws-auth -n kube-system --kubeconfig=.kube/${tap_view_kubeconfig}




# # THE FOLLOWING IS FOR SHOWING EVERYTHING IN THE CONSOLE THAT TMC ACCOUNT DID 
# curl -o eks-console-full-access.yaml https://amazon-eks.s3.us-west-2.amazonaws.com/docs/eks-console-full-access.yaml
# kubectl apply -f eks-console-full-access.yaml

# # FIRST, FETCH THE KUBE CONFIG FROM THE TMC SO OPERATIONS CAN BE PERFORMED ON THE CLUSTER
# # THE FOLLOWING IS TO UPDATE THE AWS-AUTH TO GIVE MYSELF KUBECTL ACCESS TO THE CLUSTERS CREATED BY TMC
# curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/eks-connector/manifests/eks-connector-console-roles/eks-connector-clusterrole.yaml

# vim eks-connector-clusterrole.yaml

# kubectl apply -f eks-connector-clusterrole.yaml
