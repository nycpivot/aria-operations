#!/bin/bash

tap_build=tap-build
tap_run_eks=tap-run-eks
tap_run_aks=tap-run-aks

# DELETE ALL ON TAP-BUILD
kubectl config use-context ${tap_build}

kubectl delete all -l operations=aria

# DELETE ALL ON TAP-RUN-EKS
kubectl config use-context ${tap_run_eks}

kubectl delete all -l operations=aria

if [ -d "${HOME}/run/env" ]
then
  rm -rf ${HOME}/run/env
fi

if [ -d "${HOME}/run/claim" ]
then
  rm -rf ${HOME}/run/claim
fi

if [ -d "${HOME}/run/eso" ]
then
  rm -rf ${HOME}/run/eso
fi





# DELETE ALL ON TAP-RUN-AKS
kubectl config use-context tap-run-aks

kubectl delete all -l operations=aria

if test -f "tap-dotnet-core-api-weather-env-deliverable.yaml"; then
  kubectl delete -f tap-dotnet-core-api-weather-env-deliverable.yaml
  rm tap-dotnet-core-api-weather-env-deliverable.yaml
  echo
fi

if test -f "tap-dotnet-core-api-weather-claim-deliverable.yaml"; then
  kubectl delete -f tap-dotnet-core-api-weather-claim-deliverable.yaml
  rm tap-dotnet-core-api-weather-claim-deliverable.yaml
  echo
fi

if test -f "tap-dotnet-core-api-weather-deliverable.yaml"; then
  kubectl delete -f tap-dotnet-core-api-weather-deliverable.yaml
  rm tap-dotnet-core-api-weather-deliverable.yaml
  echo
fi

stk_secret_reader_claim=stk-secret-reader-claim
if test -f "${stk_secret_reader_claim}.yaml"; then
  kubectl delete -f ${stk_secret_reader_claim}.yaml
  rm ${stk_secret_reader_claim}.yaml
fi

stk_secret_reader=stk-secret-reader
if test -f "${stk_secret_reader}.yaml"; then
  kubectl delete -f ${stk_secret_reader}.yaml
  rm ${stk_secret_reader}.yaml
fi

api_wavefront_claim=api-wavefront-claim
tanzu service resource-claim delete ${api_wavefront_claim} --yes
echo

api_wavefront_secret_claim_aks=api-wavefront-secret-claim-aks
if test -f "${api_wavefront_secret_claim_aks}.yaml"; then
  kubectl delete -f ${api_wavefront_secret_claim_aks}.yaml
  rm ${api_wavefront_secret_claim_aks}.yaml
fi

api_wavefront_secret=api-wavefront-secret
if test -f "${api_wavefront_secret}.yaml"; then
  kubectl delete -f ${api_wavefront_secret}.yaml
  rm ${api_wavefront_secret}.yaml
fi

helm uninstall prometheus
helm uninstall external-secrets -n external-secrets
tanzu service class-claim delete weather-db --yes

# DELETE ALL ON TAP-RUN-EKS
kubectl config use-context tap-run-eks

if test -f "tap-dotnet-core-web-mvc-env-deliverable.yaml"; then
  kubectl delete -f tap-dotnet-core-web-mvc-env-deliverable.yaml
  rm tap-dotnet-core-web-mvc-env-deliverable.yaml
  echo
fi

if test -f "tap-dotnet-core-web-mvc-claim-deliverable.yaml"; then
  kubectl delete -f tap-dotnet-core-web-mvc-claim-deliverable.yaml
  rm tap-dotnet-core-web-mvc-claim-deliverable.yaml
  echo
fi

if test -f "tap-dotnet-core-web-mvc-deliverable.yaml"; then
  kubectl delete -f tap-dotnet-core-web-mvc-deliverable.yaml
  rm tap-dotnet-core-web-mvc-deliverable.yaml
  echo
fi

stk_secret_reader=stk-secret-reader
if test -f "${stk_secret_reader}.yaml"; then
  kubectl delete -f ${stk_secret_reader}.yaml
  rm ${stk_secret_reader}.yaml
fi

api_weather_secret=api-weather-secret
if test -f "${api_weather_secret}.yaml"; then
  kubectl delete -f ${api_weather_secret}.yaml
  rm ${api_weather_secret}.yaml
fi

api_wavefront_secret=api-wavefront-secret
if test -f "${api_wavefront_secret}.yaml"; then
  kubectl delete -f ${api_wavefront_secret}.yaml
  rm ${api_wavefront_secret}.yaml
fi

api_weather_claim=api-weather-claim
api_wavefront_claim=api-wavefront-claim
tanzu service resource-claim delete ${api_weather_claim} --yes
tanzu service resource-claim delete ${api_wavefront_claim} --yes
echo

# DELETE ALL ON TAP-BUILD
kubectl config use-context tap-build

if test -f "tap-dotnet-core-web-mvc-env-deliverable.yaml"; then
  kubectl delete -f tap-dotnet-core-web-mvc-env-deliverable.yaml
  rm tap-dotnet-core-web-mvc-env-deliverable.yaml
  echo
fi

if test -f "tap-dotnet-core-web-mvc-claim-deliverable.yaml"; then
  kubectl delete -f tap-dotnet-core-web-mvc-claim-deliverable.yaml
  rm tap-dotnet-core-web-mvc-claim-deliverable.yaml
  echo
fi

if test -f "tap-dotnet-core-web-mvc-deliverable.yaml"; then
  kubectl delete -f tap-dotnet-core-web-mvc-deliverable.yaml
  rm tap-dotnet-core-web-mvc-deliverable.yaml
  echo
fi

rm $HOME/tap*