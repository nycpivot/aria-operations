#!/bin/bash
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-multicluster-reference-tap-values-view-sample.html

TAP_VERSION=1.6.1
VIEW_DOMAIN=view.tap.nycpivot.com
#GIT_CATALOG_REPOSITORY=tanzu-application-platform
GIT_CATALOG_REPOSITORY=tap-yelb-catalog

tap_view=tap-view
tap_build=tap-build
tap_run_eks=tap-run-eks
tap_run_aks=tap-run-aks


#RESET AN EXISTING INSTALLATION
tanzu package installed delete ootb-supply-chain-testing-scanning -n tap-install --yes
tanzu package installed delete ootb-supply-chain-testing -n tap-install --yes
tanzu package installed delete tap -n tap-install --yes

#CREATE SERVICE ACCOUNT SO BUILD AND RUN WILL BE ABLE
#TO COMMUNICATE WITH THE VIEW CLUSTER
rm tap-gui-viewer-service-account-rbac.yaml
cat <<EOF | tee tap-gui-viewer-service-account-rbac.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tap-gui
---
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: tap-gui
  name: tap-gui-viewer
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tap-gui-read-k8s
subjects:
- kind: ServiceAccount
  namespace: tap-gui
  name: tap-gui-viewer
roleRef:
  kind: ClusterRole
  name: k8s-reader
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: k8s-reader
rules:
- apiGroups: ['']
  resources: ['pods', 'pods/log', 'services', 'configmaps', 'limitranges']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['metrics.k8s.io']
  resources: ['pods']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['apps']
  resources: ['deployments', 'replicasets', 'statefulsets', 'daemonsets']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['autoscaling']
  resources: ['horizontalpodautoscalers']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['networking.k8s.io']
  resources: ['ingresses']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['networking.internal.knative.dev']
  resources: ['serverlessservices']
  verbs: ['get', 'watch', 'list']
- apiGroups: [ 'autoscaling.internal.knative.dev' ]
  resources: [ 'podautoscalers' ]
  verbs: [ 'get', 'watch', 'list' ]
- apiGroups: ['serving.knative.dev']
  resources:
  - configurations
  - revisions
  - routes
  - services
  verbs: ['get', 'watch', 'list']
- apiGroups: ['carto.run']
  resources:
  - clusterconfigtemplates
  - clusterdeliveries
  - clusterdeploymenttemplates
  - clusterimagetemplates
  - clusterruntemplates
  - clustersourcetemplates
  - clustersupplychains
  - clustertemplates
  - deliverables
  - runnables
  - workloads
  verbs: ['get', 'watch', 'list']
- apiGroups: ['source.toolkit.fluxcd.io']
  resources:
  - gitrepositories
  verbs: ['get', 'watch', 'list']
- apiGroups: ['source.apps.tanzu.vmware.com']
  resources:
  - imagerepositories
  - mavenartifacts
  verbs: ['get', 'watch', 'list']
- apiGroups: ['conventions.apps.tanzu.vmware.com']
  resources:
  - podintents
  verbs: ['get', 'watch', 'list']
- apiGroups: ['kpack.io']
  resources:
  - images
  - builds
  verbs: ['get', 'watch', 'list']
- apiGroups: ['scanning.apps.tanzu.vmware.com']
  resources:
  - sourcescans
  - imagescans
  - scanpolicies
  verbs: ['get', 'watch', 'list']
- apiGroups: ['tekton.dev']
  resources:
  - taskruns
  - pipelineruns
  verbs: ['get', 'watch', 'list']
- apiGroups: ['kappctrl.k14s.io']
  resources:
  - apps
  verbs: ['get', 'watch', 'list']
- apiGroups: [ 'batch' ]
  resources: [ 'jobs', 'cronjobs' ]
  verbs: [ 'get', 'watch', 'list' ]
- apiGroups: ['conventions.carto.run']
  resources:
  - podintents
  verbs: ['get', 'watch', 'list']
- apiGroups: ['appliveview.apps.tanzu.vmware.com']
  resources:
  - resourceinspectiongrants
  verbs: ['get', 'watch', 'list', 'create']
EOF

kubectl config use-context $tap_build
kubectl apply -f tap-gui-viewer-service-account-rbac.yaml

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: tap-gui-viewer
  namespace: tap-gui
  annotations:
    kubernetes.io/service-account.name: tap-gui-viewer
