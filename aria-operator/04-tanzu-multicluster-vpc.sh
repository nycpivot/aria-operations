#!/bin/bash

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION=$(aws configure get region)

aws cloudformation create-stack --stack-name tanzu-multicluster-vpc-stack --region $AWS_REGION \
    --template-body https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2020-10-29/amazon-eks-vpc-private-subnets.yaml
    
aws cloudformation wait stack-create-complete --stack-name tanzu-multicluster-vpc-stack --region $AWS_REGION




    --stack-name tap-multicluster-vpc-stack