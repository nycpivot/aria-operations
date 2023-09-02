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

read -p "App Name (tap-dotnet-core-api-weather-claim): " app_name
echo

if [[ -z ${app_name} ]]
then
  app_name=tap-dotnet-core-api-weather-claim
fi

tap_build=tap-build
tap_run_aks=tap-run-aks
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
pe "kubectl config use-context ${tap_run_aks}"
echo

pe "clear"

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

echo https://${app_name}.default.${tap_run_aks_domain}.tap.nycpivot.com
echo
