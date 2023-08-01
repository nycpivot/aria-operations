#!/bin/bash

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION=$(aws configure get region)

stackname=tanzu-multicluster-vpc-stack

aws cloudformation create-stack --stack-name ${stackname} --region $AWS_REGION \
    --template-url https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2020-10-29/amazon-eks-vpc-private-subnets.yaml

aws cloudformation wait stack-create-complete --stack-name ${stackname} --region $AWS_REGION

vpcId=$(aws cloudformation describe-stacks \
    --stack-name ${stackname} \
    --query "Stacks[0].Outputs[?OutputKey=='VpcId'].OutputValue" \
    --region ${AWS_REGION} \
    --output text)

if test -f "vpc-params.json"; then
  rm vpc-params.json
fi

cat <<EOF | tee vpc-params.json
[
    {
        "ParameterKey": "VpcId",
        "ParameterValue": "${vpcId}
    }
]
EOF
