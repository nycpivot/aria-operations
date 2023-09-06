#!/bin/bash

tap_build=tap-build
tap_run_aks=tap-run-aks
tap_run_aks_domain=run-aks
tap_dotnet_weather_api=tap-dotnet-weather-api

kubectl config use-context ${tap_build}

if [ ! -d ${HOME}/run/${tap_dotnet_weather_api} ]
then
  mkdir -p ${HOME}/run/${tap_dotnet_weather_api}
fi

if test -f "${HOME}/run/${tap_dotnet_weather_api}/${tap_dotnet_weather_api}-deliverable.yaml"; then
  rm ${HOME}/run/${tap_dotnet_weather_api}/${tap_dotnet_weather_api}-deliverable.yaml
  echo
fi

kubectl get configmap ${tap_dotnet_weather_api}-deliverable -o go-template='{{.data.deliverable}}' \
  > ${HOME}/run/${tap_dotnet_weather_api}/${tap_dotnet_weather_api}-deliverable.yaml

kubectl config use-context ${tap_run_aks}

weather_bit_url=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"weather-bit-api-host\")
weather_bit_key=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"weather-bit-api-key\")
wavefront_url=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"wavefront-prod-url\")
wavefront_token=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"wavefront-prod-token\")

# create weather-bit secret for claim
weather_bit_api_secret=weather-bit-api-secret
kubectl delete secret ${weather_bit_api_secret} --ignore-not-found
if test -f "${HOME}/run/${tap_dotnet_weather_api}/${weather_bit_api_secret}.yaml"; then
  rm ${HOME}/run/${tap_dotnet_weather_api}/${weather_bit_api_secret}.yaml
fi

cat <<EOF | tee ${HOME}/run/${tap_dotnet_weather_api}/${weather_bit_api_secret}.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${weather_bit_api_secret}
  labels:
    operations: aria
type: Opaque
stringData:
  host: ${weather_bit_url}
  key: ${weather_bit_key}
EOF

kubectl apply -f ${HOME}/run/${tap_dotnet_weather_api}/${weather_bit_api_secret}.yaml

# create wavefront secret for claim
wavefront_api_secret=wavefront-api-secret
kubectl delete secret ${api_wavefront_secret} --ignore-not-found
if test -f "${HOME}/run/${tap_dotnet_weather_api}/${wavefront_api_secret}.yaml"; then
  rm ${HOME}/run/${tap_dotnet_weather_api}/${wavefront_api_secret}.yaml
fi

cat <<EOF | tee ${HOME}/run/${tap_dotnet_weather_api}/${wavefront_api_secret}.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${wavefront_api_secret}
  labels:
    operations: aria
type: Opaque
stringData:
  host: ${wavefront_url}
  token: ${wavefront_token}
EOF

kubectl apply -f ${HOME}/run/${tap_dotnet_weather_api}/${wavefront_api_secret}.yaml

stk_cluster_role=stk-cluster-role
kubectl delete clusterrole ${stk_cluster_role} --ignore-not-found
if test -f "${HOME}/run/${tap_dotnet_weather_api}/${stk_cluster_role}.yaml"; then
  rm ${HOME}/run/${tap_dotnet_weather_api}/${stk_cluster_role}.yaml
fi

cat <<EOF | tee ${HOME}/run/${tap_dotnet_weather_api}/${stk_cluster_role}.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ${stk_cluster_role}
  labels:
    servicebinding.io/controller: "true"
    operations: aria
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - get
  - list
  - watch
EOF

kubectl apply -f ${HOME}/run/${tap_dotnet_weather_api}/${stk_cluster_role}.yaml

weather_bit_api_resource_claim=weather-bit-api-resource-claim
wavefront_api_resource_claim=wavefront-api-resource-claim

kubectl delete resourceclaim ${weather_bit_api_resource_claim} --ignore-not-found
kubectl delete resourceclaim ${wavefront_api_resource_claim} --ignore-not-found

tanzu service resource-claim create ${weather_bit_api_resource_claim} \
  --resource-name ${weather_bit_api_secret} --resource-kind Secret --resource-api-version v1
tanzu service resource-claim create ${wavefront_api_resource_claim} \
  --resource-name ${wavefront_api_secret} --resource-kind Secret --resource-api-version v1

kubectl delete -f ${HOME}/run/${tap_dotnet_weather_api}/${tap_dotnet_weather_api}-deliverable.yaml --ignore-not-found

kubectl apply -f ${HOME}/run/${tap_dotnet_weather_api}/${tap_dotnet_weather_api}-deliverable.yaml

echo
echo ">>> Running Workloads:"

echo https://${tap_dotnet_weather_api}.default.${tap_run_aks_domain}.tap.nycpivot.com
echo
