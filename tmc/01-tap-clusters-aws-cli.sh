#!/bin/bash

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION=$(aws configure get region)

generated_template_stack_id=17533195724431227713 # 13637809161061075293 # <- this is customer0
external_id=1cd13c5a-9b6a-53ef-b938-c687989bf70b # 50ed8bef-c8c6-5ba2-8501-992e94a0fedc # <- this is customer0
tmc_iam_stack_name=eks-tmc-cloud-vmware-com-${generated_template_stack_id}
tanzu_vpc_stack_name=tanzu-vpc-stack
tmc_org=86514df0-46a7-4b33-857d-954ba2970773 # 3be385a3-d15d-4f70-b779-5e69b8b2a2cc # <- this is customer0
tmc_account_id=630260974543


# 1. CREATE IAM ROLES (THIS IS STEP 2 IN TMC CONSOLE)
aws cloudformation create-stack --stack-name ${tmc_iam_stack_name} \
  --template-url https://tmc-mkp.s3.us-west-2.amazonaws.com/tmc_eks.template \
  --parameters ParameterKey=CredentialName,ParameterValue=aws-account-credential ParameterKey=AccountID,ParameterValue=${tmc_account_id} ParameterKey=OrgID,ParameterValue=${tmc_org} ParameterKey=RoleName,ParameterValue=main/mkp ParameterKey=ExternalID,ParameterValue=${external_id} ParameterKey=GeneratedTemplateID,ParameterValue=${generated_template_stack_id} \
  --capabilities CAPABILITY_NAMED_IAM

# aws cloudformation create-stack \
#   --stack-name ${tanzu_vpc_stack_name} \
#   --template-url https://s3.us-west-2.amazonaws.com/amazon-eks/cloudformation/2020-10-29/amazon-eks-vpc-private-subnets.yaml

aws cloudformation wait stack-create-complete --stack-name ${tmc_iam_stack_name} --region ${AWS_REGION}
# aws cloudformation wait stack-create-complete --stack-name ${tanzu_vpc_stack_name} --region ${AWS_REGION}

output=$(aws cloudformation describe-stacks \
    --stack-name ${tmc_iam_stack_name} \
    --query "Stacks[0].Outputs[?OutputKey=='Message'].OutputValue" \
    --region ${AWS_REGION} \
    --output text)

role_arn=$(sed '3q;d' <<< $output)

echo ${role_arn}
echo

read -p "Enter to continue..."
echo


# GET REFRESH TOKEN, EXCHANGE IT FOR AN ACCESS TOKEN FOR THE REMAINDER
tmc_token=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"tmc-token\")

export TMC_API_TOKEN=${tmc_token}
export TANZU_API_TOKEN=${tmc_token}

# if test -f tmc-token.json; then
#   rm tmc-token.json
# fi

# curl -X POST https://console.cloud.vmware.com/csp/gateway/am/api/auth/api-tokens/authorize \
#   -H "Accept: application/json" -H "Content-Type: application/x-www-form-urlencoded" \
#   -d "refresh_token=${tmc_token}" \
#   -o tmc-token.json

# access_token=$(cat tmc-token.json | jq .access_token -r)


# 2. CREATE A TMC CLUSTER GROUP
tmc_cluster_group=tmc-operations

cat <<EOF | tee ${tmc_cluster_group}.yaml
fullName:
  name: ${tmc_cluster_group}
EOF

tanzu mission-control clustergroup create -f ${tmc_cluster_group}.yaml


# 3. CREATE TMC AWS ACCOUNT CREDENTIAL (THIS IS STEP 1 IN TMC CONSOLE)
# THIS ACCOUNT CREDENTIAL WILL REFERENCE THE CLUSTERLIFECYCLE IAM ROLE
# CREATED AND OUTPUT FROM THE CF STACK ABOVE
# (TMC CLI)
aws_account_credential=aws-account-credential

if test -f ${aws_account_credential}.yaml; then
  rm ${aws_account_credential}.yaml
fi

cat <<EOF | tee ${aws_account_credential}.yaml # TMC CLI VERSION (THIS WORKS)
fullName:
  name: ${aws_account_credential}
  orgId: ${tmc_org}
# meta:
#   annotations:
#     GeneratedTemplateID: "${generated_template_stack_id}"
#     x-customer-domain: customer0.tmc.cloud.vmware.com
#   labels:
#     tmc.cloud.vmware.com/cred-cloudformation-key: "${generated_template_stack_id}"
#   resourceVersion: "1"
spec:
  capability: MANAGED_K8S_PROVIDER
  data:
    awsCredential:
      # accountId: "${AWS_ACCOUNT_ID}" only relevant with tanzu mission-control
      iamRole:
        arn: ${role_arn}
  meta:
    provider: AWS_EKS
    # temporaryCredentialSupport: false only relevant with tanzu mission-control
EOF

tmc account credential create -f ${aws_account_credential}.yaml

echo
intervals=( 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 )
for interval in "${intervals[@]}" ; do
echo "${interval} minutes remaining..."
sleep 60 # give 20 minutes for all clusters to be created
done


