#!/bin/bash

read -p "Aria Organization (customer0): " aria_org

if [[ -z ${aria_org} ]]
then
  aria_org=customer0
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION=$(aws configure get region)

# nycpivot aria_org defaults
generated_template_stack_id=17533195724431227713 #aws-account-credential
external_id=1cd13c5a-9b6a-53ef-b938-c687989bf70b
aria_org_id=86514df0-46a7-4b33-857d-954ba2970773

if [[ ${aria_org} == "customer0" ]]
then
  generated_template_stack_id=13637809161061075293
  external_id=50ed8bef-c8c6-5ba2-8501-992e94a0fedc
  aria_org_id=3be385a3-d15d-4f70-b779-5e69b8b2a2cc
fi

tmc_iam_stack_name=eks-tmc-cloud-vmware-com-${generated_template_stack_id}
tanzu_vpc_stack_name=tanzu-vpc-stack
vmware_cross_account_id=630260974543 #tmc aws account-id


# 1. CREATE IAM ROLES (THIS IS STEP 2 IN TMC CONSOLE)
aws cloudformation create-stack --stack-name ${tmc_iam_stack_name} \
  --template-url https://tmc-mkp.s3.us-west-2.amazonaws.com/tmc_eks.template \
  --parameters ParameterKey=CredentialName,ParameterValue=aws-account-credential ParameterKey=AccountID,ParameterValue=${vmware_cross_account_id} ParameterKey=OrgID,ParameterValue=${aria_org_id} ParameterKey=RoleName,ParameterValue=main/mkp ParameterKey=ExternalID,ParameterValue=${external_id} ParameterKey=GeneratedTemplateID,ParameterValue=${generated_template_stack_id} \
  --capabilities CAPABILITY_NAMED_IAM
aws cloudformation wait stack-create-complete --stack-name ${tmc_iam_stack_name} --region ${AWS_REGION}

output=$(aws cloudformation describe-stacks \
    --stack-name ${tmc_iam_stack_name} \
    --query "Stacks[0].Outputs[?OutputKey=='Message'].OutputValue" \
    --region ${AWS_REGION} \
    --output text)

role_arn=$(sed '3q;d' <<< $output)

echo ${role_arn}
echo

# GET REFRESH TOKEN, EXCHANGE IT FOR AN ACCESS TOKEN FOR THE REMAINDER
tmc_token=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"tmc-${aria_org}-token\")

export TMC_API_TOKEN=${tmc_token}
export TANZU_API_TOKEN=${tmc_token}

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

cat <<EOF | tee ${aws_account_credential}.yaml
fullName:
  name: ${aws_account_credential}
  orgId: ${aria_org_id}
# meta:
#   annotations:
#     GeneratedTemplateID: "${generated_template_stack_id}"
#     x-customer-domain: ${aria_org}.tmc.cloud.vmware.com
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
ctr=15
while [ $ctr -gt 0 ]
do
echo "${ctr} minutes remaining..."
sleep 60 # give 15 minutes for all clusters to be created
ctr=`expr $ctr - 1`
done

# 4. GET EXISTING VPC AND SUBNETS
vpc_id=$(cat vpc-params.json | jq '.[] | select(.ParameterKey == "VpcId")' | jq -r .ParameterValue)
subnet1=$(cat vpc-params.json | jq '.[] | select(.ParameterKey == "SubnetId1")' | jq -r .ParameterValue)
subnet2=$(cat vpc-params.json | jq '.[] | select(.ParameterKey == "SubnetId2")' | jq -r .ParameterValue)
subnet3=$(cat vpc-params.json | jq '.[] | select(.ParameterKey == "SubnetId3")' | jq -r .ParameterValue)
subnet4=$(cat vpc-params.json | jq '.[] | select(.ParameterKey == "SubnetId4")' | jq -r .ParameterValue)

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
    "orgId": "${aria_org_id}",
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
    "orgId": "${aria_org_id}",
    "credentialName": "${aws_account_credential}",
    "region": "${AWS_REGION}",
    "eksClusterName": "${cluster}",
    "name": "${cluster_nodepool}"
  },
  "spec": {
    "roleArn": "arn:aws:iam::${AWS_ACCOUNT_ID}:role/worker.${generated_template_stack_id}.eks.tmc.cloud.vmware.com",
    "scalingConfig": {
      "desiredSize": 2,
      "maxSize": 2,
      "minSize": 2
    },
    "instanceTypes": [
      "t3.2xlarge"
    ],
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
ctr=45
while [ $ctr -gt 0 ]
do
echo "${ctr} minutes remaining..."
sleep 60 # give 45 minutes for all clusters to be created
ctr=`expr $ctr - 1`
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
  #UPDATE THE MAIN KUBECONFIG FILE SO IT'S THERE 
  #WHEN WE CAN ACCESS IT WITH MY CREDENTIALS
  aws eks update-kubeconfig --name ${cluster} --region $AWS_REGION

  kubectl config rename-context ${arn}/${cluster} ${cluster}

  #DOWNLOAD THE KUBECONFIG FROM TMC
  tanzu mission-control cluster kubeconfig get eks.aws-account-credential.us-east-1.${cluster} \
    --management-cluster-name eks --provisioner-name eks >> .kube/${cluster}-kubeconfig

  kubectl config use-context ${cluster}

  #DELETE DEFAULT AWS-AUTH CONFIG MAP
  kubectl delete configmap aws-auth -n kube-system --kubeconfig .kube/${cluster}-kubeconfig

  #CREATE NEW AWS-AUTH CONFIG MAP WITH NEW ROLE
  kubectl apply -f aws-auth-config-map.yaml --kubeconfig .kube/${cluster}-kubeconfig
done

echo
echo "***DONE***"
echo
echo "***NEXT -> ~/aria-operations/tmc/attach/01-tap-clusters-azure-create-and-attach-cli.sh"
echo
