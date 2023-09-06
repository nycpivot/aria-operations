#!/bin/bash

tap_build=tap-build
tap_dotnet_weather_web=tap-dotnet-weather-web
tap_dotnet_weather_api=tap-dotnet-weather-api
tap_dotnet_weather_data=tap-dotnet-weather-data

bash 00-reset-all.sh
bash 01-build-tap-dotnet-weather-web.sh
bash 02-build-tap-dotnet-weather-api.sh
bash 03-build-tap-dotnet-weather-data.sh

echo ">>> Supply Chains:"
echo https://tap-gui.view.tap.nycpivot.com/supply-chain/${tap_build}/default/${tap_dotnet_weather_web}
echo https://tap-gui.view.tap.nycpivot.com/supply-chain/${tap_build}/default/${tap_dotnet_weather_api}
echo https://tap-gui.view.tap.nycpivot.com/supply-chain/${tap_build}/default/${tap_dotnet_weather_data}
