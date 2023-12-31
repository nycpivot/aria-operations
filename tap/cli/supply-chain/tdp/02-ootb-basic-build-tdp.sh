#!/bin/bash
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-multicluster-reference-tap-values-view-sample.html

TAP_VERSION=1.6.1
VIEW_DOMAIN=view.tap.nycpivot.com
GIT_CATALOG_REPOSITORY=tanzu-application-platform

registry_secret=$(aws secretsmanager get-secret-value --secret-id aria-operations | jq -r .SecretString | jq -r .\"registry-secret\")

export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export IMGPKG_REGISTRY_HOSTNAME_1=tanzuapplicationregistry.azurecr.io
export IMGPKG_REGISTRY_USERNAME_1=tanzuapplicationregistry
export IMGPKG_REGISTRY_PASSWORD_1=$registry_secret

tdp_build=tdp-build

# 2. INSTALL BUILD TAP PROFILE
echo
echo "<<< INSTALLING BUILD TAP PROFILE >>>"
echo

sleep 5

kubectl config use-context $tdp_build

rm tap-values-build.yaml
cat <<EOF | tee tap-values-build.yaml
profile: build
ceip_policy_disclosed: true
shared:
  ingress_domain: "$VIEW_DOMAIN"
supply_chain: basic
ootb_supply_chain_basic:
  registry:
    server: $IMGPKG_REGISTRY_HOSTNAME_1
    repository: "supply-chain"
buildservice:
  kp_default_repository: $IMGPKG_REGISTRY_HOSTNAME_1/build-service
  kp_default_repository_username: $IMGPKG_REGISTRY_USERNAME_1
  kp_default_repository_password: $IMGPKG_REGISTRY_PASSWORD_1
grype:
  namespace: "default"
  targetImagePullSecret: "registry-credentials"
scanning:
  metadataStore:
    url: "" # Configuration is moved, so set this string to empty.
EOF

tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file tap-values-build.yaml -n tap-install


# 3. CREATE DEVELOPER NAMESPACE
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

echo
echo "NEXT -> ~/aria-operations/tap/cli/supply-chain/03-ootb-basic-run-eks.sh"
echo
echo "HAPPY TAP'ING!"
echo
