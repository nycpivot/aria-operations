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

read -p "App Name (tap-dotnet-core-api-weather): " app_name
read -p "Git Repo Name (https://github.com/nycpivot/tap-dotnet-core): " git_app_url
echo

if [[ -z ${app_name} ]]
then
  app_name=tap-dotnet-core-api-weather-claim
fi

if [[ -z ${git_app_url} ]]
then
  git_app_url=https://github.com/nycpivot/tap-dotnet-core
fi

app_branch=tap-dotnet-core-web-mvc-claim

tap_build=tap-build
tap_run_aks=tap-run-aks
tap_run_aks_domain=run-aks

pe "kubectl config use-context ${tap_build}"
echo

pe "tanzu apps workload list"
echo

kubectl delete workload ${app_name} --ignore-not-found
echo

api_wavefront_claim_claim_aks=api-wavefront-claim-claim-aks

wavefront_api_service_ref=wavefront-api=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:${api_wavefront_claim_claim_aks}

# api_weather_bit_claim=api-weather-bit-claim
# api_wavefront_claim=api-wavefront-claim

# weather_bit_api_service_ref=weather-bit-api=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:${api_weather_bit_claim}
# wavefront_api_service_ref=wavefront-api=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:${api_wavefront_claim}


pe "tanzu apps workload create ${app_name} --git-repo ${git_app_url} --git-branch ${app_branch} --type web --annotation autoscaling.knative.dev/min-scale=2 --label app.kubernetes.io/part-of=${app_name} --label secret-type=claim --label operations=aria --build-env BP_DOTNET_PROJECT_PATH=src/Tap.Dotnet.Core.Api.Weather --service-ref ${wavefront_api_service_ref} --yes"

pe "clear"

pe "tanzu apps workload tail ${app_name} --since 1h --timestamp"
echo

pe "tanzu apps workload list"
echo

pe "tanzu apps workload get ${app_name}"
echo

echo "To see supply chain: https://tap-gui.view.tap.nycpivot.com/supply-chain/${tap_build}/default/${app_name}"
echo
