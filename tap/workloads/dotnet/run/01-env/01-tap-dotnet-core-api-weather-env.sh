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

read -p "App Name (tap-dotnet-core-api-weather-env): " app_name
echo

if [[ -z ${app_name} ]]
then
  app_name=tap-dotnet-core-api-weather-env
fi

tap_build=tap-build
tap_run_aks=tap-run-aks
tap_run_aks_domain=run-aks

if [ ! -d "${HOME}/workloads/env" ]
then
  mkdir -p ${HOME}/workloads/env
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

if test -f "${HOME}/workloads/env/${app_name}-deliverable.yaml"; then
  rm ${HOME}/workloads/env/${app_name}-deliverable.yaml
  echo
fi

pe "kubectl get configmap ${app_name}-deliverable -o go-template='{{.data.deliverable}}' > ${HOME}/workloads/env/${app_name}-deliverable.yaml"
echo

#SWITCH TO RUN CLUSTER
pe "kubectl config use-context ${tap_run_aks}"
echo

kubectl delete -f ${HOME}/workloads/env/${app_name}-deliverable.yaml --ignore-not-found
echo

pe "kubectl apply -f ${HOME}/workloads/env/${app_name}-deliverable.yaml"
echo

pe "kubectl label deliverable ${app_name} operations=aria secret-type=env"
echo

echo "Press Ctrl+C on the next command when the deliverable is ready..."
echo

pe "kubectl get deliverables -w"
echo

#pe "kubectl get httpproxy"
#echo

echo https://${app_name}.default.${tap_run_aks_domain}.tap.nycpivot.com
echo
