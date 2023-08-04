#!/bin/bash

TAP_VERSION=1.6.1
TDP_DOMAIN=tdp.tap.nycpivot.com
GIT_CATALOG_REPOSITORY=tanzu-application-platform

tap_view=tap-view

kubectl config use-context ${tap_view}

tdp_values=tdp-values

if test -f ${tdp_values}.yaml; then
  rm ${tdp_values}.yaml
fi

cat <<EOF | tee ${tdp_values}.yaml
ingressEnabled: true
ingressDomain: "${TDP_DOMAIN}"
app_config:
  catalog:
    locations:
      - type: url
        target: https://github.com/nycpivot/$GIT_CATALOG_REPOSITORY/catalog-info.yaml
EOF

tap_gui_version=$(tanzu package available list tap-gui.tanzu.vmware.com --namespace tap-install -ojson | jq -r .[].version)

tanzu package install tap-gui --package tap-gui.tanzu.vmware.com -v ${tap_gui_version} -n tap-install --values-file ${tdp_values}.yaml

tanzu package installed get tap-gui -n tap-install

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
                "Name": "*.${TDP_DOMAIN}",
                "Type": "CNAME",
                "TTL": 60,
                "ResourceRecords": [
                    {
                        "Value": "${ingress}"
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
echo "TAP-GUI: " https://tap-gui.${TDP_DOMAIN}
echo
echo "HAPPY VIEWING!"
echo
