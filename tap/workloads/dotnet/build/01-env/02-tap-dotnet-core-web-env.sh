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

app_branch=tap-dotnet-core-env

tap_build=tap-build
tap_run_eks_domain=run-eks
tap_run_aks_domain=run-aks

pe "kubectl config use-context ${tap_build}"
echo

pe "tanzu apps workload list -n ${app_branch}"
echo

kubectl delete workload ${app_name} -n ${app_branch} --ignore-not-found

weather_api=https://tap-dotnet-core-api-weather-env.default.${tap_run_aks_domain}.tap.nycpivot.com
wavefront_url=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"wavefront-prod-url\")
wavefront_token=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"wavefront-prod-token\")

pe "tanzu apps workload create ${app_name} -n ${app_branch} --git-repo ${git_app_url} --git-branch ${app_name} --type web --annotation autoscaling.knative.dev/min-scale=2 --label app.kubernetes.io/part-of=${app_name} --label secret-type=env --label operations=aria --env WEATHER_API=${weather_api} --env WAVEFRONT_URL=${wavefront_url} --env WAVEFRONT_TOKEN=${wavefront_token} --build-env BP_DOTNET_PROJECT_PATH=src/Tap.Dotnet.Core.Web.Mvc --yes"

pe "clear"

pe "tanzu apps workload tail ${app_name} -n ${app_branch} --since 1h --timestamp"
echo

pe "tanzu apps workload list -n ${app_branch}"
echo

pe "tanzu apps workload get ${app_name} -n ${app_branch}"
echo

echo "To see supply chain: https://tap-gui.view.tap.nycpivot.com/supply-chain/${tap_build}/default/${app_name}"
echo
