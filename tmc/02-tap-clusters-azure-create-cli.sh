#!/bin/bash

# DELETE LEFTOVER KEYS CREATED BY THE PRINCIPAL CREATION
rm tmp*

subscription_id=$(az account show --query id --output tsv)

service_principal=$(az ad sp create-for-rbac --name azure-account-credential --role Contributor --create-cert --scopes /subscriptions/${subscription_id})

app_id=$(echo $service_principal | jq -r .appId)
tenant_id=$(echo $service_principal | jq -r .tenant)
file_cert_and_key=$(echo $service_principal | jq -r .fileWithCertAndPrivateKey)

# GET REFRESH TOKEN, EXCHANGE IT FOR AN ACCESS TOKEN FOR THE REMAINDER
tmc_token=$(az keyvault secret show --name tmc-${aria_org}-token --subscription nycpivot --vault-name tanzuvault --query value --output tsv)

export TMC_API_TOKEN=${tmc_token}
export TANZU_API_TOKEN=${tmc_token}


# 3. CREATE TMC AZURE ACCOUNT CREDENTIAL (THIS IS STEP 1 IN TMC CONSOLE)
# THIS ACCOUNT CREDENTIAL WILL REFERENCE THE APP REGISTRATION
azure_account_credential=azure-account-credential

if test -f ${azure_account_credential}.yaml; then
  rm ${azure_account_credential}.yaml
fi

cat <<EOF | tee ${azure_account_credential}.yaml # TMC CLI VERSION (THIS WORKS)
fullName:
  name: ${azure_account_credential}
  orgId: 3be385a3-d15d-4f70-b779-5e69b8b2a2cc
spec:
  capability: MANAGED_K8S_PROVIDER
  data:
    azureCredential:
      servicePrincipalWithCertificate:
        clientId: ${app_id}
        subscriptionId: ${subscription_id}
        tenantId: ${tenant_id}
        clientCertificate: |-
EOF

sed -e 's/^/          /' ${file_cert_and_key} >> ${azure_account_credential}.yaml
echo '  meta:' >> ${azure_account_credential}.yaml
echo '    provider: AZURE_AKS' >> ${azure_account_credential}.yaml

tmc account credential create -f ${azure_account_credential}.yaml

echo
intervals=( 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 )
for interval in "${intervals[@]}" ; do
echo "${interval} minutes remaining..."
sleep 60 # give 20 minutes for all clusters to be created
done


# CREATE CLUSTERS
cluster=tap-run-eks
resource_group=tmc-operations

if test -f ${cluster}.json; then
  rm ${cluster}.json
fi

cat <<EOF | tee ${cluster}.json
{
 "fullName": {
  "orgId": "3be385a3-d15d-4f70-b779-5e69b8b2a2cc",
  "credentialName": ${azure_account_credentials},
  "subscriptionId": ${subscription_id},
  "resourceGroupName": ${resource_group},
  "name": ${cluster}
 },
 "meta": {
  "uid": "c:01H748T9J1E8951JSMPYT629NG",
  "creationTime": "2023-08-06T01:54:00.896513Z",
  "updateTime": "2023-08-06T02:10:02.215888Z"
 },
 "spec": {
  "clusterGroupName": ${resource_group},
  "config": {
   "location": "eastus",
   "version": "1.25.11",
   "nodeResourceGroupName": "MC_tmc-operations_${cluster}_eastus",
   "sku": {
    "name": "BASIC",
    "tier": "PAID"
   },
   "networkConfig": {
    "loadBalancerSku": "standard",
    "networkPlugin": "kubenet",
    "dnsServiceIp": "10.0.0.10",
    "dockerBridgeCidr": "172.17.0.1/16",
    "podCidrs": [
     "10.244.0.0/16"
    ],
    "serviceCidrs": [
     "10.0.0.0/16"
    ],
    "dnsPrefix": "${tap_run_eks}-dns"
   },
   "storageConfig": {
    "enableDiskCsiDriver": true,
    "enableFileCsiDriver": true,
    "enableSnapshotController": true
   },
   "tags": {
    "account.tmc.cloud.vmware.com": ${azure_account_credential},
    "creator.tmc.cloud.vmware.com": "mijames@vmware.com",
    "managed.tmc.cloud.vmware.com": "true",
    "org-id.tmc.cloud.vmware.com": "3be385a3-d15d-4f70-b779-5e69b8b2a2cc"
   }
  },
  "agentName": "aks.ca889dd0.${resource_group}.${cluster}",
  "resourceId": "/subscriptions/6e27ec38-5950-433a-a795-222b73ddfc66/resourcegroups/tmc-operations/providers/Microsoft.ContainerService/managedClusters/${cluster}"
 }
}
EOF

tanzu mission-control akscluster create -f ${cluster}.json

sleep 60


# NODEPOOL
cluster_nodepool=${cluster}-nodepool

if test -f ${cluster_nodepool}.json; then
  rm ${cluster_nodepool}.json
fi

cat <<EOF | tee ${cluster_nodepool}.json
{
 "fullName": {
  "orgId": "3be385a3-d15d-4f70-b779-5e69b8b2a2cc",
  "credentialName": ${azure_account_credential},
  "subscriptionId": ${subscription_id},
  "resourceGroupName": ${resource_group},
  "aksClusterName": ${cluster},
  "name": ${cluster}-nodepool
 },
 "spec": {
  "mode": "SYSTEM",
  "type": "VIRTUAL_MACHINE_SCALE_SETS",
  "availabilityZones": [
   "1",
   "2",
   "3"
  ],
  "count": 1,
  "autoScaling": {
   "enabled": true,
   "minCount": 1,
   "maxCount": 2
  },
  "vmSize": "Standard_DS2_v2",
  "osType": "LINUX",
  "osDiskType": "MANAGED",
  "osDiskSizeGb": 128,
  "maxPods": 110,
  "upgradeConfig": {
   "maxSurge": "1"
  },
  "scaleSetPriority": "REGULAR"
 }
}
EOF

tanzu mission-control akscluster nodepool create -f ${cluster_nodepool}.json
