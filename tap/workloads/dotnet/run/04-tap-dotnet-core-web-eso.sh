#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

########################
# Configure the options
########################

#
# speed at which to simulate typing. bigger num = faster
#
TYPE_SPEED=15

#
# custom prompt
#
# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#
#DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "

# hide the evidence
clear

DEMO_PROMPT="${GREEN}➜ TAP ${CYAN}\W "

read -p "App Name (tap-dotnet-core-web-mvc-claim): " app_name
echo

if [[ -z ${app_name} ]]
then
  app_name=tap-dotnet-core-web-mvc-claim
fi

tap_build=tap-build
tap_run_eks=tap-run-eks
tap_run_eks_domain=run-eks
tap_run_aks_domain=run-aks

#REBUILD DELIVERABLE HERE IF NEW SOURCE CODE WAS COMMITTED AND BUILT
pe "kubectl config use-context ${tap_build}"
echo

echo "Press Ctrl+C when the workload has finished building and is ready..."
echo

pe "kubectl get workloads -w"
echo

pe "kubectl get configmaps"
echo

if test -f "${app_name}-deliverable.yaml"; then
  rm ${app_name}-deliverable.yaml
  echo
fi

pe "kubectl get configmap ${app_name}-deliverable -o go-template='{{.data.deliverable}}' > ${app_name}-deliverable.yaml"
echo


#SWITCH TO RUN CLUSTER
pe "kubectl config use-context ${tap_run_eks}"
echo

api_weather_claim=api-weather-claim

api_weather_secret=api-weather-secret
if test -f "${api_weather_secret}.yaml"; then
  kubectl delete -f ${api_weather_secret}
  rm ${api_weather_secret}.yaml
fi

cat <<EOF | tee ${api_weather_secret}.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${api_weather_secret}
type: Opaque
stringData:
  host: https://tap-dotnet-core-api-weather.default.${tap_run_aks_domain}.tap.nycpivot.com
EOF
echo

pe "kubectl apply -f ${api_weather_secret}.yaml"
echo

#GIVE SERVICES TOOLKIT PERMISSION TO READ SECRET
stk_secret_reader=stk-secret-reader
if test -f "${stk_secret_reader}.yaml"; then
  kubectl delete -f ${stk_secret_reader}
  rm ${stk_secret_reader}.yaml
fi

cat <<EOF | tee ${stk_secret_reader}.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: stk-secret-reader
  labels:
    servicebinding.io/controller: "true"
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
echo

pe "kubectl apply -f ${stk_secret_reader}.yaml"
echo

pe "tanzu service resource-claim create ${api_weather_claim} --resource-name ${api_weather_secret} --resource-kind Secret --resource-api-version v1"
echo

pe "tanzu service resource-claim list -o wide"
echo

pe "tanzu services resource-claims get api-weather-claim"
echo

kubectl delete -f ${app_name}-deliverable.yaml
echo

pe "kubectl apply -f ${app_name}-deliverable.yaml"
echo

pe "kubectl get deliverables -w"
echo

#pe "kubectl get httpproxy"
#echo

echo https://${app_name}.default.${tap_run_eks_domain}.tap.nycpivot.com
echo
