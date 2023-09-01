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

read -p "App Name (tap-dotnet-core-web-mvc): " app_name
echo

if [[ -z ${app_name} ]]
then
  app_name=tap-dotnet-core-web-mvc
fi

tap_build=tap-build
tap_run_eks=tap-run-eks
tap_run_eks_domain=run-eks
tap_run_aks_domain=run-aks

if [ ! -d "${HOME}/run/eso" ]
then
  mkdir -p ${HOME}/run/eso
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

if test -f "${HOME}/run/eso/${app_name}-deliverable.yaml"; then
  rm ${HOME}/run/eso/${app_name}-deliverable.yaml
  echo
fi

pe "kubectl get configmap ${app_name}-deliverable -o go-template='{{.data.deliverable}}' > ${HOME}/run/eso/${app_name}-deliverable.yaml"
echo

#SWITCH TO RUN CLUSTER
pe "kubectl config use-context ${tap_run_eks}"
echo

pe "clear"








#GIVE SERVICES TOOLKIT PERMISSION TO READ SECRET
stk_secret_reader=stk-secret-reader
if test -f "${HOME}/run/eso/${stk_secret_reader}.yaml"; then
  kubectl delete -f ${HOME}/run/eso/${stk_secret_reader}.yaml
  rm ${HOME}/run/eso/${stk_secret_reader}.yaml
fi

cat <<EOF | tee ${HOME}/run/eso/${stk_secret_reader}.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ${stk_secret_reader}
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

pe "kubectl apply -f ${HOME}/run/eso/${stk_secret_reader}.yaml"
echo

pe "clear"

api_weather_claim=api-weather-claim
api_wavefront_claim=api-wavefront-claim

kubectl delete resourceclaim ${api_weather_claim} --ignore-not-found
kubectl delete resourceclaim ${api_wavefront_claim} --ignore-not-found

pe "tanzu service resource-claim create ${api_weather_claim} --resource-name ${api_weather_secret} --resource-kind Secret --resource-api-version v1"
echo

pe "tanzu service resource-claim create ${api_wavefront_claim} --resource-name ${api_wavefront_secret} --resource-kind Secret --resource-api-version v1"
echo

pe "tanzu service resource-claim list -o wide"
echo

# pe "tanzu services resource-claims get ${api_weather_claim}"
# echo

# pe "tanzu services resource-claims get ${api_wavefront_claim}"
# echo

kubectl delete -f ${HOME}/run/eso/${app_name}-deliverable.yaml --ignore-not-found

pe "kubectl apply -f ${HOME}/run/eso/${app_name}-deliverable.yaml"
echo

echo "Press Ctrl+C on the next command when the deliverable is ready..."
echo

pe "kubectl get deliverables -w"
echo

#pe "kubectl get httpproxy"
#echo

echo https://${app_name}.default.${tap_run_eks_domain}.tap.nycpivot.com
echo
