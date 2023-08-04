#!/bin/bash
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-multicluster-reference-tap-values-view-sample.html

TAP_VERSION=1.6.1
VIEW_DOMAIN=view.tap.nycpivot.com
RUN_DOMAIN=run-aks.tap.nycpivot.com

tap_run=tap-run-aks

acr_secret=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"acr-secret\")

export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export IMGPKG_REGISTRY_HOSTNAME_1=tanzuapplicationregistry.azurecr.io
export IMGPKG_REGISTRY_USERNAME_1=tanzuapplicationregistry
export IMGPKG_REGISTRY_PASSWORD_1=$acr_secret

#INSTALL RUN TAP PROFILE
echo
echo "<<< INSTALLING RUN TAP PROFILE >>>"
echo

sleep 5

kubectl config use-context $tap_run

rm tap-values-run.yaml
cat <<EOF | tee tap-values-run.yaml
profile: run
ceip_policy_disclosed: true
shared:
  ingress_domain: $RUN_DOMAIN
supply_chain: basic
contour:
  infrastructure_provider: aws
  envoy:
    service:
      aws:
        LBType: nlb
appliveview_connector:
  backend:
    sslDisabled: true
    ingressEnabled: true
    host: appliveview.$VIEW_DOMAIN
excluded_packages:
  - policy.apps.tanzu.vmware.com
EOF

tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file tap-values-run.yaml -n tap-install

# DEVELOPER NAMESPACE
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.4/tap/scc-ootb-supply-chain-basic.html
echo
echo "<<< CREATING DEVELOPER NAMESPACE >>>"
echo

tanzu secret registry add registry-credentials \
  --server $IMGPKG_REGISTRY_HOSTNAME_1 \
  --username $IMGPKG_REGISTRY_USERNAME_1 \
  --password $IMGPKG_REGISTRY_PASSWORD_1 \
  --namespace default

rm rbac-dev.yaml
cat <<EOF | tee rbac-dev.yaml
apiVersion: v1
kind: Secret
metadata:
  name: tap-registry
  annotations:
    secretgen.carvel.dev/image-pull-secret: ""
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: e30K
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
secrets:
  - name: registry-credentials
imagePullSecrets:
  - name: registry-credentials
  - name: tap-registry
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-deliverable
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: deliverable
subjects:
  - kind: ServiceAccount
    name: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-workload
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: workload
subjects:
  - kind: ServiceAccount
    name: default
EOF

kubectl apply -f rbac-dev.yaml

#CONFIGURE DNS NAME WITH ELB IP
echo
echo "Press Ctrl+C when contour packages has successfully reconciled"
echo

kubectl get pkgi -n tap-install -w | grep contour

echo
echo "<<< CONFIGURING DNS >>>"
echo

sleep 5

hosted_zone_id=$(aws route53 list-hosted-zones --query HostedZones[0].Id --output text | awk -F '/' '{print $3}')
ingress=$(kubectl get svc envoy -n tanzu-system-ingress -o json | jq -r .status.loadBalancer.ingress[].ip)

echo $ingress
echo

#rm change-batch.json
change_batch_filename=change-batch-$RANDOM
cat <<EOF | tee $change_batch_filename.json
{
    "Comment": "Update record.",
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "*.$RUN_DOMAIN",
                "Type": "A",
                "TTL": 60,
                "ResourceRecords": [
                    {
                        "Value": "$ingress"
                    }
                ]
            }
        }
    ]
}
EOF
echo

echo $change_batch_filename.json
aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --change-batch file:///$HOME/$change_batch_filename.json

echo
echo "HAPPY TAP'ING!"
echo
