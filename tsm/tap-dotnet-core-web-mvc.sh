#!/bin/bash

# APPLY TSM K8S COMPONENTS
echo
echo "<<< APPLY TSM K8S COMPONENTS >>>"
echo

sleep 5

cluster_name=tap-run-eks

kubectl config use-context ${cluster_name}

tsm_token=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"tsm-token\")
vmware_token=$(curl "https://console.cloud.vmware.com/csp/gateway/am/api/auth/api-tokens/authorize" -H "authority: console.cloud.vmware.com" -H "pragma: no-cache" -H "cache-control: no-cache" -H "accept: application/json, text/plain, */*" --data-raw "refresh_token=${tsm_token}")
access_token=$(echo ${vmware_token} | jq -r .access_token)

registration_yaml=$(curl "https://${server_name}/tsm/v1alpha1/clusters/onboard-url" -H "accept: application/json" -H "csp-auth-token: ${access_token}")
registration_url=$(echo $registration_yaml | jq .url)

kubectl apply -f $registration_url


# REGISTER CLUSTER
echo
echo "<<< REGISTER CLUSTER >>>"
echo

sleep 5

put_response=$(curl -X PUT "https://${server_name}/tsm/v1alpha1/clusters/${cluster_name}" -H "content-type: application/json" -H "accept: application/json" -H "csp-auth-token: ${access_token}" -d "{\"displayName\":\"${cluster_name}\",\"description\":\"${cluster_name}\",\"tags\":[],\"labels\":[],\"namespaceExclusions\":[],\"autoInstallServiceMesh\":true,\"enableNamespaceExclusions\":false}")

cluster_token=$(echo $put_response | jq .token | tr -d '"')

kubectl create secret generic cluster-token --from-literal=token=$cluster_token -n vmware-system-tsm

sleep 300

get_status=$(curl "https://${server_name}/tsm/v1alpha1/clusters/${cluster_name}" -H "accept: application/json" -H "csp-auth-token: ${access_token}")

echo $get_status

kubectl label namespace default istio-injection=enabled


# CREATE GNS
server_name=prod-2.nsxservicemesh.vmware.com

tsm_token=$(aws secretsmanager get-secret-value --secret-id aria-workshop | jq -r .SecretString | jq -r .\"tsm-token\")
vmware_token=$(curl "https://console.cloud.vmware.com/csp/gateway/am/api/auth/api-tokens/authorize" -H "authority: console.cloud.vmware.com" -H "pragma: no-cache" -H "cache-control: no-cache" -H "accept: application/json, text/plain, */*" --data-raw "refresh_token=${tsm_token}")
access_token=$(echo ${vmware_token} | jq -r .access_token)

cat <<EOF | tee gns-request.json
{
   "name":"acme-fitness",
   "display_name":"Acme Fitness",
   "domain_name":"nycpivot.com",
   "description":"Acme Fitness",
   "mtls_enforced":true,
   "ca_type":"PreExistingCA",
   "ca":"default",
   "version":"1.0",
   "match_conditions":[
      {
         "namespace":{
            "type":"EXACT",
            "match":"default"
         },
         "cluster":{
            "type":"EXACT",
            "match":"acme-fitness-web"
         }
      },
      {
         "namespace":{
            "type":"EXACT",
            "match":"default"
         },
         "cluster":{
            "type":"EXACT",
            "match":"acme-fitness-catalog"
         }
      }
   ]
}
EOF

gns_request=$(cat gns-request.json)

response=$(curl -X POST "https://${server_name}/tsm/v1alpha1/global-namespaces" -H "content-type: application/json" -H "accept: application/json" -H "csp-auth-token: ${access_token}" -d "${gns_request}") 

echo $response