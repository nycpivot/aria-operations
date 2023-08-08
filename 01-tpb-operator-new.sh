stack_name=tpb-operator-stack
aws_region_code=us-east-1

aws cloudformation create-stack \
    --stack-name ${stack_name} \
    --region ${aws_region_code} \
    --template-body file://operator/config/tpb-operator-stack.yaml

aws cloudformation wait stack-create-complete --stack-name ${stack_name} --region ${aws_region_code}

key_id=$(aws ec2 describe-key-pairs --filters Name=key-name,Values=tpb-operator-keypair --query KeyPairs[*].KeyPairId --output text --region ${aws_region_code})

rm operator/keys/tpb-operator-keypair.pem

aws ssm get-parameter --name " /ec2/keypair/${key_id}" --with-decryption \
    --query Parameter.Value --region ${aws_region_code} \
    --output text > operator/keys/tpb-operator-keypair.pem

echo

aws cloudformation describe-stacks \
    --stack-name ${stack_name} \
    --region ${aws_region_code} \
    --query "Stacks[0].Outputs[?OutputKey=='PublicDnsName'].OutputValue" --output text
