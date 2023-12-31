#!/bin/bash

tap_build=tap-build
tap_run_aks_domain=run-aks
tap_dotnet_weather_api=tap-dotnet-weather-api
git_app_url=https://github.com/nycpivot/tap-dotnet-weather

kubectl config use-context ${tap_build}

kubectl delete workload ${tap_dotnet_weather_api} --ignore-not-found

# ENVIRONMENT VARIABLES
weather_db_api=http://tap-dotnet-weather-data.default.${tap_run_aks_domain}.tap.nycpivot.com

# THESE ARE THE NAMES OF THE CLAIMS TO BE CREATED ON THE RUN CLUSTER
weather_bit_api_resource_claim=weather-bit-api-resource-claim
wavefront_api_resource_claim=wavefront-api-resource-claim

# THESE ARE THE NAMES OF THE SERVICE REFS TO THOSE CLAIMS
weather_bit_api_service_ref=${weather_bit_api_resource_claim}=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:${weather_bit_api_resource_claim}
wavefront_api_service_ref=${wavefront_api_resource_claim}=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:${wavefront_api_resource_claim}

tanzu apps workload create ${tap_dotnet_weather_api} \
  --git-repo ${git_app_url} --git-branch main --type web \
  --build-env BP_DOTNET_PROJECT_PATH=src/Tap.Dotnet.Weather.Api \
  --annotation autoscaling.knative.dev/min-scale=2 \
  --label app.kubernetes.io/part-of=${tap_dotnet_weather_api} \
  --label operations=aria \
  --env WEATHER_DB_API=${weather_db_api} \
  --service-ref ${weather_bit_api_service_ref} \
  --service-ref ${wavefront_api_service_ref} \
  --yes

# give 5 minutes to build tap-dotnet-weather-api
intervals=( 5 4 3 2 1 )
for interval in "${intervals[@]}" ; do
echo "${interval} minutes remaining..."
sleep 60
done
echo

tanzu apps workload list
echo

tanzu apps workload get ${tap_dotnet_weather_api}
echo

echo ">>> Supply Chain:"
echo https://tap-gui.view.tap.nycpivot.com/supply-chain/${tap_build}/default/${tap_dotnet_weather_api}
echo
