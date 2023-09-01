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

read -p "App Name (tap-dotnet-core-web-mvc-claim): " app_name
echo

if [[ -z ${app_name} ]]
then
  app_name=tap-dotnet-core-web-mvc-claim
fi

tap_build=tap-build
tap_run_eks=tap-run-eks
tap_run_eks_domain=run-eks
tap_run_aks_domain=run-aks

if [ ! -d "${HOME}/run/claim" ]
then
  mkdir -p ${HOME}/run/claim
fi

#REBUILD DELIVERABLE HERE IF NEW SOURCE CODE WAS COMMITTED AND BUILT
pe "kubectl config use-context ${tap_build}"
echo

echo "Press Ctrl+C on the next command when the workload has finished building and is ready..."
echo

pe "kubectl get workloads -w"
echo

pe "kubectl get configmaps | grep ${app_name}"
echo

if test -f "${HOME}/run/claim/${app_name}-deliverable.yaml"; then
  rm ${HOME}/run/claim/${app_name}-deliverable.yaml
  echo
fi

pe "kubectl get configmap ${app_name}-deliverable -o go-template='{{.data.deliverable}}' > ${HOME}/run/claim/${app_name}-deliverable.yaml"
echo

#SWITCH TO RUN CLUSTER
pe "kubectl config use-context ${tap_run_eks}"
echo

pe "clear"

weather_api=https://tap-dotnet-core-api-weather-claim.default.${tap_run_aks_domain}.tap.nycpivot.com
wavefront_url=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"wavefront-prod-url\")
wavefront_token=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"wavefront-prod-token\")

# API WEATHER SECRET
api_weather_secret_claim_eks=api-weather-secret-claim-eks
if test -f "${HOME}/run/claim/${api_weather_secret_claim_eks}.yaml"; then
  kubectl delete -f ${HOME}/run/claim/${api_weather_secret_claim_eks}.yaml
  rm ${HOME}/run/claim/${api_weather_secret_claim_eks}.yaml
fi

cat <<EOF | tee ${HOME}/run/claim/${api_weather_secret_claim_eks}.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${api_weather_secret_claim_eks}
  labels:
    operations: aria
    secret-type: claim
type: Opaque
stringData:
  host: ${weather_api}
EOF
echo

pe "kubectl apply -f ${HOME}/run/claim/${api_weather_secret_claim_eks}.yaml"
echo

pe "clear"

# WAVEFRONT SECRETS
api_wavefront_secret_claim_eks=api-wavefront-secret-claim-eks
if test -f "${HOME}/run/claim/${api_wavefront_secret_claim_eks}.yaml"; then
  kubectl delete -f ${HOME}/run/claim/${api_wavefront_secret_claim_eks}.yaml
  rm ${HOME}/run/claim/${api_wavefront_secret_claim_eks}.yaml
fi

cat <<EOF | tee ${HOME}/run/claim/${api_wavefront_secret_claim_eks}.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${api_wavefront_secret_claim_eks}
  labels:
    operations: aria
    secret-type: claim
type: Opaque
stringData:
  host: ${wavefront_url}
  token: ${wavefront_token}
EOF
echo

pe "kubectl apply -f ${HOME}/run/claim/${api_wavefront_secret_claim_eks}.yaml"
echo

pe "clear"

# CREATE REDIS INSTANCE AND SERVICE REF
cache_redis_claim_claim_eks=cache_redis_claim_claim_eks
tanzu service class-claim delete ${cache_redis_claim_claim_eks}

pe "tanzu service class-claim create ${cache_redis_claim_claim_eks} --class redis-unmanaged --parameter storageGB=1"
echo

#GIVE SERVICES TOOLKIT PERMISSION TO READ SECRET
stk_secret_reader_claim_eks=stk-secret-reader-claim-eks
if test -f "${HOME}/run/claim/${stk_secret_reader_claim_eks}.yaml"; then
  kubectl delete -f ${HOME}/run/claim/${stk_secret_reader_claim_eks}.yaml
  rm ${HOME}/run/claim/${stk_secret_reader_claim_eks}.yaml
fi

cat <<EOF | tee ${HOME}/run/claim/${stk_secret_reader_claim_eks}.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ${stk_secret_reader_claim_eks}
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

pe "kubectl apply -f ${HOME}/run/claim/${stk_secret_reader_claim_eks}.yaml"
echo

api_weather_claim_claim_eks=api-weather-claim-claim-eks
api_wavefront_claim_claim_eks=api-wavefront-claim-claim-eks

kubectl delete resourceclaim ${api_weather_claim_claim_eks} --ignore-not-found
kubectl delete resourceclaim ${api_wavefront_claim_claim_eks} --ignore-not-found
# tanzu service resource-claim delete ${api_weather_claim} --yes
# tanzu service resource-claim delete ${api_wavefront_claim} --yes
echo

pe "tanzu service resource-claim create ${api_weather_claim_claim_eks} --resource-name ${api_weather_secret_claim_eks} --resource-kind Secret --resource-api-version v1"
echo

pe "tanzu service resource-claim create ${api_wavefront_claim_claim_eks} --resource-name ${api_wavefront_secret_claim_eks} --resource-kind Secret --resource-api-version v1"
echo

pe "tanzu service resource-claim list -o wide"
echo

# pe "tanzu services resource-claims get ${api_weather_claim}"
# echo

# pe "tanzu services resource-claims get ${api_wavefront_claim}"
# echo

kubectl delete -f ${HOME}/run/claim/${app_name}-deliverable.yaml --ignore-not-found
echo

pe "kubectl apply -f ${HOME}/run/claim/${app_name}-deliverable.yaml"
echo

echo "Press Ctrl+C on the next command when the deliverable is ready..."
echo

pe "kubectl get deliverables -w"
echo

#pe "kubectl get httpproxy"
#echo

echo https://${app_name}.default.${tap_run_eks_domain}.tap.nycpivot.com
echo
