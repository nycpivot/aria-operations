#!/bin/bash
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-multicluster-reference-tap-values-view-sample.html

TAP_VERSION=1.5.0
VIEW_DOMAIN=view.tap.nycpivot.com
RUN_DOMAIN=run-aks.tap.nycpivot.com

tap_run=tap-run-aks

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
ingress=$(kubectl get svc envoy -n tanzu-system-ingress -o json | jq -r .status.loadBalancer.ingress[].hostname)

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
                "Type": "CNAME",
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
