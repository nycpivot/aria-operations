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
echo

if [[ -z ${app_name} ]]
then
  app_name=tap-dotnet-core-web-mvc-env
fi

run_cluster=run-eks
if [[ ${kube_context} = "tap-run-eks" ]]
then
  run_cluster=run-eks
elif [[ ${kube_context} = "tap-run-aks" ]]
then
  run_cluster=run-aks
fi

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

echo https://${app_name}.default.${run_cluster}.tap.nycpivot.com
echo
