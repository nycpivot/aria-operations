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

read -p "App Name (tap-dotnet-core-web-mvc-env): " app_name
read -p "Git Repo Name (https://github.com/nycpivot/tap-dotnet-core): " git_app_url
echo

if [[ -z ${app_name} ]]
then
  app_name=tap-dotnet-core-web-mvc-env
fi

if [[ -z ${git_app_url} ]]
then
  git_app_url=https://github.com/nycpivot/tap-dotnet-core
fi

tap_build=tap-build
tap_run_eks=tap-run-eks
run_eks=run-eks
run_aks=run-aks

kubectl config use-context ${tap_build}

workload_item=$(tanzu apps workload get ${app_name})
if [[ ${workload_item} != "Workload \"default/tap-dotnet-core-web-mvc-env\" not found" ]]
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

weather_api=https://tap-dotnet-core-api-weather.default.${run_aks}.tap.nycpivot.com
wavefront_url=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"wavefront-prod-url\")
wavefront_token=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"wavefront-prod-token\")

pe "tanzu apps workload create ${app_name} --git-repo ${git_app_url} --git-branch ${app_name} --type web --annotation autoscaling.knative.dev/min-scale=2 --label app.kubernetes.io/part-of=${app_name} --env WEATHER_API=${weather_api} --env WAVEFRONT_URL=${wavefront_url} --env WAVEFRONT_TOKEN=${wavefront_token} --build-env BP_DOTNET_PROJECT_PATH=src/Tap.Dotnet.Core.Web.Mvc --yes"

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

kubectl config use-context ${tap_run_eks}
echo

pe "kubectl apply -f ${app_name}-deliverable.yaml"
echo

pe "kubectl get deliverables"
echo

#pe "kubectl get httpproxy"
#echo

echo https://${app_name}.default.${run_eks}.tap.nycpivot.com
echo
