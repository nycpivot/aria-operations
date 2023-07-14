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
read -p "Git Repo Name (https://github.com/nycpivot/tap-dotnet-core): " git_app_url
echo

if [[ -z ${app_name} ]]
then
  app_name=tap-dotnet-core-web-mvc-claim
fi

if [[ -z ${git_app_url} ]]
then
  git_app_url=https://github.com/nycpivot/tap-dotnet-core
fi

kubectl config get-contexts
echo

read -p "Select build context (Press Enter for current context): " kube_context
echo

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

workload_item=$(tanzu apps workload get ${app_name})
if [[ ${workload_item} != "Workload \"default/tap-dotnet-core-web-mvc-claim\" not found" ]]
then
  workload_name=$(tanzu apps workload get ${app_name} -oyaml | yq -r .metadata.name)
  if [[ ${workload_name} = ${app_name} ]]
  then
    tanzu apps workload delete ${app_name}
    echo
  fi
fi

pe "tanzu apps workload list"
echo

api_weather_claim=api-weather-claim
service_ref=weather-api=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:${api_weather_claim}

pe "tanzu apps workload create ${app_name} --git-repo ${git_app_url} --git-branch ${app_name} --type web --annotation autoscaling.knative.dev/min-scale=2 --label app.kubernetes.io/part-of=${app_name} --build-env BP_DOTNET_PROJECT_PATH=src/Tap.Dotnet.Core.Web.Mvc --service-ref ${service_ref}  --yes"

pe "clear"

pe "tanzu apps workload tail ${app_name} --since 1h --timestamp"
echo

pe "tanzu apps workload list"
echo

pe "tanzu apps workload get ${app_name}"
echo

pe "kubectl get configmaps"
echo

if test -f "${app_name}-deliverable.yaml"; then
  kubectl delete -f ${app_name}-deliverable.yaml
  rm ${app_name}-deliverable.yaml
  echo
fi

pe "kubectl get configmap ${app_name}-deliverable -o go-template='{{.data.deliverable}}' > ${app_name}-deliverable.yaml"
#pe "kubectl get configmap ${app_name}-deliverable -o yaml | yq 'del(.metadata.ownerReferences)' | yq 'del(.metadata.resourceVersion)' | yq 'del(.metadata.uid)' > ${app_name}-deliverable.yaml"
echo

kubectl config get-contexts
echo

read -p "Select run context: " kube_context
echo

kubectl config use-context ${kube_context}
echo

api_weather_secret=api-weather-secret
if test -f "${api_weather_secret}.yaml"; then
  kubectl delete -f ${api_weather_secret}
  rm ${api_weather_secret}.yaml
fi

cat <<EOF | tee ${api_weather_secret}.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${api_weather_secret}
type: Opaque
stringData:
  host: https://tap-dotnet-core-api-weather.default.${run_cluster}.tap.nycpivot.com
EOF
echo

pe "kubectl apply -f ${api_weather_secret}.yaml"
echo

#GIVE SERVICES TOOLKIT PERMISSION TO READ SECRET
stk_secret_reader=stk-secret-reader
if test -f "${stk_secret_reader}.yaml"; then
  kubectl delete -f ${stk_secret_reader}
  rm ${stk_secret_reader}.yaml
fi

cat <<EOF | tee ${stk_secret_reader}.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: stk-secret-reader
  labels:
    servicebinding.io/controller: "true"
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

pe "kubectl apply -f ${stk_secret_reader}.yaml"
echo

pe "tanzu service resource-claim create ${api_weather_claim} --resource-name ${api_weather_secret} --resource-kind Secret --resource-api-version v1"
echo

pe "tanzu service resource-claim list -o wide"
echo

pe "tanzu services resource-claims get api-weather-claim"
echo

pe "kubectl apply -f ${app_name}-deliverable.yaml"
echo

pe "kubectl get deliverables"
echo

#pe "kubectl get httpproxy"
#echo

echo https://${app_name}.default.${run_cluster}.tap.nycpivot.com
echo