type: kubernetes.io/service-account-token
EOF

CLUSTER_URL_BUILD=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CLUSTER_TOKEN_BUILD=$(kubectl -n tap-gui get secret tap-gui-viewer -o=json | jq -r '.data["token"]' | base64 --decode)

kubectl config use-context $tap_run_eks
kubectl apply -f tap-gui-viewer-service-account-rbac.yaml

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: tap-gui-viewer
  namespace: tap-gui
  annotations:
    kubernetes.io/service-account.name: tap-gui-viewer
type: kubernetes.io/service-account-token
EOF

CLUSTER_URL_RUN_EKS=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CLUSTER_TOKEN_RUN_EKS=$(kubectl -n tap-gui get secret tap-gui-viewer -o=json | jq -r '.data["token"]' | base64 --decode)

kubectl config use-context $tap_run_aks
kubectl apply -f tap-gui-viewer-service-account-rbac.yaml

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: tap-gui-viewer
  namespace: tap-gui
  annotations:
    kubernetes.io/service-account.name: tap-gui-viewer
type: kubernetes.io/service-account-token
EOF

CLUSTER_URL_RUN_AKS=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CLUSTER_TOKEN_RUN_AKS=$(kubectl -n tap-gui get secret tap-gui-viewer -o=json | jq -r '.data["token"]' | base64 --decode)


#INSTALL VIEW TAP PROFILE
echo
echo "<<< INSTALLING VIEW TAP PROFILE >>>"
echo

sleep 5

kubectl config use-context $tap_view

ad_client_id=$(az keyvault secret show --name tdp-azure-ad-client-id --subscription nycpivot --vault-name tanzuvault --query value --output tsv)
ad_client_secret=$(az keyvault secret show --name tdp-azure-ad-client-secret --subscription nycpivot --vault-name tanzuvault --query value --output tsv)

rm tap-values-view.yaml
cat <<EOF | tee tap-values-view.yaml
profile: view
ceip_policy_disclosed: true # Installation fails if this is not set to true. Not a string.
shared:
  ingress_domain: "$VIEW_DOMAIN"
tap_gui:
  service_type: ClusterIP
  app_config:
    app:
      title: "The James Portal"
      support:
        url: https://google.com
        items:
          - title: Google It
            icon: email
            links:
              - url: https://google.com
                title: Tanzu Support Page
          - title: Just Google It
            icon: docs
            links:
              - url: https://google.com
                title: Tanzu Application Platform Documentation
    organization:
      name: "The James Portal"
    customize:
      #custom_logo: ""
      custom_name: "The James Portal"
    auth:
      environment: development
      providers:
        microsoft:
          development:
            clientId: ${ad_client_id}
            clientSecret: ${ad_client_secret}
            tenantId: b39138ca-3cee-4b4a-a4d6-cd83d9dd62f0
    catalog:
      locations:
        - type: url
          target: https://github.com/nycpivot/$GIT_CATALOG_REPOSITORY/catalog-info.yaml
    kubernetes:
      serviceLocatorMethod:
        type: 'multiTenant'
      clusterLocatorMethods:
        - type: 'config'
          clusters:
            - url: $CLUSTER_URL_BUILD
              name: $tap_build
              authProvider: serviceAccount
              serviceAccountToken: $CLUSTER_TOKEN_BUILD
              skipTLSVerify: true
            - url: $CLUSTER_URL_RUN_EKS
              name: $tap_run_eks
              authProvider: serviceAccount
              serviceAccountToken: $CLUSTER_TOKEN_RUN_EKS
              skipTLSVerify: true
            - url: $CLUSTER_URL_RUN_AKS
              name: $tap_run_aks
              authProvider: serviceAccount
              serviceAccountToken: $CLUSTER_TOKEN_RUN_AKS
              skipTLSVerify: true
contour:
  infrastructure_provider: aws
  envoy:
    service:
      aws:
        LBType: nlb
appliveview:
  sslDisabled: true
  ingressEnabled: true
EOF

tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file tap-values-view.yaml -n tap-install

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
                "Name": "*.${VIEW_DOMAIN}",
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
echo "TAP-GUI: " https://tap-gui.${VIEW_DOMAIN}
echo
echo "HAPPY VIEWING!"
echo
