#!/bin/bash

read -p "AWS Region Code (us-east-1): " aws_region_code

if [[ -z $aws_region_code ]]
then
	aws_region_code=us-east-1
fi

if [[ $aws_region_code = "us-east-1" ]]
then
    ssh ubuntu@ec2-54-174-158-127.compute-1.amazonaws.com -i operator/keys/aria-operator-keypair-${aws_region_code}.pem -L 9090:localhost:9090
elif [[ $aws_region_code = "us-east-2" ]]
then
    ssh ubuntu@ec2-3-22-118-73.us-east-2.compute.amazonaws.com -i operator/keys/aria-operator-keypair-${aws_region_code}.pem
elif [[ $aws_region_code = "us-west-1" ]]
then
    ssh ubuntu@ec2-13-56-227-32.us-west-1.compute.amazonaws.com -i operator/keys/aria-operator-keypair-${aws_region_code}.pem
elif [[ $aws_region_code = "us-west-2" ]]
then
    ssh ubuntu@ec2-35-93-82-66.us-west-2.compute.amazonaws.com -i operator/keys/aria-operator-keypair-${aws_region_code}.pem
fi
