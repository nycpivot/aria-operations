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

read -p "App Name (tap-dotnet-core-api-weather): " app_name
echo

if [[ -z ${app_name} ]]
then
  app_name=tap-dotnet-core-api-weather
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
AWS_REGION=$(aws configure get region)

tap_build=tap-build
tap_run_aks=tap-run-aks
tap_run_aks_domain=run-aks

#REBUILD DELIVERABLE HERE IF NEW SOURCE CODE WAS COMMITTED AND BUILT
pe "kubectl config use-context ${tap_build}"
echo

echo "Press Ctrl+C on the next command when the workload has finished building and is ready..."
echo

pe "kubectl get workloads -w"
echo

pe "kubectl get configmaps | grep ${app_name}"
echo

if test -f "${app_name}-deliverable.yaml"; then
  rm ${app_name}-deliverable.yaml
  echo
fi

pe "kubectl get configmap ${app_name}-deliverable -o go-template='{{.data.deliverable}}' > ${app_name}-deliverable.yaml"
echo

#SWITCH TO RUN CLUSTER
pe "kubectl config use-context ${tap_run_aks}"
echo

pe "clear"

# pe "helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace"
# echo

# # KEY_ID=$(aws configure get aws_access_key_id)
# # SECRET_KEY=$(aws configure get aws_secret_access_key)

# echo -n $AWS_ACCESS_KEY_ID > .aws/access-key
# echo -n $AWS_SECRET_ACCESS_KEY > .aws/secret-access-key
# echo -n $AWS_SESSION_TOKEN > .aws/session-token

# if test -f "service-account.yaml"; then
#   rm service-account.yaml
# fi

# cat <<EOF | tee service-account.yaml
# apiVersion: v1
# kind: ServiceAccount
# metadata:
#   annotations:
#     eks.amazonaws.com/role-arn: arn:aws:iam::${AWS_ACCOUNT_ID}:role/PowerUser
#   name: secret-store-sa
#   namespace: default
# EOF
# echo

# kubectl apply -f service-account.yaml
# echo

# # CREATE A K8S SECRET THAT WILL GIVE THE ESO OPERATOR ACCESS TO AWS SECRETS MANAGER
# aws_secrets_manager_secret=aws-secrets-manager-secret

# kubectl delete secret ${aws_secrets_manager_secret}

# pe "kubectl create secret generic ${aws_secrets_manager_secret} --from-file=.aws/access-key --from-file=.aws/secret-access-key --from-file=.aws/session-token"
# echo

# # CREATE AN ESO SECRET STORE BASED ON THE AWS SECRET CREDS
# eso_secret_store=eso-secret-store-api-weather
# if test -f "${eso_secret_store}.yaml"; then
#   kubectl delete -f ${eso_secret_store}.yaml
#   rm ${eso_secret_store}.yaml
# fi

# cat <<EOF | tee ${eso_secret_store}.yaml
# apiVersion: external-secrets.io/v1beta1
# kind: SecretStore
# metadata:
#   name: ${eso_secret_store}
# spec:
#   provider:
#     aws:
#       service: SecretsManager
#       region: ${AWS_REGION}
#       auth:
#         secretRef:
#           accessKeyIDSecretRef:
#             name: ${aws_secrets_manager_secret}
#             key: access-key
#           secretAccessKeySecretRef:
#             name: ${aws_secrets_manager_secret}
#             key: secret-access-key
# EOF
# echo

# pe "kubectl apply -f ${eso_secret_store}.yaml"
# echo

# # CREATE THE ESO OPERATOR
# eso_operator=eso-operator-api-weather
# if test -f "${eso_operator}.yaml"; then
#   kubectl delete -f ${eso_operator}.yaml
#   rm ${eso_operator}.yaml
# fi

# api_weather_bit_claim=api-weather-bit-claim

# cat <<EOF | tee ${eso_operator}.yaml
# apiVersion: external-secrets.io/v1beta1
# kind: ExternalSecret
# metadata:
#   name: ${eso_operator}
# spec:
#   refreshInterval: 30s
#   secretStoreRef:
#     name: ${eso_secret_store}
#     kind: SecretStore
#   target:
#     name: ${api_weather_bit_claim}
#     creationPolicy: Owner
#   data:
#   - secretKey: host
#     remoteRef:
#       key: aria-operations
#       # version: provider-key-version
#       property: weather-bit-api-host
#   - secretKey: key
#     remoteRef:
#       key: aria-operations
#       property: weather-bit-api-key
#   # dataFrom:
#   # - extract:
#   #     key: weather-bit-api-key
# EOF
# echo

# pe "kubectl apply -f ${eso_operator}.yaml"
# echo


wavefront_url=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"wavefront-prod-url\")
wavefront_token=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"wavefront-prod-token\")

# WAVEFRONT SECRETS
api_wavefront_secret_claim_aks=api-wavefront-secret-claim-aks
kubectl delete secret ${api_wavefront_secret_claim_aks} --ignore-not-found
if test -f "${HOME}/run/claim/${api_wavefront_secret_claim_aks}.yaml"; then
  rm ${HOME}/run/claim/${api_wavefront_secret_claim_aks}.yaml
fi

cat <<EOF | tee ${HOME}/run/claim/${api_wavefront_secret_claim_aks}.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${api_wavefront_secret_claim_aks}
  labels:
    operations: aria
    secret-type: claim
type: Opaque
stringData:
  host: ${wavefront_url}
  token: ${wavefront_token}
EOF
echo

pe "kubectl apply -f ${HOME}/run/claim/${api_wavefront_secret_claim_aks}.yaml"
echo

pe "clear"

#GIVE SERVICES TOOLKIT PERMISSION TO READ SECRET
stk_secret_reader_claim_aks=stk-secret-reader-claim-aks
kubectl delete clusterrole ${stk_secret_reader_claim_aks} --ignore-not-found
if test -f "${HOME}/run/claim/${stk_secret_reader_claim_aks}.yaml"; then
  rm ${HOME}/run/claim/${stk_secret_reader_claim_aks}.yaml
fi

cat <<EOF | tee ${HOME}/run/claim/${stk_secret_reader_claim_aks}.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ${stk_secret_reader_claim_aks}
  labels:
    servicebinding.io/controller: "true"
    operations: aria
    secret-type: claim
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - get
  - list
  - watch
EOF
echo

pe "kubectl apply -f ${HOME}/run/claim/${stk_secret_reader_claim_aks}.yaml"
echo

api_wavefront_claim_claim_aks=api-wavefront-claim-claim-aks
kubectl delete resourceclaim ${api_wavefront_claim_claim_aks} --ignore-not-found

pe "tanzu service resource-claim create ${api_wavefront_claim_claim_aks} --resource-name ${api_wavefront_secret_claim_aks} --resource-kind Secret --resource-api-version v1"
echo

pe "tanzu service resource-claim list -o wide"
echo

pe "tanzu services resource-claims get ${api_weather_bit_claim}"
echo

kubectl delete -f ${app_name}-deliverable.yaml
echo

pe "kubectl apply -f ${app_name}-deliverable.yaml"
echo

echo "Press Ctrl+C on the next command when the deliverable is ready..."
echo

pe "kubectl get deliverables -w"
echo


#pe "kubectl get httpproxy"
#echo

echo https://${app_name}.default.${tap_run_aks_domain}.tap.nycpivot.com
echo
