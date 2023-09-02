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

tap_build=tap-build

pe "kubectl config use-context ${tap_build}"
echo

pe "tanzu apps workload list"
echo

kubectl delete workload ${app_name} --ignore-not-found

api_weather_claim_claim_eks=api-weather-claim-claim-eks
api_wavefront_claim_claim_eks=api-wavefront-claim-claim-eks
cache_redis_claim_claim_eks=cache-redis-claim-claim-eks

weather_api_service_ref=weather-api=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:${api_weather_claim_claim_eks}
wavefront_api_service_ref=wavefront-api=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:${api_wavefront_claim_claim_eks}
cache_service_ref=cache-config=services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:${cache_redis_claim_claim_eks}

pe "tanzu apps workload create ${app_name} --git-repo ${git_app_url} --git-branch ${app_name} --type web --annotation autoscaling.knative.dev/min-scale=2 --label app.kubernetes.io/part-of=${app_name} --label secret-type=claim --label operations=aria --build-env BP_DOTNET_PROJECT_PATH=src/Tap.Dotnet.Core.Web.Mvc --service-ref ${weather_api_service_ref} --service-ref ${wavefront_api_service_ref} --service-ref ${cache_service_ref} --yes"

pe "clear"

pe "tanzu apps workload tail ${app_name} --since 1h --timestamp"
echo

pe "tanzu apps workload list"
echo

pe "tanzu apps workload get ${app_name}"
echo

echo "To see supply chain: https://tap-gui.view.tap.nycpivot.com/supply-chain/${tap_build}/default/${app_name}"
echo