# *********************************************************************************
# NONE OF THE CLIs (OLD/NEW) WORK FOR THE FOLLOWING OBJECTS (EKSCLUSTER & NODEPOOL)
# BUT THE APIs SEEM TO WORK OK - THESE WILL BE REPLACED WHEN THE CLI WORKS
# *********************************************************************************

# 4. GET EXISTING VPC AND SUBNETS
vpc_id=$(aws ec2 describe-vpcs --query "Vpcs[?Tags[?Value=='${tanzu_vpc_stack_name}-VPC']].VpcId" --output text)
subnets=$(aws ec2 describe-subnets --query "Subnets[?VpcId=='${vpc_id}']".SubnetId --output text)

subnet1=$(echo $subnets | awk -F ' ' '{print $1}')
subnet2=$(echo $subnets | awk -F ' ' '{print $2}')
subnet3=$(echo $subnets | awk -F ' ' '{print $3}')
subnet4=$(echo $subnets | awk -F ' ' '{print $4}')


# 5. CREATE CLUSTERS
tap_view=tap-view
tap_build=tap-build
tap_run_eks=tap-run-eks

clusters=( $tap_view $tap_build $tap_run_eks )

for cluster in "${clusters[@]}" ; do

if test -f ${cluster}.json; then
  rm ${cluster}.json
fi

cat <<EOF | tee ${cluster}.json
{
  "fullName": {
    "orgId": "${tmc_org}",
    "credentialName": "${aws_account_credential}",
    "region": "${AWS_REGION}",
    "name": "${cluster}"
  },
  "spec": {
    "clusterGroupName": "${tmc_cluster_group}",
    "config": {
      "version": "1.25",
      "roleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/control-plane.${generated_template_stack_id}.eks.tmc.cloud.vmware.com",
      "vpc": {
        "enablePrivateAccess": true,
        "enablePublicAccess": true,
        "publicAccessCidrs": [
          "0.0.0.0/0"
        ],
        "subnetIds": [
          "${subnet1}",
          "${subnet2}",
          "${subnet3}",
          "${subnet4}"
        ]
      }
    }
  }
}
EOF

tanzu mission-control ekscluster create -f ${cluster}.json

sleep 60

# NODE-POOL
cluster_nodepool=${cluster}-nodepool

if test -f ${cluster_nodepool}.json; then
  rm ${cluster_nodepool}.json
fi

cat <<EOF | tee ${cluster_nodepool}.json
{
  "fullName": {
    "orgId": "${tmc_org}",
    "credentialName": "${aws_account_credential}",
    "region": "${AWS_REGION}",
    "eksClusterName": "${cluster}",
    "name": "${cluster_nodepool}"
  },
  "spec": {
    "roleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/worker.${generated_template_stack_id}.eks.tmc.cloud.vmware.com",
    "subnetIds": [
      "${subnet1}",
      "${subnet2}",
      "${subnet3}",
      "${subnet4}"
    ]
  }
}
EOF

tanzu mission-control ekscluster nodepool create -f ${cluster_nodepool}.json
done

echo
intervals=( 20 19 18 17 16 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 )
for interval in "${intervals[@]}" ; do
echo "${interval} minutes remaining..."
sleep 60 # give 20 minutes for all clusters to be created
done


# CREATE A MODIFIED AWS-AUTH CONFIG MAP TO BE APPLIED IN THE FOLLOWING LOOP
if test -f aws-auth-config-map.yaml; then
  rm aws-auth-config-map.yaml
fi

cat <<EOF | tee aws-auth-config-map.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - groups:
      - system:bootstrappers
      - system:nodes
      rolearn: arn:aws:iam::${AWS_ACCOUNT_ID}:role/worker.${generated_template_stack_id}.eks.tmc.cloud.vmware.com
      username: system:node:{{EC2PrivateDNSName}}
    - groups:
      - system:masters
      rolearn: arn:aws:iam::${AWS_ACCOUNT_ID}:role/PowerUser
      username: PowerUser/cloudgate@mijames
EOF

# GET KUBECONFIGS AND UPDATE AWS-AUTH CONFIG MAP TO ADD PERMISSIONS TO CURRENT AWS USER
arn=arn:aws:eks:$AWS_REGION:$AWS_ACCOUNT_ID:cluster

for cluster in "${clusters[@]}" ; do
  aws eks update-kubeconfig --name ${cluster} --region $AWS_REGION

  kubectl config rename-context ${arn}/${cluster} ${cluster}

  tanzu mission-control cluster kubeconfig get eks.aws-account-credential.us-east-1.${cluster} \
    --management-cluster-name eks --provisioner-name eks >> .kube/${cluster}-kubeconfig

  kubectl config use-context ${cluster}

  kubectl delete configmap aws-auth -n kube-system --kubeconfig .kube/${cluster}-kubeconfig

  kubectl apply -f aws-auth-config-map.yaml --kubeconfig .kube/${cluster}-kubeconfig
done

echo
echo "***DONE***"
echo
echo "NEXT -> ~/aria-operations/tap/cli/01-tap-aws-prereqs.sh"
echo
