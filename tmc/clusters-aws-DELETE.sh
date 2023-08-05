#!/bin/bash

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION=$(aws configure get region)

generated_template_stack_id=13637809161061075293
full_tmc_stack_name=eks-tmc-cloud-vmware-com-${generated_template_stack_id}
tanzu_vpc_stack_name=tanzu-multicluster-vpc-stack
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


# 2. CREATE A TMC CLUSTER GROUP
tmc_cluster_group=tmc-operations

cat <<EOF | tee ${tmc_cluster_group}.yaml
fullName:
  name: ${tmc_cluster_group}
EOF

tanzu mission-control clustergroup create -f ${tmc_cluster_group}.yaml


# 3. CREATE TMC AWS ACCOUNT CREDENTIAL (THIS IS STEP 1 IN TMC CONSOLE)
# THIS ACCOUNT CREDENTIAL WILL REFERENCE THE CLUSTERLIFECYCLE IAM ROLE
# CREATED AND OUTPUT FROM THE CF STACK ABOVE
# (TMC CLI)
aws_account_credential=aws-account-credential

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


# *********************************************************************************
# NONE OF THE CLIs (OLD/NEW) WORK FOR THE FOLLOWING OBJECTS (EKSCLUSTER & NODEPOOL)
# BUT THE APIs SEEM TO WORK OK - THESE WILL BE REPLACED WHEN THE CLI WORKS
# *********************************************************************************
tmc_token=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"tmc-token\")

rm tmc-token.json

curl -X POST https://console.cloud.vmware.com/csp/gateway/am/api/auth/api-tokens/authorize \
  -H "Accept: application/json" -H "Content-Type: application/x-www-form-urlencoded" \
  -d "refresh_token=${tmc_token}" \
  -o tmc-token.json

access_token=$(cat tmc-token.json | jq .access_token -r)


# 4. CREATE NEW EKS CLUSTER
eks_cluster_name=tap-dotnet-core-web-mvc

vpc_id=$(aws ec2 describe-vpcs --query "Vpcs[?Tags[?Value=='tanzu-multicluster-vpc-stack-VPC']].VpcId" --output text)
subnets=$(aws ec2 describe-subnets --query "Subnets[?VpcId=='${vpc_id}']".SubnetId --output text)

subnet1=$(echo $subnets | awk -F ' ' '{print $1}')
subnet2=$(echo $subnets | awk -F ' ' '{print $2}')
subnet3=$(echo $subnets | awk -F ' ' '{print $3}')
subnet4=$(echo $subnets | awk -F ' ' '{print $4}')

