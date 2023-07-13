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

echo "tap-dotnet-core-web-mvc"
echo "tap-dotnet-core-api-weather"
echo

read -p "App Name: " app_name
read -p "Git Repo Name (https://github.com/nycpivot/tap-dotnet-core): " git_app_url

if [[ -z ${git_app_url} ]]
then
  git_app_url=https://github.com/nycpivot/tap-dotnet-core
fi

sub_path=
if [[ ${app_name} = "tap-dotnet-core-web-mvc" ]]
then
  sub_path=Tap.Dotnet.Core.Web.Mvc
elif [[ ${app_name} = "tap-dotnet-core-api-weather" ]]
then
  sub_path=Tap.Dotnet.Core.Api.Weather
fi
echo

kubectl config get-contexts
echo

read -p "Select build context (Press Enter for current context): " kube_context

if [[ -n ${kube_context} ]]
then
  kubectl config use-context ${kube_context}
  echo
fi

pe "tanzu apps workload list"
echo

pe "tanzu apps workload create ${app_name} --git-repo ${git_app_url} --git-branch main --type web --annotation autoscaling.knative.dev/min-scale=2 --label app.kubernetes.io/part-of=${app_name} --build-env BP_DOTNET_PROJECT_PATH=src/${sub_path} --yes"

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

pe "kubectl apply -f ${app_name}-deliverable.yaml"
echo

pe "kubectl get deliverables"
echo

#pe "kubectl get httpproxy"
#echo

run_cluster=run-eks
if [[ ${kube_context} = "tap-run-eks" ]]
then
  run_cluster=run-eks
elif [[ ${kube_context} = "tap-run-aks" ]]
then
  run_cluster=run-aks
fi

echo https://${app_name}.default.${run_cluster}.tap.nycpivot.com
echo
