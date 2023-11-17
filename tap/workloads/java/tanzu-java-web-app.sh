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

read -p "App Name (tanzu-java-web-app): " app_name
echo

if [[ -z ${app_name} ]]; then
    app_name=tanzu-java-web-app
fi

tap_build=tap-build
tap_run_eks=tap-run-eks
tap_run_aks=tap-run-aks

git_app_url=https://github.com/nycpivot/${app_name}

kubectl config use-context $tap_build
echo

#pe "tanzu apps workload delete --all --yes"
#echo

pe "tanzu apps workload list"
echo

#pe "tanzu apps workload create ${app_name} --git-repo ${git_app_url} --git-branch main --type web --label app.kubernetes.io/part-of=${app_name} --yes --dry-run"
#echo

pe "tanzu apps workload create ${app_name} --git-repo ${git_app_url} --git-branch main --type web --annotation autoscaling.knative.dev/min-scale=2 --label app.kubernetes.io/part-of=${app_name} --yes"
echo

pe "clear"

pe "tanzu apps workload tail ${app_name} --since 1h --timestamp"
echo

pe "clear"

pe "tanzu apps workload list"
echo

pe "tanzu apps workload get ${app_name}"
echo

pe "clear"

pe "kubectl get configmaps"
echo

pe "rm ${app_name}-deliverable.yaml"
pe "kubectl get configmap ${app_name}-deliverable -o go-template='{{.data.deliverable}}' > ${app_name}-deliverable.yaml"
echo

pe "clear"

kubectl config use-context $tap_run_eks
echo

pe "kubectl apply -f ${app_name}-deliverable.yaml"
echo

pe "kubectl get deliverables"
echo

pe "clear"

kubectl config use-context $tap_run_aks
echo

pe "kubectl apply -f ${app_name}-deliverable.yaml"
echo

pe "kubectl get deliverables"
echo

echo https://${app_name}.default.run-eks.tap.nycpivot.com
echo https://${app_name}.default.run-aks.tap.nycpivot.com
