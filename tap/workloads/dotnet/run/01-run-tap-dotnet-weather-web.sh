#!/bin/bash

tap_build=tap-build
tap_run_eks=tap-run-eks
tap_run_eks_domain=run-eks
tap_dotnet_weather_web=tap-dotnet-weather-web

kubectl config use-context ${tap_build}

if [ ! -d ${HOME}/run/${tap_dotnet_weather_web} ]
then
  mkdir -p ${HOME}/run/${tap_dotnet_weather_web}
fi

if test -f "${HOME}/run/${tap_dotnet_weather_web}/${tap_dotnet_weather_web}-deliverable.yaml"; then
  rm ${HOME}/run/${tap_dotnet_weather_web}/${tap_dotnet_weather_web}-deliverable.yaml
  echo
fi

kubectl get configmap ${tap_dotnet_weather_web}-deliverable -o go-template='{{.data.deliverable}}' \
    > ${HOME}/run/${tap_dotnet_weather_web}/${tap_dotnet_weather_web}-deliverable.yaml

kubectl config use-context ${tap_run_eks}

# wavefront secret
wavefront_api_secret=wavefront-api-secret

wavefront_url=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"wavefront-prod-url\")
wavefront_token=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"wavefront-prod-token\")

kubectl delete -f ${HOME}/run/${tap_dotnet_weather_web}/${wavefront_api_secret}.yaml
if test -f "${HOME}/run/${tap_dotnet_weather_web}/${wavefront_api_secret}.yaml"; then
  rm ${HOME}/run/${tap_dotnet_weather_web}/${wavefront_api_secret}.yaml
fi

cat <<EOF | tee ${HOME}/run/${tap_dotnet_weather_web}/${wavefront_api_secret}.yaml
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

kubectl apply -f ${HOME}/run/${tap_dotnet_weather_web}/${wavefront_api_secret}.yaml

# give services toolkit permission to view secrets
stk_cluster_role=stk-cluster-role

kubectl delete -f ${HOME}/run/${tap_dotnet_weather_web}/${stk_cluster_role}.yaml --ignore-not-found
if test -f "${HOME}/run/${tap_dotnet_weather_web}/${stk_cluster_role}.yaml"; then
  rm ${HOME}/run/${tap_dotnet_weather_web}/${stk_cluster_role}.yaml
fi

cat <<EOF | tee ${HOME}/run/${tap_dotnet_weather_web}/${stk_cluster_role}.yaml
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

kubectl apply -f ${HOME}/run/${tap_dotnet_weather_web}/${stk_cluster_role}.yaml

redis_cache_class_claim=redis-cache-class-claim
wavefront_api_resource_claim=wavefront-api-resource-claim

kubectl delete classclaim ${redis_cache_class_claim} --ignore-not-found
kubectl delete resourceclaim ${wavefront_api_resource_claim} --ignore-not-found

tanzu service class-claim create ${redis_cache_class_claim} \
  --class redis-unmanaged --parameter storageGB=1
tanzu service resource-claim create ${wavefront_api_resource_claim} \
  --resource-name ${wavefront_api_secret} --resource-kind Secret --resource-api-version v1

sleep 20

kubectl delete -f ${HOME}/run/${tap_dotnet_weather_web}/${tap_dotnet_weather_web}-deliverable.yaml --ignore-not-found
kubectl apply -f ${HOME}/run/${tap_dotnet_weather_web}/${tap_dotnet_weather_web}-deliverable.yaml

echo
echo ">>> Running Workloads:"

echo https://${tap_dotnet_weather_web}.default.${tap_run_eks_domain}.tap.nycpivot.com
echo
