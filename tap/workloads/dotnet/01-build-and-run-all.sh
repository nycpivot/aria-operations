#!/bin/bash

tap_build=tap-build
tap_run_eks=tap-run-eks
tap_run_aks=tap-run-aks
tap_run_eks_domain=run-eks
tap_run_aks_domain=run-aks

git_app_url=https://github.com/nycpivot/tap-dotnet

tap_dotnet_mvc_web=tap-dotnet-web-mvc
tap_dotnet_api_weather=tap-dotnet-api-weather

weather_api=https://tap-dotnet-api-weather.default.${tap_run_aks_domain}.tap.nycpivot.com
weather_bit_url=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"weather-bit-api-host\")
weather_bit_key=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"weather-bit-api-key\")
wavefront_url=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"wavefront-prod-url\")
wavefront_token=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"wavefront-prod-token\")

# *********************************************************************************************** #
# START RESET ALL IN TAP-BUILD, TAP-RUN-EKS, AND TAP-RUN-AKS
# *********************************************************************************************** #
# tap-build
kubectl config use-context ${tap_build}

kubectl delete all -l operations=aria

# tap-run-eks
kubectl config use-context ${tap_run_eks}

kubectl delete secret -l operations=aria
kubectl delete clusterrole -l operations=aria
kubectl delete all -l operations=aria

if [ -d ${HOME}/${tap_dotnet_mvc_web} ]
then
  rm -rf ${HOME}/${tap_dotnet_mvc_web}
fi

# tap-run-aks
kubectl config use-context ${tap_run_aks}

kubectl delete secret -l operations=aria
kubectl delete clusterrole -l operations=aria
kubectl delete all -l operations=aria

if [ -d ${HOME}/${tap_dotnet_api_weather} ]
then
  rm -rf ${HOME}/${tap_dotnet_api_weather}
fi
# *********************************************************************************************** #
# END RESET ALL IN TAP-BUILD
# *********************************************************************************************** #


# *********************************************************************************************** #
# START BUILD OF TAP-DOTNET-MVC-WEB IN TAP-BUILD
# *********************************************************************************************** #
kubectl config use-context ${tap_build}

kubectl delete workload ${tap_dotnet_mvc_web} --ignore-not-found

# INJECT SOME ENVIRONMENT VARIABLES
default_zip_code_env="10001"

# THESE SECRETS ARE CREATED ON THE RUN CLUSTER
api_weather_claim=api-weather-claim
api_wavefront_claim=api-wavefront-claim
cache_redis_claim=cache-redis-claim

# THESE ARE THE NAME OF THE CLAIMS
weather_api_service_ref=weather-api=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:${api_weather_claim}
wavefront_api_service_ref=wavefront-api=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:${api_wavefront_claim}
cache_service_ref=cache-config=services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:${cache_redis_claim}

tanzu apps workload create ${tap_dotnet_mvc_web} \
    --git-repo ${git_app_url} --git-branch main --type web \
    --build-env BP_DOTNET_PROJECT_PATH=src/Tap.Dotnet.Web.Mvc \
    --annotation autoscaling.knative.dev/min-scale=2 \
    --label app.kubernetes.io/part-of=${tap_dotnet_mvc_web} \
    --label operations=aria \
    --env DEFAULT_ZIP_CODE_ENV=${default_zip_code_env} \
    --service-ref ${weather_api_service_ref} \
    --service-ref ${wavefront_api_service_ref} \
    --service-ref ${cache_service_ref} \
    --yes
# *********************************************************************************************** #
# END BUILD OF TAP-DOTNET-MVC-WEB IN TAP-BUILD
# *********************************************************************************************** #

# give 7 minutes to build tap-dotnet-web-mvc
intervals=( 7 6 5 4 3 2 1 )
for interval in "${intervals[@]}" ; do
echo "${interval} minutes remaining..."
sleep 60
done

# *********************************************************************************************** #
# START BUILD OF TAP-DOTNET-API-WEATHER IN TAP-BUILD
# *********************************************************************************************** #
kubectl delete workload ${tap_dotnet_api_weather} --ignore-not-found

api_weather_bit_claim=api-weather-bit-claim
api_wavefront_claim=api-wavefront-claim

weather_bit_api_service_ref=weather-bit-api=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:${api_weather_bit_claim}
wavefront_api_service_ref=wavefront-api=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:${api_wavefront_claim}

tanzu apps workload create ${tap_dotnet_api_weather} \
    --git-repo ${git_app_url} --git-branch main --type web \
    --build-env BP_DOTNET_PROJECT_PATH=src/Tap.Dotnet.Api.Weather \
    --annotation autoscaling.knative.dev/min-scale=2 \
    --label app.kubernetes.io/part-of=${tap_dotnet_api_weather} \
    --label operations=aria \
    --service-ref ${weather_bit_api_service_ref} \
    --service-ref ${wavefront_api_service_ref} \
    --yes
