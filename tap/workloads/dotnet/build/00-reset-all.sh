#!/bin/bash

tap_build=tap-build

tap_dotnet_weather_web=tap-dotnet-weather-web
tap_dotnet_weather_api=tap-dotnet-weather-api
tap_dotnet_weather_data=tap-dotnet-weather-data


# tap-build
kubectl config use-context ${tap_build}

kubectl delete all -l operations=aria
