#!/bin/bash

AWS_REGION=$(aws configure get region)

aws_account_credential=aws-account-credential

# DELETE EKS CLUSTER FROM TMC
eks_cluster_name=tap-dotnet-core-web-mvc

if test -f "${eks_cluster_name}.yaml"; then
  rm ${eks_cluster_name}.yaml
fi

tmc ekscluster delete ${eks_cluster_name} --credential-name ${aws_account_credential} --region ${AWS_REGION}

sleep 2000 # 30+ mins

# DELETE AWS VPC STACK
tap_vpc_stack_name=tap-multicluster-vpc-stack

aws cloudformation delete-stack --stack-name ${tap_vpc_stack_name} --region ${AWS_REGION}
aws cloudformation wait stack-delete-complete --stack-name ${tap_vpc_stack_name} --region ${AWS_REGION}


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

curl #
