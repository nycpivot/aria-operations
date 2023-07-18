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
read -p "Git Repo Name (https://github.com/nycpivot/tap-dotnet-core): " git_app_url
echo

if [[ -z ${app_name} ]]
then
  app_name=tap-dotnet-core-api-weather
fi

if [[ -z ${git_app_url} ]]
then
  git_app_url=https://github.com/nycpivot/tap-dotnet-core
fi

AWS_REGION=$(aws configure get region)

kubectl config get-contexts
echo

read -p "Select build context (Press Enter for current context): " kube_context

if [[ -n ${kube_context} ]]
then
  kubectl config use-context ${kube_context}
  echo
fi

run_cluster=run-eks
if [[ ${kube_context} = "tap-run-eks" ]]
then
  run_cluster=run-eks
elif [[ ${kube_context} = "tap-run-aks" ]]
then
  run_cluster=run-aks
fi

pe "tanzu apps workload list"
echo

api_weather_eso_secret=api-weather-eso-secret
service_ref=weather-api=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:${api_weather_eso_secret}

pe "tanzu apps workload create ${app_name} --git-repo ${git_app_url} --git-branch main --type web --annotation autoscaling.knative.dev/min-scale=2 --label app.kubernetes.io/part-of=${app_name} --build-env BP_DOTNET_PROJECT_PATH=src/Tap.Dotnet.Core.Api.Weather --service-ref ${service_ref} --yes"

pe "clear"

pe "tanzu apps workload tail ${app_name} --since 1h --timestamp"
echo

pe "tanzu apps workload list"
echo

pe "tanzu apps workload get ${app_name}"
echo

pe "kubectl get configmaps"
echo

pe "rm ${app_name}-deliverable.yaml"
echo

pe "kubectl get configmap ${app_name}-deliverable -o go-template='{{.data.deliverable}}' > ${app_name}-deliverable.yaml"
#pe "kubectl get configmap ${app_name}-deliverable -o yaml | yq 'del(.metadata.ownerReferences)' | yq 'del(.metadata.resourceVersion)' | yq 'del(.metadata.uid)' > ${app_name}-deliverable.yaml"
echo

kubectl config get-contexts
echo

read -p "Select run context: " kube_context
echo

kubectl config use-context ${kube_context}
echo

pe "helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace"
echo

KEY_ID=$(aws configure get aws_access_key_id)
SECRET_KEY=$(aws configure get aws_secret_access_key)

echo -n $KEY_ID > .aws/access-key
echo -n $SECRET_KEY > .aws/secret-access-key

# CREATE A K8S SECRET THAT WILL GIVE THE ESO OPERATOR ACCESS TO AWS SECRETS MANAGER
aws_secrets_manager_secret=aws-secrets-manager-secret
pe "kubectl create secret generic ${aws_secrets_manager_secret} --from-file=.aws/access-key --from-file=.aws/secret-access-key"
echo

# CREATE AN ESO SECRET STORE BASED ON THE AWS SECRET CREDS
eso_secret_store=eso-secret-store
if test -f "${eso_secret_store}.yaml"; then
  kubectl delete -f ${eso_secret_store}
  rm ${eso_secret_store}.yaml
fi

cat <<EOF | tee ${eso_secret_store}.yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: ${eso_secret_store}
spec:
  provider:
    aws:
      service: SecretsManager
      region: ${AWS_REGION}
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: ${aws_secrets_manager_secret}
            key: access-key
          secretAccessKeySecretRef:
            name: ${aws_secrets_manager_secret}
            key: secret-access-key
EOF

pe "kubectl apply -f ${eso_secret_store}"
echo

# CREATE THE ESO OPERATOR
eso_operator=eso-operator
if test -f "${eso_operator}.yaml"; then
  kubectl delete -f ${eso_operator}.yaml
  rm ${eso_operator}.yaml
fi

cat <<EOF | tee ${eso_operator}.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: ${eso_operator}
spec:
  refreshInterval: 30s
  secretStoreRef:
    name: ${eso_secret_store}
    kind: SecretStore
  target:
    name: ${api_weather_eso_secret}
    creationPolicy: Owner
  data:
  - secretKey: ${api_weather_eso_secret}-key
    remoteRef:
      key: aria-operations
      # version: provider-key-version
      property: weather-bit-api-key
  # dataFrom:
  # - extract:
  #     key: weather-bit-api-key
EOF

pe "kubectl apply -f ${eso_operator}.yaml"
echo

kubectl delete deliverable tap-dotnet-core-api-weather
echo

pe "kubectl apply -f ${app_name}-deliverable.yaml"
echo

pe "kubectl get deliverables"
echo

#pe "kubectl get httpproxy"
#echo

echo https://${app_name}.default.${run_cluster}.tap.nycpivot.com
echo
