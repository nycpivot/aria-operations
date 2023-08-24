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

tap_view=tap-view
tap_build=tap-build
tap_run_eks=tap-run-eks
#tap_iterate=tap-iterate

#DELETE IAM CSI DRIVER ROLES
view_rolename=${tap_view}-csi-driver-role-${AWS_REGION}
build_rolename=${tap_build}-csi-driver-role-${AWS_REGION}
run_eks_rolename=${tap_run_eks}-csi-driver-role-${AWS_REGION}
#iterate_rolename=${tap_iterate}-csi-driver-role-${AWS_REGION}

pei "aws iam detach-role-policy --role-name ${view_rolename} --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy --no-cli-pager"
echo

pei "aws iam detach-role-policy --role-name ${build_rolename} --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy --no-cli-pager"
echo

pei "aws iam detach-role-policy --role-name ${run_eks_rolename} --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy --no-cli-pager"
echo

#pei "aws iam detach-role-policy --role-name ${iterate_rolename} --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy --no-cli-pager"
#echo

pei "aws iam delete-role --role-name ${view_rolename}"
echo

pei "aws iam delete-role --role-name ${build_rolename}"
echo

pei "aws iam delete-role --role-name ${run_eks_rolename}"
echo

#pei "aws iam delete-role --role-name ${iterate_rolename}"
#echo


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
pei "aws cloudformation delete-stack --stack-name tap-vpc-stack --region ${AWS_REGION}"
pei "aws cloudformation wait stack-delete-complete --stack-name tap-vpc-stack --region ${AWS_REGION}"
echo

#rm .kube/config

kubectl config delete-context tap-run-eks
kubectl config delete-context tap-build
kubectl config delete-context tap-view

arn=arn:aws:eks:$AWS_REGION:$AWS_ACCOUNT_ID:cluster
kubectl config delete-cluster ${arn}/${tap_run_eks}
kubectl config delete-cluster ${arn}/${tap_build}
kubectl config delete-cluster ${arn}/${tap_view}

kubectl config delete-user ${arn}/${tap_run_eks}
kubectl config delete-user ${arn}/${tap_build}
kubectl config delete-user ${arn}/${tap_view}

pei "rm change-batch-*"
# pei "rm -rf ${HOME}/tanzu"
# pei "rm -rf ${HOME}/tanzu-cluster-essentials"
# pei "rm -rf ${HOME}/tanzu-java-web-app"
