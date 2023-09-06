#!/bin/bash

tap_build=tap-build
tap_run_aks_domain=run-aks
tap_dotnet_weather_web=tap-dotnet-weather-web
git_app_url=https://github.com/nycpivot/tap-dotnet-weather

kubectl config use-context ${tap_build}

kubectl delete workload ${tap_dotnet_weather_web} --ignore-not-found

# ENVIRONMENT VARIABLES
weather_api=https://tap-dotnet-api-weather.default.${tap_run_aks_domain}.tap.nycpivot.com

# THESE ARE THE NAMES OF THE CLAIMS TO BE CREATED ON THE RUN CLUSTER
redis_cache_class_claim=redis-cache-class-claim
wavefront_api_resource_claim=wavefront-api-resource-claim

# THESE ARE THE NAMES OF THE SERVICE REFS TO THOSE CLAIMS
wavefront_api_service_ref=${redis_cache_class_claim}=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:${redis_cache_class_claim}
redis_cache_service_ref=${wavefront_api_resource_claim}=services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:${wavefront_api_resource_claim}

tanzu apps workload create ${tap_dotnet_weather_web} \
  --git-repo ${git_app_url} --git-branch main --type web \
  --build-env BP_DOTNET_PROJECT_PATH=src/Tap.Dotnet.Weather.Web \
  --annotation autoscaling.knative.dev/min-scale=2 \
  --label app.kubernetes.io/part-of=${tap_dotnet_weather_web} \
  --label operations=aria \
  --env WEATHER_API=${weather_api} \
  --service-ref ${wavefront_api_service_ref} \
  --service-ref ${redis_cache_service_ref} \
  --yes

# give 7 minutes to build tap-dotnet-weather-web
intervals=( 7 6 5 4 3 2 1 )
for interval in "${intervals[@]}" ; do
echo "${interval} minutes remaining..."
sleep 60
done
echo

tanzu apps workload list
echo

tanzu apps workload get ${tap_dotnet_weather_web}
echo

echo ">>> Supply Chain:"
echo https://tap-gui.view.tap.nycpivot.com/supply-chain/${tap_build}/default/${tap_dotnet_weather_web}
echo
