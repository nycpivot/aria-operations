#!/bin/bash

echo "1. Inject Api endpoints as environment variables."
echo "2. Use a direct secret reference."
echo "3. Create an external secrets operator (ESO)."

read -p "Input the option number: " option

if [[ ${option} = "1" ]]
then
    bash 01-tap-dotnet-core-web-env.sh
elif [[ ${option} = "2" ]]
then
    bash 02-tap-dotnet-core-web-secret.sh
elif [[ ${option} = "3" ]]
then
    bash 03-tap-dotnet-core-web-eso.sh
fi
