#!/bin/bash

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION=$(aws configure get region)

stackname=tanzu-vpc-stack

aws cloudformation create-stack --stack-name ${stackname} --region $AWS_REGION \
    --template-url https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2020-10-29/amazon-eks-vpc-private-subnets.yaml

aws cloudformation wait stack-create-complete --stack-name ${stackname} --region $AWS_REGION

vpcId=$(aws cloudformation describe-stacks \
    --stack-name ${stackname} \
    --query "Stacks[0].Outputs[?OutputKey=='VpcId'].OutputValue" \
    --region ${AWS_REGION} \
    --output text)

subnetIds=$(aws cloudformation describe-stacks \
    --stack-name ${stackname} \
    --query "Stacks[0].Outputs[?OutputKey=='SubnetIds'].OutputValue" \
    --region ${AWS_REGION} \
    --output text)

subnetId1=$(echo $subnetIds | awk -F ',' '{print $1}')
subnetId2=$(echo $subnetIds | awk -F ',' '{print $2}')
subnetId3=$(echo $subnetIds | awk -F ',' '{print $3}')
subnetId4=$(echo $subnetIds | awk -F ',' '{print $4}')

sgId=$(aws cloudformation describe-stacks \
    --stack-name ${stackname} \
    --query "Stacks[0].Outputs[?OutputKey=='SecurityGroups'].OutputValue" \
    --region ${AWS_REGION} \
    --output text)

if test -f "vpc-params.json"; then
  rm vpc-params.json
fi

cat <<EOF | tee vpc-params.json
[
    {
        "ParameterKey": "VpcId",
        "ParameterValue": "${vpcId}"
    },
    {
        "ParameterKey": "SubnetId1",
        "ParameterValue": "${subnetId1}"
    },
    {
        "ParameterKey": "SubnetId2",
        "ParameterValue": "${subnetId2}"
    },
    {
        "ParameterKey": "SubnetId3",
        "ParameterValue": "${subnetId3}"
    },
    {
        "ParameterKey": "SubnetId4",
        "ParameterValue": "${subnetId4}"
    },
    {
        "ParameterKey": "SecurityGroupId",
        "ParameterValue": "${sgId}"
    }
]
EOF

echo
echo "***DONE***"
echo
echo "NEXT -> ~/aria-operations/tap/tdp/05-tap-build-aws-prereqs.sh"
echo