#!/bin/bash

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
intervals=( 20 19 18 17 16 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 )
for interval in "${intervals[@]}" ; do
echo "Waiting ${interval} minutes for account credential to be created and available..."
sleep 60 # give 20 minutes for all clusters to be created
done

# DELETE AWS VPC STACK
tanzu_stack_name=tanzu-multicluster-vpc-stack

aws cloudformation delete-stack --stack-name ${tanzu_stack_name} --region ${AWS_REGION}
aws cloudformation wait stack-delete-complete --stack-name ${tanzu_stack_name} --region ${AWS_REGION}


# DELETE TMC ACCOUNT CREDENTIAL
tmc account credential delete ${aws_account_credential}

if test -f "${aws_account_credential}.yaml"; then
  rm ${aws_account_credential}.yaml
fi


# DELETE THE CF STACK THAT CREATES THE ROLES FOR THE TMC CREDENTIAL
generated_template_stack_id=13637809161061075293
full_stack_name=eks-tmc-cloud-vmware-com-${generated_template_stack_id}

aws cloudformation delete-stack --stack-name ${full_stack_name} --region ${AWS_REGION}
aws cloudformation wait stack-delete-complete --stack-name ${full_stack_name} --region ${AWS_REGION}


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