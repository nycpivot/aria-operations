#!/bin/bash

tap_build=tap-build
tap_run_eks=tap-run-eks
tap_run_aks=tap-run-aks

tap_dotnet_weather_web=tap-dotnet-weather-web
tap_dotnet_weather_api=tap-dotnet-weather-api
tap_dotnet_weather_data=tap-dotnet-weather-data


# tap-build
kubectl config use-context ${tap_build}

kubectl delete all -l operations=aria


# tap-run-eks
kubectl config use-context ${tap_run_eks}

kubectl delete secret -l operations=aria
kubectl delete clusterrole -l operations=aria
kubectl delete all -l operations=aria

if [ -d ${HOME}/${tap_dotnet_weather_web} ]
then
  rm -rf ${HOME}/${tap_dotnet_weather_web}
fi


# tap-run-aks
kubectl config use-context ${tap_run_aks}

kubectl delete secret -l operations=aria
kubectl delete clusterrole -l operations=aria
kubectl delete all -l operations=aria

if [ -d ${HOME}/${tap_dotnet_weather_api} ]
then
  rm -rf ${HOME}/${tap_dotnet_weather_api}
fi

if [ -d ${HOME}/${tap_dotnet_weather_data} ]
then
  rm -rf ${HOME}/${tap_dotnet_weather_data}
fi