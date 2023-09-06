#!/bin/bash

tap_build=tap-build
tap_dotnet_weather_data=tap-dotnet-weather-data
git_app_url=https://github.com/nycpivot/tap-dotnet-weather

kubectl config use-context ${tap_build}

kubectl delete workload ${tap_dotnet_weather_data} --ignore-not-found

# THESE ARE THE NAMES OF THE CLAIMS TO BE CREATED ON THE RUN CLUSTER
weather_db_class_claim=weather-db-class-claim
wavefront_api_resource_claim=weather-api-resource-claim

# THESE ARE THE NAMES OF THE SERVICE REFS TO THOSE CLAIMS
weather_data_service_ref=${weather_db_class_claim}=services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:${weather_db_class_claim}
wavefront_api_service_ref=${wavefront_api_resource_claim}=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:${wavefront_api_resource_claim}

tanzu apps workload create ${tap_dotnet_weather_data} \
  --git-repo ${git_app_url} --git-branch main --type web \
  --build-env BP_DOTNET_PROJECT_PATH=src/Tap.Dotnet.Weather.Data \
  --annotation autoscaling.knative.dev/min-scale=2 \
  --label app.kubernetes.io/part-of=${tap_dotnet_weather_data} \
  --label operations=aria \
  --service-ref ${weather_data_service_ref} \
  --service-ref ${wavefront_api_service_ref} \
  --yes

# give 7 minutes to build tap-dotnet-weather-data
intervals=( 7 6 5 4 3 2 1 )
for interval in "${intervals[@]}" ; do
echo "${interval} minutes remaining..."
sleep 60
done
echo

tanzu apps workload list
echo

tanzu apps workload get ${tap_dotnet_weather_data}
echo

echo ">>> Supply Chain:"
echo https://tap-gui.view.tap.nycpivot.com/supply-chain/${tap_build}/default/${tap_dotnet_weather_data}
echo
