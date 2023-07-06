#!/bin/bash

kubectl config get-contexts
read -p "Input cluster name: " cluster_name
kubectl config use-context ${cluster_name}

wavefront_prod_token=$(az keyvault secret show --name wavefront-prod-token --subscription nycpivot --vault-name tanzuvault --query value --output tsv)

#INSTALL WAVEFRONT HELM CHART
helm repo add wavefront https://wavefronthq.github.io/helm/ && helm repo update
kubectl create namespace wavefront && helm install wavefront wavefront/wavefront --set wavefront.url=https://vmwareprod.wavefront.com --set wavefront.token=${wavefront_prod_token} --set clusterName=${cluster_name} --namespace wavefront
