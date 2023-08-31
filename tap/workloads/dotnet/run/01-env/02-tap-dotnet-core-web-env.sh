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

tap_build=tap-build
tap_run_eks=tap-run-eks
run_eks=run-eks

if [ ! -d "${HOME}/run/env" ]
then
  mkdir -p ${HOME}/run/env
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

if test -f "${HOME}/run/env/${app_name}-deliverable.yaml"; then
  rm ${HOME}/run/env/${app_name}-deliverable.yaml
  echo
fi

pe "kubectl get configmap ${app_name}-deliverable -o go-template='{{.data.deliverable}}' > ${HOME}/run/env/${app_name}-deliverable.yaml"
echo

#SWITCH TO RUN CLUSTER
pe "kubectl config use-context ${tap_run_eks}"
echo

kubectl delete -f ${HOME}/run/env/${app_name}-deliverable.yaml --ignore-not-found
echo

pe "kubectl apply -f ${HOME}/run/env/${app_name}-deliverable.yaml"
echo

echo "Press Ctrl+C on the next command when the deliverable is ready..."
echo

pe "kubectl get deliverables -w"
echo

#pe "kubectl get httpproxy"
#echo

echo https://${app_name}.default.${run_eks}.tap.nycpivot.com
echo