cat <<EOF | tee ${eks_cluster_name}.yaml
'{
  "eksCluster": {
    "fullName": {
      "orgId": "${tmc_org}",
      "credentialName": "${aws_account_credential}",
      "region": "${AWS_REGION}",
      "name": "${eks_cluster_name}"
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
}'
EOF

# COPY THE CONTENTS FROM THE ABOVE FILE, PASTE IT INTO A BROWSER TO FLATTEN IT TO ONE LINE
# THEN COPY AND PASTE THAT ONE LINE INTO THE BELOW CURL COMMAND FOLLOWING THE -d
# HAVE TO FIGURE OUT WHY CURL REJECTS A VARIABLE, VARIABLES WITHIN QUOTES AND SINGLE QUOTES ARE IGNORED

#sed -z "s/\n//g" ${eks_cluster_name}.yaml > eks-payload.json

curl -X POST https://customer0.tmc.cloud.vmware.com/v1alpha1/eksclusters \
  -H "Accept: application/json" -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Authorization: Bearer ${access_token}" \
  -d 

curl https://customer0.tmc.cloud.vmware.com/v1alpha1/eksclusters \
  -H "Accept: application/json" -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${access_token}"

# THE TMC OR TANZU CLIs JUST DO NOT WORK, BUT WHEN THEY EVENTUALLY DO, REPLACE API CALL ABOVE WITH THE FOLLOWING
# cat <<EOF | tee ${eks_cluster_name}.yaml
# fullName:
#   credentialName: ${aws_account_credential}
#   name: ${eks_cluster_name}
#   region: ${AWS_REGION}
# spec:
#   clusterGroupName: ${tmc_cluster_group}
#   config:
#     roleArn: arn:aws:iam::${AWS_ACCOUNT_ID}:role/control-plane.${generated_template_stack_id}.eks.tmc.cloud.vmware.com
#     version: "1.25"
#     vpc:
#       enablePrivateAccess: true
#       enablePublicAccess: true
#       publicAccessCidrs:
#       - 0.0.0.0/0
#       subnetIds:
#       - ${subnet1}
#       - ${subnet2}
#       - ${subnet3}
#       - ${subnet4}
# EOF

# tanzu mission-control ekscluster create -f ${eks_cluster_name}.yaml
# #tmc ekscluster create -f ${eks_cluster_name}.yaml


# CREATE THE EKSCLUSTER NODE POOL
eks_cluster_nodepool=${eks_cluster_name}-nodepool

cat <<EOF | tee ${eks_cluster_nodepool}.yaml
'{
  "nodepool": {
    "fullName": {
      "orgId": "${tmc_org}",
      "credentialName": "${aws_account_credential}",
      "region": "${AWS_REGION}",
      "eksClusterName": "${eks_cluster_name}",
      "name": "${eks_cluster_nodepool}"
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
}'
EOF

# COPY THE CONTENTS FROM THE ABOVE FILE, PASTE IT INTO A BROWSER TO FLATTEN IT TO ONE LINE
# THEN COPY AND PASTE THAT ONE LINE INTO THE BELOW CURL COMMAND FOLLOWING THE -d
# HAVE TO FIGURE OUT WHY CURL REJECTS A VARIABLE, VARIABLES WITHIN QUOTES AND SINGLE QUOTES ARE IGNORED
curl -X POST https://customer0.tmc.cloud.vmware.com/v1alpha1/eksclusters/${eks_cluster_name}/nodepools \
  -H "Accept: application/json" -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Authorization: Bearer ${access_token}" \
  -d '{ "nodepool": { "fullName": { "orgId": "3be385a3-d15d-4f70-b779-5e69b8b2a2cc", "credentialName": "aws-account-credential", "region": "us-east-1", "eksClusterName": "tap-dotnet-core-web-mvc", "name": "tap-dotnet-core-web-mvc-nodepool" }, "spec": { "roleArn": "arn:aws:iam::964978768106:role/worker.13637809161061075293.eks.tmc.cloud.vmware.com", "subnetIds": [ "subnet-01e2d880634642a83", "subnet-038baaa15a2837fe3", "subnet-0d6c0d493173f2004", "subnet-08572d1daa8b44e11" ] } } }'

# curl https://customer0.tmc.cloud.vmware.com/v1alpha1/clusters/tap-dotnet-core-web-mvc/nodepools \
#   -H "Accept: application/json" -H "Content-Type: application/json" \
#   -H "Authorization: Bearer ${access_token}"


# DOWNLOAD TMC KUBE CONFIG

# OPEN THE AWS-AUTH CONFIG MAP (CONTAINS THE TMC USER WITH PERMISSIONS)
# https://docs.vmware.com/en/VMware-Tanzu-Mission-Control/services/tanzumc-using/GUID-EF3A426A-6880-4CE3-95AD-83D4B244CB60.html
# https://docs.aws.amazon.com/eks/latest/userguide/add-user-role.html - USE EKSCTL INSTEAD OF MANUAL
kubectl create clusterrolebinding tmc-clusterrole-binding \
  --clusterrole=cluster-admin --group=tmc-cluster-access --kubeconfig .kube/tmc-config

kubectl edit cm aws-auth -n kube-system --kubeconfig=.kube/tmc-config

# IT SHOULD LOOK LIKE THIS:
# apiVersion: v1
# data:
#   mapRoles: |
#     - groups:
#       - system:bootstrappers
#       - system:nodes
#       rolearn: arn:aws:iam::964978768106:role/worker.13637809161061075293.eks.tmc.cloud.vmware.com
#       username: system:node:{{EC2PrivateDNSName}}
#   mapUsers: |
#     - groups:
#       - system:masters
#       userarn: arn:aws:iam::964978768106:user/mijames@vmware.com
#       username: mijames@vmware.com
# kind: ConfigMap
# metadata:
#   creationTimestamp: "2023-07-27T21:01:06Z"
#   name: aws-auth
#   namespace: kube-system
#   resourceVersion: "3072"
#   uid: 9a8f4070-9f0a-4aca-ba08-9eb9d7f1029f

# UPDATE REGULAR CONFIG
aws eks update-kubeconfig --name ${eks_cluster_name} --region $AWS_REGION

arn=arn:aws:eks:$AWS_REGION:$AWS_ACCOUNT_ID:cluster
kubectl config rename-context ${arn}/${eks_cluster_name} ${eks_cluster_name}



# # THE FOLLOWING IS FOR SHOWING EVERYTHING IN THE CONSOLE THAT TMC ACCOUNT DID 
# curl -o eks-console-full-access.yaml https://amazon-eks.s3.us-west-2.amazonaws.com/docs/eks-console-full-access.yaml
# kubectl apply -f eks-console-full-access.yaml

# # FIRST, FETCH THE KUBE CONFIG FROM THE TMC SO OPERATIONS CAN BE PERFORMED ON THE CLUSTER
# # THE FOLLOWING IS TO UPDATE THE AWS-AUTH TO GIVE MYSELF KUBECTL ACCESS TO THE CLUSTERS CREATED BY TMC
# curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/eks-connector/manifests/eks-connector-console-roles/eks-connector-clusterrole.yaml

# vim eks-connector-clusterrole.yaml

# kubectl apply -f eks-connector-clusterrole.yaml





















curl -X POST https://customer0.tmc.cloud.vmware.com/v1alpha1/eksclusters/tap-dotnet-core-web-mvc/nodepools \
  -H "Accept: application/json" -H "Content-Type: application/x-www-form-urlencoded" \
  -H "Authorization: Bearer ${access_token}" \
  -d '{ "nodepool": { "fullName": { "orgId": "3be385a3-d15d-4f70-b779-5e69b8b2a2cc", "credentialName": "aws-account-credential", "region": "us-east-1", "eksClusterName": "tap-dotnet-core-web-mvc", "name": "tap-dotnet-core-web-mvc-nodepool" }, "spec": { "roleArn": "arn:aws:iam::964978768106:role/worker.13637809161061075293.eks.tmc.cloud.vmware.com", "subnetIds": [ "subnet-01e2d880634642a83", "subnet-038baaa15a2837fe3", "subnet-0d6c0d493173f2004", "subnet-08572d1daa8b44e11" ] } } }'

