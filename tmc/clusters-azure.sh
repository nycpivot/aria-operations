#!/bin/bash

rm tmp*

subscription_id=$(az account show --query id --output tsv)

service_principal=$(az ad sp create-for-rbac --name azure-account-credential --role Contributor --create-cert --scopes /subscriptions/6e27ec38-5950-433a-a795-222b73ddfc66)

app_id=$(echo $service_principal | jq -r .appId)
tenant_id=$(echo $service_principal | jq -r .tenant)

cat /home/ubuntu/tmpf5x93nzr.pem