# *********************************************************************************************** #
# END BUILD OF TAP-DOTNET-API-WEATHER IN TAP-BUILD
# *********************************************************************************************** #

# give 7 minutes to build tap-dotnet-api-weather
intervals=( 7 6 5 4 3 2 1 )
for interval in "${intervals[@]}" ; do
echo "${interval} minutes remaining..."
sleep 60
done

# *********************************************************************************************** #
# START RUN DELIVERABLE OF TAP-DOTNET-WEB-MVC IN TAP-RUN-EKS
# *********************************************************************************************** #
kubectl config use-context ${tap_build}

if [ ! -d ${HOME}/${tap_dotnet_mvc_web} ]
then
  mkdir ${HOME}/${tap_dotnet_mvc_web}
fi

if test -f "${HOME}/${tap_dotnet_mvc_web}/${tap_dotnet_mvc_web}-deliverable.yaml"; then
  rm ${HOME}/${tap_dotnet_mvc_web}/${tap_dotnet_mvc_web}-deliverable.yaml
  echo
fi

kubectl get configmap ${tap_dotnet_mvc_web}-deliverable -o go-template='{{.data.deliverable}}' \
    > ${HOME}/${tap_dotnet_mvc_web}/${tap_dotnet_mvc_web}-deliverable.yaml

kubectl config use-context ${tap_run_eks}

# api-weather secret
api_weather_secret=api-weather-secret

kubectl delete -f ${HOME}/${tap_dotnet_mvc_web}/${api_weather_secret}.yaml
if test -f "${HOME}/${tap_dotnet_mvc_web}/${api_weather_secret}.yaml"; then
  rm ${HOME}/${tap_dotnet_mvc_web}/${api_weather_secret}.yaml
fi

cat <<EOF | tee ${HOME}/${tap_dotnet_mvc_web}/${api_weather_secret}.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${api_weather_secret}
  labels:
    operations: aria
type: Opaque
stringData:
  host: ${weather_api}
EOF

kubectl apply -f ${HOME}/${tap_dotnet_mvc_web}/${api_weather_secret}.yaml

# wavefront secret
api_wavefront_secret=api-wavefront-secret

kubectl delete -f ${HOME}/${tap_dotnet_mvc_web}/${api_wavefront_secret}.yaml
if test -f "${HOME}/${tap_dotnet_mvc_web}/${api_wavefront_secret}.yaml"; then
  rm ${HOME}/${tap_dotnet_mvc_web}/${api_wavefront_secret}.yaml
fi

cat <<EOF | tee ${HOME}/${tap_dotnet_mvc_web}/${api_wavefront_secret}.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${api_wavefront_secret}
  labels:
    operations: aria
type: Opaque
stringData:
  host: ${wavefront_url}
  token: ${wavefront_token}
EOF

kubectl apply -f ${HOME}/${tap_dotnet_mvc_web}/${api_wavefront_secret}.yaml

# create redis instance and service-ref
cache_redis_claim=cache-redis-claim

kubectl delete classclaim ${cache_redis_claim} --ignore-not-found

tanzu service class-claim create ${cache_redis_claim} --class redis-unmanaged --parameter storageGB=1

# give services toolkit permission to view secrets
stk_cluster_role=stk-cluster-role

kubectl delete -f ${HOME}/${tap_dotnet_mvc_web}/${stk_cluster_role}.yaml --ignore-not-found
if test -f "${HOME}/${tap_dotnet_mvc_web}/${stk_cluster_role}.yaml"; then
  rm ${HOME}/${tap_dotnet_mvc_web}/${stk_cluster_role}.yaml
fi

cat <<EOF | tee ${HOME}/${tap_dotnet_mvc_web}/${stk_cluster_role}.yaml
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

kubectl apply -f ${HOME}/${tap_dotnet_mvc_web}/${stk_cluster_role}.yaml

api_weather_claim=api-weather-claim
api_wavefront_claim=api-wavefront-claim

kubectl delete resourceclaim ${api_weather_claim} --ignore-not-found
kubectl delete resourceclaim ${api_wavefront_claim} --ignore-not-found

tanzu service resource-claim create ${api_weather_claim} \
  --resource-name ${api_weather_secret} --resource-kind Secret --resource-api-version v1
tanzu service resource-claim create ${api_wavefront_claim} \
  --resource-name ${api_wavefront_secret} --resource-kind Secret --resource-api-version v1

kubectl delete -f ${HOME}/${tap_dotnet_mvc_web}/${tap_dotnet_mvc_web}-deliverable.yaml --ignore-not-found
kubectl apply -f ${HOME}/${tap_dotnet_mvc_web}/${tap_dotnet_mvc_web}-deliverable.yaml
# *********************************************************************************************** #
# END RUN DELIVERABLE OF TAP-DOTNET-WEB-MVC IN TAP-RUN-EKS
# *********************************************************************************************** #


