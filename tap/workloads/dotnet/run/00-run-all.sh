#!/bin/bash

tap_dotnet_weather_web=tap-dotnet-weather-web
tap_dotnet_weather_api=tap-dotnet-weather-api
tap_dotnet_weather_data=tap-dotnet-weather-data

bash 00-reset-all.sh
bash 01-run-tap-dotnet-weather-web.sh
bash 02-run-tap-dotnet-weather-api.sh
bash 03-run-tap-dotnet-weather-data.sh
