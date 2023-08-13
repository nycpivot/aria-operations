#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

########################
# Configure the options
########################

#
# speed at which to simulate typing. bigger num = faster
#
TYPE_SPEED=15

#
# custom prompt
#
# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#
#DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "

# hide the evidence
clear

DEMO_PROMPT="${GREEN}➜ TAP ${CYAN}\W "

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION=$(aws configure get region)

tap_build=tdp-build

#DELETE IAM CSI DRIVER ROLES
build_rolename=${tap_build}-csi-driver-role-${AWS_REGION}

pei "aws iam detach-role-policy --role-name ${build_rolename} --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy --no-cli-pager"
echo

pei "aws iam delete-role --role-name ${build_rolename}"
echo

#DELETE ELBs
classic_lb1=$(aws elb describe-load-balancers | jq -r .LoadBalancerDescriptions[0].LoadBalancerName)
classic_lb2=$(aws elb describe-load-balancers | jq -r .LoadBalancerDescriptions[1].LoadBalancerName)
network_lb1=$(aws elbv2 describe-load-balancers | jq -r .LoadBalancers[0].LoadBalancerArn)
network_lb2=$(aws elbv2 describe-load-balancers | jq -r .LoadBalancers[1].LoadBalancerArn)

pei "aws elb delete-load-balancer --load-balancer-name ${classic_lb1}"
echo

pei "aws elb delete-load-balancer --load-balancer-name ${classic_lb2}"
echo

pei "aws elbv2 delete-load-balancer --load-balancer-arn ${network_lb1}"
echo

pei "aws elbv2 delete-load-balancer --load-balancer-arn ${network_lb2}"
echo

sleep 10

#DELETE STACK
pei "aws cloudformation delete-stack --stack-name tpb-multicluster-stack --region ${AWS_REGION}"
pei "aws cloudformation wait stack-delete-complete --stack-name tpb-multicluster-stack --region ${AWS_REGION}"
echo

#rm .kube/config

kubectl config delete-context tdp-build

arn=arn:aws:eks:$AWS_REGION:$AWS_ACCOUNT_ID:cluster
kubectl config delete-cluster ${arn}/${tap_build}

kubectl config delete-user ${arn}/${tap_build}

pei "rm change-batch-*"
# pei "rm -rf ${HOME}/tanzu"
# pei "rm -rf ${HOME}/tanzu-cluster-essentials"
# pei "rm -rf ${HOME}/tanzu-java-web-app"
