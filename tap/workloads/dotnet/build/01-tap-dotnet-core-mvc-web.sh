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
TYPE_SPEED=20

#
# custom prompt
#
# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#
#DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "

# hide the evidence
clear

DEMO_PROMPT="${GREEN}➜ TAP ${CYAN}\W "

read -p "App Name (tap-dotnet-web-mvc): " app_name
read -p "Git Repo Name (https://github.com/nycpivot/tap-dotnet): " git_app_url
echo

if [[ -z ${app_name} ]]
then
  app_name=tap-dotnet-web-mvc
fi

if [[ -z ${git_app_url} ]]
then
  git_app_url=https://github.com/nycpivot/tap-dotnet
fi

tap_build=tap-build

pe "kubectl config use-context ${tap_build}"
echo

pe "tanzu apps workload list"
echo

kubectl delete workload ${app_name} --ignore-not-found

# INJECT SOME ENVIRONMENT VARIABLES
default_zip_code_env="10001"

# THESE SECRETS ARE CREATED ON THE RUN CLUSTER
api_weather_claim=api-weather-claim
api_wavefront_claim=api-wavefront-claim
cache_redis_claim=cache-redis-claim

# THESE ARE THE NAME OF THE CLAIMS
weather_api_service_ref=weather-api=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:${api_weather_claim}
wavefront_api_service_ref=wavefront-api=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:${api_wavefront_claim}
cache_service_ref=cache-config=services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:${cache_redis_claim}

pe "tanzu apps workload create ${app_name} --git-repo ${git_app_url} --git-branch main --type web --build-env BP_DOTNET_PROJECT_PATH=src/Tap.Dotnet.Web.Mvc --annotation autoscaling.knative.dev/min-scale=2 --label app.kubernetes.io/part-of=${app_name} --label operations=aria --env DEFAULT_ZIP_CODE_ENV=${default_zip_code_env} --service-ref ${weather_api_service_ref} --service-ref ${wavefront_api_service_ref} --service-ref ${cache_service_ref} --yes"

pe "clear"

pe "tanzu apps workload tail ${app_name} --since 1h --timestamp"
echo

pe "tanzu apps workload list"
echo

pe "tanzu apps workload get ${app_name}"
echo

echo "To see supply chain: https://tap-gui.view.tap.nycpivot.com/supply-chain/${tap_build}/default/${app_name}"
echo
