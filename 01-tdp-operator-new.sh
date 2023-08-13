stack_name=tdp-operator-stack
aws_region_code=us-east-1

aws cloudformation create-stack \
    --stack-name ${stack_name} \
    --region ${aws_region_code} \
    --template-body file://operator/config/tdp-operator-stack.yaml

aws cloudformation wait stack-create-complete --stack-name ${stack_name} --region ${aws_region_code}

key_id=$(aws ec2 describe-key-pairs --filters Name=key-name,Values=tdp-operator-keypair --query KeyPairs[*].KeyPairId --output text --region ${aws_region_code})

rm operator/keys/tdp-operator-keypair.pem

aws ssm get-parameter --name " /ec2/keypair/${key_id}" --with-decryption \
    --query Parameter.Value --region ${aws_region_code} \
    --output text > operator/keys/tdp-operator-keypair.pem

echo

jumpbox_dns=$(aws cloudformation describe-stacks --stack-name ${stack_name} --region ${aws_region_code} --query "Stacks[0].Outputs[?OutputKey=='PublicDnsName'].OutputValue" --output text)

rm tdp-operator.sh
cat <<EOF | tee tdp-operator.sh
ssh ubuntu@${jumpbox_dns} -i operator/keys/tdp-operator-keypair.pem -L 3000:localhost:3000
EOF

sh tdp-operator.sh