# *********************************************************************************************** #
# START RUN DELIVERABLE OF TAP-DOTNET-API-WEATHER IN TAP-RUN-AKS
# *********************************************************************************************** #
kubectl config use-context ${tap_build}

if [ ! -d ${HOME}/${tap_dotnet_api_weather} ]
then
  mkdir ${HOME}/${tap_dotnet_api_weather}
fi

if test -f "${HOME}/${tap_dotnet_api_weather}/${tap_dotnet_api_weather}-deliverable.yaml"; then
  rm ${HOME}/${tap_dotnet_api_weather}/${tap_dotnet_api_weather}-deliverable.yaml
  echo
fi

kubectl get configmap ${tap_dotnet_api_weather}-deliverable -o go-template='{{.data.deliverable}}' \
  > ${HOME}/${tap_dotnet_api_weather}/${tap_dotnet_api_weather}-deliverable.yaml

kubectl config use-context ${tap_run_aks}

# create weather-bit secret for claim
api_weather_bit_secret=api-weather-bit-secret
kubectl delete secret ${api_weather_bit_secret} --ignore-not-found
if test -f "${HOME}/${tap_dotnet_api_weather}/${api_weather_bit_secret}.yaml"; then
  rm ${HOME}/${tap_dotnet_api_weather}/${api_weather_bit_secret}.yaml
fi

cat <<EOF | tee ${HOME}/${tap_dotnet_api_weather}/${api_weather_bit_secret}.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${api_weather_bit_secret}
  labels:
    operations: aria
type: Opaque
stringData:
  host: ${weather_bit_url}
  key: ${weather_bit_token}
EOF

kubectl apply -f ${HOME}/${tap_dotnet_api_weather}/${api_weather_bit_secret}.yaml

# create wavefront secret for claim
api_wavefront_secret=api-wavefront-secret
kubectl delete secret ${api_wavefront_secret} --ignore-not-found
if test -f "${HOME}/${tap_dotnet_api_weather}/${api_wavefront_secret}.yaml"; then
  rm ${HOME}/${tap_dotnet_api_weather}/${api_wavefront_secret}.yaml
fi

cat <<EOF | tee ${HOME}/${tap_dotnet_api_weather}/${api_wavefront_secret}.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${api_wavefront_secret}
  labels:
    operations: aria
type: Opaque
stringData:
  host: ${wavefront_url}
  token: ${wavefront_token}
EOF

kubectl apply -f ${HOME}/${tap_dotnet_api_weather}/${api_wavefront_secret}.yaml

stk_cluster_role=stk-cluster-role
kubectl delete clusterrole ${stk_cluster_role} --ignore-not-found
if test -f "${HOME}/${tap_dotnet_api_weather}/${stk_cluster_role}.yaml"; then
  rm ${HOME}/${tap_dotnet_api_weather}/${stk_cluster_role}.yaml
fi

cat <<EOF | tee ${HOME}/${tap_dotnet_api_weather}/${stk_cluster_role}.yaml
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

kubectl apply -f ${HOME}/${tap_dotnet_api_weather}/${stk_cluster_role}.yaml

api_weather_bit_claim=api-weather-bit-claim
kubectl delete resourceclaim ${api_weather_bit_claim} --ignore-not-found

api_wavefront_claim=api-wavefront-claim
kubectl delete resourceclaim ${api_wavefront_claim} --ignore-not-found

tanzu service resource-claim create ${api_weather_bit_claim} --resource-name ${api_weather_bit_secret} --resource-kind Secret --resource-api-version v1
tanzu service resource-claim create ${api_wavefront_claim} --resource-name ${api_wavefront_secret} --resource-kind Secret --resource-api-version v1

kubectl delete -f ${HOME}/${tap_dotnet_api_weather}/${tap_dotnet_api_weather}-deliverable.yaml --ignore-not-found

kubectl apply -f ${HOME}/${tap_dotnet_api_weather}/${tap_dotnet_api_weather}-deliverable.yaml
# *********************************************************************************************** #
# END RUN DELIVERABLE OF TAP-DOTNET-API-WEATHER IN TAP-RUN-AKS
# *********************************************************************************************** #

echo
echo
echo ">>> Supply Chains:"
echo "https://tap-gui.view.tap.nycpivot.com/supply-chain"
echo

echo ">>> Running Workloads:"

echo https://${tap_dotnet_mvc_web}.default.${tap_run_eks_domain}.tap.nycpivot.com
echo
echo https://${tap_dotnet_api_weather}.default.${tap_run_aks_domain}.tap.nycpivot.com
echo

