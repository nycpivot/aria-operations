#!/bin/bash
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-multicluster-reference-tap-values-view-sample.html

TAP_VERSION=1.5.0
VIEW_DOMAIN=view.tap.nycpivot.com
RUN_DOMAIN=run.tap.nycpivot.com

tap_run=tap-run-eks

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
