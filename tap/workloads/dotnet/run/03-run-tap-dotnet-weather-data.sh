#!/bin/bash

tap_build=tap-build
tap_run_aks=tap-run-aks
tap_run_aks_domain=run-aks
tap_dotnet_weather_data=tap-dotnet-weather-data

kubectl config use-context ${tap_build}

if [ ! -d ${HOME}/run/${tap_dotnet_weather_data} ]
then
  mkdir ${HOME}/run/${tap_dotnet_weather_data}
fi

if test -f "${HOME}/run/${tap_dotnet_weather_data}/${tap_dotnet_weather_data}-deliverable.yaml"; then
  rm ${HOME}/run/${tap_dotnet_weather_data}/${tap_dotnet_weather_data}-deliverable.yaml
  echo
fi

kubectl get configmap ${tap_dotnet_weather_data}-deliverable -o go-template='{{.data.deliverable}}' \
  > ${HOME}/run/${tap_dotnet_weather_data}/${tap_dotnet_weather_data}-deliverable.yaml

kubectl config use-context ${tap_run_aks}

wavefront_url=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"wavefront-prod-url\")
wavefront_token=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"wavefront-prod-token\")

# create wavefront secret for claim
wavefront_api_secret=wavefront-api-secret
kubectl delete secret ${wavefront_api_secret} --ignore-not-found
if test -f "${HOME}/run/${tap_dotnet_weather_data}/${wavefront_api_secret}.yaml"; then
  rm ${HOME}/run/${tap_dotnet_weather_data}/${wavefront_api_secret}.yaml
fi

cat <<EOF | tee ${HOME}/run/${tap_dotnet_weather_data}/${wavefront_api_secret}.yaml
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

kubectl apply -f ${HOME}/run/${tap_dotnet_weather_data}/${wavefront_api_secret}.yaml

stk_cluster_role=stk-cluster-role
kubectl delete clusterrole ${stk_cluster_role} --ignore-not-found
if test -f "${HOME}/run/${tap_dotnet_weather_data}/${stk_cluster_role}.yaml"; then
  rm ${HOME}/run/${tap_dotnet_weather_data}/${stk_cluster_role}.yaml
fi

cat <<EOF | tee ${HOME}/run/${tap_dotnet_weather_data}/${stk_cluster_role}.yaml
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

kubectl apply -f ${HOME}/run/${tap_dotnet_weather_data}/${stk_cluster_role}.yaml

weather_db_class_claim=weater-db-class-claim
wavefront_api_resource_claim=wavefront-api-resource-claim

kubectl delete classclaim ${weather_db_class_claim} --ignore-not-found
kubectl delete resourceclaim ${wavefront_api_resource_claim} --ignore-not-found

tanzu service class-claim create ${weather_db_class_claim} \
  --class postgresql-unmanaged --parameter storageGB=1
tanzu service resource-claim create ${wavefront_api_resource_claim} \
  --resource-name ${wavefront_api_secret} --resource-kind Secret --resource-api-version v1

kubectl delete -f ${HOME}/run/${tap_dotnet_weather_data}/${tap_dotnet_weather_data}-deliverable.yaml --ignore-not-found
kubectl apply -f ${HOME}/run/${tap_dotnet_weather_data}/${tap_dotnet_weather_data}-deliverable.yaml

echo
echo ">>> Running Workloads:"

echo https://${tap_dotnet_weather_data}.default.${tap_run_aks_domain}.tap.nycpivot.com
echo
