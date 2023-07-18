#!/bin/bash

AWS_REGION=$(aws configure get region)

# CREATE TMC-AWS CREDENTIAL
aws cloudformation create-stack --stack-name eks-tmc-cloud-vmware-com-10283133551681270421 \
    --template-url https://tmc-mkp.s3.us-west-2.amazonaws.com/tmc_eks.template \
    --parameters ParameterKey=CredentialName,ParameterValue=aws-cluster-operations ParameterKey=AccountID,ParameterValue=630260974543 ParameterKey=OrgID,ParameterValue=3be385a3-d15d-4f70-b779-5e69b8b2a2cc ParameterKey=RoleName,ParameterValue=main/mkp ParameterKey=ExternalID,ParameterValue=96680801-9e79-5bda-ab8e-b0d04e1a3c81 ParameterKey=GeneratedTemplateID,ParameterValue=10283133551681270421 \
    --capabilities CAPABILITY_NAMED_IAM

aws cloudformation wait stack-create-complete --stack-name eks-tmc-cloud-vmware-com-10283133551681270421 --region ${AWS_REGION}

output=$(aws cloudformation describe-stacks \
    --stack-name eks-tmc-cloud-vmware-com-10283133551681270421 \
    --region ${AWS_REGION} \
    --query "Stacks[0].Outputs[?OutputKey=='Message'].OutputValue" \
    --output text)

role_arn=$(sed '3q;d' <<< $output)

#tanzu mission-control account credential get aws-cluster-operations > aws-cluster-operations.yaml

aws_cluster_credential=aws-cluster-credential
if test -f "${aws_cluster_credential}.yaml"; then
  rm ${aws_cluster_credential}.yaml
fi

cat <<EOF | tee ${aws_cluster_credential}.yaml
fullName:
  name: ${aws_cluster_credential}
  orgId: 3be385a3-d15d-4f70-b779-5e69b8b2a2cc
meta:
  annotations:
    GeneratedTemplateID: "10283133551681270421"
    x-customer-domain: customer0.tmc.cloud.vmware.com
  creationTime: "2023-07-17T18:17:51.002648Z"
  labels:
    tmc.cloud.vmware.com/cred-cloudformation-key: "10283133551681270421"
  resourceVersion: "1"
spec:
  capability: MANAGED_K8S_PROVIDER
  data:
    awsCredential:
      iamRole:
        ${role_arn}
  meta:
    provider: AWS_EKS
EOF

tmc account credential create -f aws-cluster-credential.yaml
#tanzu mission-control account credential create --data-values-file ${aws_cluster_credential}.yaml


