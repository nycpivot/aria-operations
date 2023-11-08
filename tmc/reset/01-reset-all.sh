#!/bin/bash

read -p "Aria Organization (customer0): " aria_org

if [[ -z ${aria_org} ]]
then
  aria_org=customer0
fi

# nycpivot aria_org defaults
generated_template_stack_id=17533195724431227713

if [[ ${aria_org} == "customer0" ]]
then
  generated_template_stack_id=13637809161061075293
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION=$(aws configure get region)

aws_account_credential=aws-account-credential

# DELETE EKS CLUSTERS FROM TMC
tap_view=tap-view
tap_build=tap-build
tap_run_eks=tap-run-eks

clusters=( $tap_view $tap_build $tap_run_eks )

for cluster in "${clusters[@]}" ; do

if test -f "${cluster}.yaml"; then
  rm ${cluster}.yaml
fi

tmc ekscluster delete ${cluster} --credential-name ${aws_account_credential} --region ${AWS_REGION}
done

echo
ctr=45
while [ $ctr -gt 0 ]
do
echo "${ctr} minutes remaining..."
sleep 60 # give 45 minutes for all clusters to be created
ctr=`expr $ctr - 1`
done

#DELETE ELBs (some of these might not exist, that's fine - ignore errors)
tanzu_vpc_stack_name=tanzu-vpc-stack

vpc_id=$(aws ec2 describe-vpcs --query "Vpcs[?Tags[?Value=='${tanzu_vpc_stack_name}-VPC']].VpcId" --output text)

classic_lbs=$(aws elb describe-load-balancers --query "LoadBalancerDescriptions[?VPCId=='${vpc_id}'].LoadBalancerName")
network_lbs=$(aws elbv2 describe-load-balancers --query "LoadBalancers[?VpcId=='${vpc_id}'].LoadBalancerArn")

echo $classic_lbs | jq -c -r '.[]' | while read elb; do
  aws elb delete-load-balancer --load-balancer-name ${elb}
done

echo $network_lbs | jq -c -r '.[]' | while read nlb; do
  aws elbv2 delete-load-balancer --load-balancer-arn ${nlb}
done

echo "Deleting load balancers..."

echo
ctr=2
while [ $ctr -gt 0 ]
do
echo "${ctr} minutes remaining..."
sleep 60 # give 2 minutes to delete load balancers
ctr=`expr $ctr - 1`
done

# igw_id=$(aws ec2 describe-internet-gateways --query "InternetGateways[].{ InternetGatewayId: InternetGatewayId, VpcId: Attachments[0].VpcId } | [?VpcId == '$vpc_id'].[InternetGatewayId][0][0]" --output text)

# aws ec2 detach-internet-gateway --internet-gateway-id ${igw_id} --vpc-id ${vpc_id}
# aws ec2 delete-internet-gateway --internet-gateway-id ${igw_id}

# echo "Deleting internet gateways..."

# echo
# ctr=5
# while [ $ctr -gt 0 ]
# do
# echo "${ctr} minutes remaining..."
# sleep 60 # give 5 minutes for all clusters to be created
# ctr=`expr $ctr - 1`
# done

# # DELETE AWS VPC STACK
# tanzu_stack_name=tanzu-vpc-stack

# echo
# echo "Deleting ${tanzu_stack_name}..."
# echo

# aws cloudformation delete-stack --stack-name ${tanzu_stack_name} --region ${AWS_REGION}
# aws cloudformation wait stack-delete-complete --stack-name ${tanzu_stack_name} --region ${AWS_REGION}


# DELETE TMC ACCOUNT CREDENTIAL
tmc account credential delete ${aws_account_credential}

if test -f "${aws_account_credential}.yaml"; then
  rm ${aws_account_credential}.yaml
fi

# DELETE THE CF STACK THAT CREATES THE ROLES FOR THE TMC CREDENTIAL
full_stack_name=eks-tmc-cloud-vmware-com-${generated_template_stack_id}

echo
echo "Deleting ${full_stack_name}..."
echo

aws cloudformation delete-stack --stack-name ${full_stack_name} --region ${AWS_REGION}
aws cloudformation wait stack-delete-complete --stack-name ${full_stack_name} --region ${AWS_REGION}


# DELETE AKS CLUSTER
tap_run_aks=tap-run-aks
subscription_id=$(az account show --query id --output tsv)

tanzu mission-control cluster delete ${tap_run_aks} --management-cluster-name attached --provisioner-name attached

echo
ctr=20
while [ $ctr -gt 0 ]
do
echo "${ctr} minutes remaining..."
sleep 60 # give 20 minutes for all clusters to be deleted
ctr=`expr $ctr - 1`
done

az aks delete --name ${tap_run_aks} --resource-group aria-operations --yes

kubectl config delete-cluster ${tap_run_aks}
kubectl config delete-context ${tap_run_aks}
kubectl config delete-user clusterUser_aria-operations_${tap_run_aks}

az group delete --name aria-operations --yes

# DELETE CLUSTER GROUP
tmc_cluster_group=tmc-operations
tanzu mission-control clustergroup delete ${tmc_cluster_group}

if test -f "${tmc_cluster_group}.yaml"; then
  rm ${tmc_cluster_group}.yaml
fi

# REMOVE KUBECONFIGS
for cluster in "${clusters[@]}" ; do
kubectl config delete-context ${cluster}

arn=arn:aws:eks:$AWS_REGION:$AWS_ACCOUNT_ID:cluster
kubectl config delete-cluster ${arn}/${cluster}

kubectl config delete-user ${arn}/${cluster}
done

rm .kube/${tap_view}-kubeconfig
rm .kube/${tap_build}-kubeconfig
rm .kube/${tap_run_eks}-kubeconfig
