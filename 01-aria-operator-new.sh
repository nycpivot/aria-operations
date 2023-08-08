#!/bin/bash

read -p "Stack Name (aria-operator-stack): " stack_name
read -p "Operator Name (aria-operator): " operator_name
read -p "AWS Region Code (us-east-1): " aws_region_code


if [[ -z $stack_name ]]
then
    stack_name=aria-operator-stack
fi

if [[ -z $operator_name ]]
then
    operator_name=aria-operator
fi

if [[ -z $aws_region_code ]]
then
    aws_region_code=us-east-1
fi

aws cloudformation create-stack \
    --stack-name ${stack_name} \
    --region ${aws_region_code} \
    --parameters ParameterKey=OperatorName,ParameterValue=${operator_name} \
    --template-body file://operator/config/aria-operator-stack-${aws_region_code}.yaml

aws cloudformation wait stack-create-complete --stack-name ${stack_name} --region ${aws_region_code}

key_id=$(aws ec2 describe-key-pairs --filters Name=key-name,Values=aria-operator-keypair --query KeyPairs[*].KeyPairId --output text --region ${aws_region_code})

rm operator/keys/aria-operator-keypair-${aws_region_code}.pem

aws ssm get-parameter --name " /ec2/keypair/${key_id}" --with-decryption \
    --query Parameter.Value --region ${aws_region_code} \
    --output text > operator/keys/aria-operator-keypair-${aws_region_code}.pem

echo

aws cloudformation describe-stacks \
    --stack-name ${stack_name} \
    --region ${aws_region_code} \
    --query "Stacks[0].Outputs[?OutputKey=='PublicDnsName'].OutputValue" --output text
