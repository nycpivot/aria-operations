#!/bin/bash

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION=$(aws configure get region)

generated_template_stack_id=13637809161061075293
full_tmc_stack_name=eks-tmc-cloud-vmware-com-${generated_template_stack_id}
tap_vpc_stack_name=tap-multicluster-vpc-stack
tmc_account_id=630260974543


# 1. CREATE IAM ROLES (THIS IS STEP 2 IN TMC CONSOLE)
aws cloudformation create-stack --stack-name ${full_tmc_stack_name} \
  --template-url https://tmc-mkp.s3.us-west-2.amazonaws.com/tmc_eks.template \
  --parameters ParameterKey=CredentialName,ParameterValue=aws-account-credential ParameterKey=AccountID,ParameterValue=${tmc_account_id} ParameterKey=OrgID,ParameterValue=3be385a3-d15d-4f70-b779-5e69b8b2a2cc ParameterKey=RoleName,ParameterValue=main/mkp ParameterKey=ExternalID,ParameterValue=50ed8bef-c8c6-5ba2-8501-992e94a0fedc ParameterKey=GeneratedTemplateID,ParameterValue=${generated_template_stack_id} \
  --capabilities CAPABILITY_NAMED_IAM

aws cloudformation create-stack \
  --stack-name ${tap_vpc_stack_name} \
  --template-url https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2020-10-29/amazon-eks-vpc-private-subnets.yaml

aws cloudformation wait stack-create-complete --stack-name ${full_tmc_stack_name} --region ${AWS_REGION}
aws cloudformation wait stack-create-complete --stack-name ${tap_vpc_stack_name} --region ${AWS_REGION}

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

# cat <<EOF | tee ${aws_account_credential}.yaml # TANZU MISSION-CONTROL CLI VERSION (THIS SUCKS)
# fullName:
#   name: "${aws_account_credential}"
# spec:
#   capability: MANAGED_K8S_PROVIDER
#   data:
#       awsCredential:
#         accountId: "${AWS_ACCOUNT_ID}"
#         iamRole:
#           arn: "${role_arn}"
#           extId: "${generated_template_stack_id}"
# EOF

#tanzu mission-control account credential create -f ${aws_account_credential}.yaml


# 4. CREATE NEW EKS CLUSTER
tmc_cluster_group=tmc-operations
eks_cluster_name=tap-dotnet-core-web-mvc

vpc_id=$(aws ec2 describe-vpcs --query "Vpcs[?Tags[?Value=='tap-multicluster-vpc-stack-VPC']].VpcId" --output text)
subnets=$(aws ec2 describe-subnets --query "Subnets[?VpcId=='${vpc_id}']".SubnetId --output text)

subnet1=$(echo $subnets | awk -F ' ' '{print $1}')
subnet2=$(echo $subnets | awk -F ' ' '{print $2}')
subnet3=$(echo $subnets | awk -F ' ' '{print $3}')
subnet4=$(echo $subnets | awk -F ' ' '{print $4}')

cat <<EOF | tee ${eks_cluster_name}.yaml
fullName:
  credentialName: ${aws_account_credential}
  name: ${eks_cluster_name}
  region: ${AWS_REGION}
spec:
  clusterGroupName: ${tmc_cluster_group}
  config:
    roleArn: arn:aws:iam::${AWS_ACCOUNT_ID}:role/control-plane.${generated_template_stack_id}.eks.tmc.cloud.vmware.com
    version: "1.25"
    vpc:
      enablePrivateAccess: true
      enablePublicAccess: true
      publicAccessCidrs:
      - 0.0.0.0/0
      subnetIds:
      - ${subnet1}
      - ${subnet2}
      - ${subnet3}
      - ${subnet4}
EOF

#tanzu mission-control ekscluster create -f ${eks_cluster_name}.yaml
tmc ekscluster create -f ${eks_cluster_name}.yaml

#tanzu mission-control ekscluster get tap-dotnet-core-web-mvc --credential-name aws-account-credential --region us-east-1

curl -o eks-console-full-access.yaml https://amazon-eks.s3.us-west-2.amazonaws.com/docs/eks-console-full-access.yaml

kubectl apply -f eks-console-full-access.yaml


curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/eks-connector/manifests/eks-connector-console-roles/eks-connector-clusterrole.yaml

vim eks-conn

kubectl apply -f eks-connector-clusterrole.yaml
